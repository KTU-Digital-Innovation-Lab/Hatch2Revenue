-- ============================================================
-- Hatch2Revenue — Role-based access control for farm teams
--
-- Replaces the single blanket "own or approved farm rows" policy
-- (which let ANY approved member insert, edit AND delete every farm
-- record) with per-role, per-operation rules.
--
-- Roles (h2r_farm_members.role): owner | manager | worker | vet
--   owner    - full control; only one; set at farm creation.
--   manager  - deputy: edit/delete records, see finances; NOT team/prices.
--   worker   - append-only: log eggs/feed/deaths, record sales; no edit,
--              no delete, no money totals.
--   vet      - health only: manage vaccinations, record/annotate deaths,
--              read flocks + feed; no eggs, sales or money.
--
-- Anti-theft principle: workers APPEND, owner/manager AMEND. A worker
-- can never edit or delete a record, so a skimmed collection or a
-- shaved sale cannot be covered up. Every row keeps user_id = its
-- author for attribution ("logged by ...").
--
-- Solo users (no farm, farm_id null) are unaffected: their rows stay
-- fully private to them. Safe to re-run (idempotent).
-- ============================================================

-- ---------------- Role helpers -------------------------------
-- The caller's role in [farm]. Owner is authoritative from h2r_farms.
create or replace function h2r_role(farm uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from h2r_farms f where f.id = farm and f.owner_id = auth.uid())
      then 'owner'
    else (
      select m.role from h2r_farm_members m
      where m.farm_id = farm and m.user_id = auth.uid() and m.status = 'approved'
      limit 1
    )
  end;
$$;

-- Can edit/delete records, see finances, manage flocks & stock.
create or replace function h2r_can_amend(farm uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select h2r_role(farm) in ('owner', 'manager');
$$;

-- Can log daily operations (eggs, feed, sales). Everyone except the vet.
create or replace function h2r_can_log(farm uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select h2r_role(farm) in ('owner', 'manager', 'worker');
$$;

-- Can manage health: vaccinations and annotating cause of death.
create or replace function h2r_is_health(farm uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select h2r_role(farm) in ('owner', 'manager', 'vet');
$$;

-- ---------------- Per-table, per-operation policies ----------
-- Helper block: drop the blanket policy, then create four scoped ones.
-- Written explicitly per table because the rules differ by table.

-- Common solo-user clause, inlined in each policy:
--   (farm_id is null and user_id = auth.uid())

-- === batches: owner/manager set up flocks; everyone reads ===
drop policy if exists "own or approved farm rows" on h2r_batches;
create policy "batches read" on h2r_batches for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_approved(farm_id)));
create policy "batches insert" on h2r_batches for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_amend(farm_id)));
create policy "batches update" on h2r_batches for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
create policy "batches delete" on h2r_batches for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- === egg_production: owner/manager/worker; vet cannot see eggs ===
drop policy if exists "own or approved farm rows" on h2r_egg_production;
create policy "eggs read" on h2r_egg_production for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_log(farm_id)));
create policy "eggs insert" on h2r_egg_production for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_log(farm_id)));
create policy "eggs update" on h2r_egg_production for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
create policy "eggs delete" on h2r_egg_production for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- === feed_records: worker logs; vet reads; owner/manager amend ===
drop policy if exists "own or approved farm rows" on h2r_feed_records;
create policy "feed read" on h2r_feed_records for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_approved(farm_id)));
create policy "feed insert" on h2r_feed_records for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_log(farm_id)));
create policy "feed update" on h2r_feed_records for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
create policy "feed delete" on h2r_feed_records for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- === feed_inventory (stock): owner/manager manage; team reads ===
drop policy if exists "own or approved farm rows" on h2r_feed_inventory;
create policy "stock read" on h2r_feed_inventory for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_approved(farm_id)));
create policy "stock insert" on h2r_feed_inventory for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_amend(farm_id)));
create policy "stock update" on h2r_feed_inventory for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
create policy "stock delete" on h2r_feed_inventory for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- === mortality: worker + vet record; vet annotates; owner/manager delete ===
drop policy if exists "own or approved farm rows" on h2r_mortality;
create policy "mortality read" on h2r_mortality for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_approved(farm_id)));
create policy "mortality insert" on h2r_mortality for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_is_approved(farm_id)));
create policy "mortality update" on h2r_mortality for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_health(farm_id)));
create policy "mortality delete" on h2r_mortality for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- === vaccinations: owner/manager/vet manage; worker reads schedule ===
drop policy if exists "own or approved farm rows" on h2r_vaccinations;
create policy "vacc read" on h2r_vaccinations for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_approved(farm_id)));
create policy "vacc insert" on h2r_vaccinations for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_is_health(farm_id)));
create policy "vacc update" on h2r_vaccinations for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_health(farm_id)));
create policy "vacc delete" on h2r_vaccinations for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_health(farm_id)));

-- === financial_transactions: owner/manager only. No worker/vet money ===
drop policy if exists "own or approved farm rows" on h2r_financial_transactions;
create policy "fin read" on h2r_financial_transactions for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
-- Owner/manager post any transaction; a worker may append ONLY income
-- (type 0 = TransactionType.income), which is the egg-sale income line,
-- so their sale reaches the books. They still cannot read, edit or
-- delete financial transactions.
create policy "fin insert" on h2r_financial_transactions for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_amend(farm_id))
  or (farm_id is not null and user_id = auth.uid() and h2r_can_log(farm_id) and "type" = 0));
create policy "fin update" on h2r_financial_transactions for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
create policy "fin delete" on h2r_financial_transactions for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- === egg_sales: workers record sales; only owner/manager see the
--     ledger, totals and debtors. ===
drop policy if exists "own or approved farm rows" on h2r_egg_sales;
drop policy if exists "sales read" on h2r_egg_sales;
drop policy if exists "sales insert" on h2r_egg_sales;
create policy "sales read" on h2r_egg_sales for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
create policy "sales insert" on h2r_egg_sales for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_log(farm_id)));
create policy "sales update" on h2r_egg_sales for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
create policy "sales delete" on h2r_egg_sales for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- ---------------- Role assignment RPC ------------------------
-- Owner sets a member's role (manager | worker | vet) and, optionally,
-- approves them in one call. Only the farm owner may call it, and the
-- owner's own role can never be changed away from 'owner'.
create or replace function h2r_set_member_role(
  member uuid, new_role text, approve boolean default false
)
returns void language plpgsql security definer set search_path = public as $$
declare
  fid uuid;
begin
  -- The farm the caller owns and [member] belongs to.
  select fm.farm_id into fid
  from h2r_farm_members fm
  join h2r_farms f on f.id = fm.farm_id
  where fm.user_id = member and f.owner_id = auth.uid()
  limit 1;

  if fid is null then
    raise exception 'Not authorised, or member not found';
  end if;
  if member = auth.uid() then
    raise exception 'The owner role cannot be changed';
  end if;
  if new_role not in ('manager', 'worker', 'vet') then
    raise exception 'Invalid role: %', new_role;
  end if;

  update h2r_farm_members
     set role = new_role,
         status = case when approve then 'approved' else status end,
         approved_at = case when approve and approved_at is null then now() else approved_at end,
         server_updated_at = now()
   where farm_id = fid and user_id = member;
end;
$$;
