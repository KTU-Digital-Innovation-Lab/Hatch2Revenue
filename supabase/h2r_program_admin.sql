-- ============================================================
-- Hatch2Revenue — National program / coordinator oversight tier
--
-- Hatch2Revenue is piloted as a national scheme: government distributes
-- birds to beneficiary farmers, each of whom keeps their own farm in the
-- app. This layer adds a READ-ONLY "program admin" (coordinator) role
-- ABOVE every farm for a web Command Center.
--
-- PRIVACY BY DESIGN (data minimisation):
--   * Coordinators see PRODUCTION & WELFARE data only — flocks, birds,
--     mortality, eggs, feed, vaccinations, activity recency.
--   * They do NOT get read access to the commercial ledger: egg SALES
--     (buyers, debts) and FINANCIAL transactions stay owner/manager-only,
--     enforced at RLS, not merely hidden in the UI.
--   * The per-farm activity feed coordinators see is REDACTED: sale lines
--     are stripped of buyer name and amounts.
--   * There is a beneficiary ROSTER so the scheme can reconcile "who was
--     given birds" against "who is actually using the app", surfacing
--     beneficiaries who never onboarded (the real blind spot).
--
-- NOTE ON WORDING: the activity log is append-only for app users via RLS
-- (tamper-resistant), NOT cryptographically immutable — a holder of the
-- service key or SQL editor can still alter it.
--
-- Depends on: h2r_farms_schema.sql, h2r_roles_schema.sql,
--             h2r_command_center.sql. Safe to re-run (idempotent).
-- ============================================================

-- ---------------- 1. Program admins (coordinators) -----------
create table if not exists h2r_program_admins (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  email    text not null default '',
  name     text not null default '',
  added_at timestamptz not null default now()
);

create or replace function h2r_is_program_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from h2r_program_admins a where a.user_id = auth.uid());
$$;

alter table h2r_program_admins enable row level security;
drop policy if exists "admins read roster" on h2r_program_admins;
create policy "admins read roster" on h2r_program_admins for select
  using (h2r_is_program_admin());

-- ---------------- 2. Enrollment (per onboarded farm) ---------
create table if not exists h2r_program_enrollment (
  farm_id          uuid primary key references h2r_farms(id) on delete cascade,
  region           text,
  district         text,
  farmer_name      text,
  contact          text,
  birds_allocated  integer,        -- official gov figure; null => derive from batches
  enrolled_at      timestamptz,
  notes            text,
  updated_at       timestamptz not null default now()
);
alter table h2r_program_enrollment enable row level security;
drop policy if exists "admins manage enrollment" on h2r_program_enrollment;
create policy "admins manage enrollment" on h2r_program_enrollment for all
  using (h2r_is_program_admin()) with check (h2r_is_program_admin());

-- ---------------- 2b. Official beneficiary roster ------------
-- Who the scheme GAVE birds to, independent of app usage. Lets the
-- dashboard reconcile the roster against real activity and surface
-- beneficiaries who never started logging (abandonment blind spot).
create table if not exists h2r_beneficiaries (
  id               uuid primary key default gen_random_uuid(),
  farmer_name      text not null,
  app_email        text,           -- the email they use / will use in the app
  region           text,
  district         text,
  contact          text,
  birds_allocated  integer,
  enrolled_at      timestamptz not null default now(),
  notes            text
);
alter table h2r_beneficiaries enable row level security;
drop policy if exists "admins manage roster" on h2r_beneficiaries;
create policy "admins manage roster" on h2r_beneficiaries for all
  using (h2r_is_program_admin()) with check (h2r_is_program_admin());
create index if not exists idx_h2r_beneficiaries_email on h2r_beneficiaries (lower(app_email));

-- ---------------- 3. Cross-farm READ access for admins -------
-- PRODUCTION & WELFARE tables only. egg_sales, financial_transactions
-- and the raw activity_log are DELIBERATELY EXCLUDED so a coordinator
-- cannot read a farmer's commercial ledger. Admins get no write policy
-- anywhere => read-only. Policies are OR'd, so farmers are unaffected.
do $$
declare t text;
begin
  foreach t in array array[
    'h2r_batches','h2r_vaccinations','h2r_feed_records','h2r_feed_inventory',
    'h2r_mortality','h2r_egg_production','h2r_farms','h2r_farm_members'
  ] loop
    execute format('drop policy if exists "program admin reads" on %I', t);
    execute format('create policy "program admin reads" on %I for select using (h2r_is_program_admin())', t);
  end loop;
  -- If a previous version granted admins the commercial tables, remove it.
  foreach t in array array['h2r_egg_sales','h2r_financial_transactions','h2r_activity_log'] loop
    execute format('drop policy if exists "program admin reads" on %I', t);
  end loop;
end;
$$;

-- ---------------- 4. National farmer registry ----------------
-- One row per ONBOARDED farm with production/welfare figures only (no
-- sales, no cash). last_active is derived from production records, not
-- the activity log, so coordinators need no access to it. Derived
-- metrics + at-risk flags are computed by the dashboard.
-- Dropped-then-created (not CREATE OR REPLACE) because the column set
-- changed from an earlier version, which REPLACE cannot do in place.
drop view if exists h2r_farmer_registry;
create view h2r_farmer_registry with (security_invoker = on) as
select
  f.id                              as farm_id,
  f.name                            as farm_name,
  f.created_at                      as created_at,
  (select m.email from h2r_farm_members m
     where m.farm_id = f.id and m.role = 'owner' limit 1) as owner_email,
  e.region, e.district, e.farmer_name, e.contact,
  e.birds_allocated                 as allocated_official,
  coalesce((select sum(b."initialCount") from h2r_batches b
     where b.farm_id = f.id and coalesce(b."deletedAt",'') = ''), 0) as birds_derived,
  coalesce((select sum(b."currentCount") from h2r_batches b
     where b.farm_id = f.id and coalesce(b."deletedAt",'') = ''), 0) as birds_alive,
  coalesce((select count(*) from h2r_batches b
     where b.farm_id = f.id and coalesce(b."deletedAt",'') = ''), 0) as batch_count,
  coalesce((select sum(m2."count") from h2r_mortality m2
     where m2.farm_id = f.id and coalesce(m2."deletedAt",'') = ''), 0) as total_deaths,
  coalesce((select sum(ep."eggCount") from h2r_egg_production ep
     where ep.farm_id = f.id and coalesce(ep."deletedAt",'') = ''), 0) as eggs_total,
  coalesce((select sum(fr."bagsUsed") from h2r_feed_records fr
     where fr.farm_id = f.id and coalesce(fr."deletedAt",'') = ''), 0) as feed_bags,
  coalesce((select count(*) from h2r_vaccinations v
     where v.farm_id = f.id and coalesce(v."deletedAt",'') = '' and v."status" = 1), 0) as vaccines_done,
  -- most recent PRODUCTION record (ISO text; good enough for "last seen")
  greatest(
    (select max(b."createdAt")  from h2r_batches b        where b.farm_id  = f.id and coalesce(b."deletedAt",'')  = ''),
    (select max(ep."createdAt") from h2r_egg_production ep where ep.farm_id = f.id and coalesce(ep."deletedAt",'') = ''),
    (select max(fr."createdAt") from h2r_feed_records fr   where fr.farm_id = f.id and coalesce(fr."deletedAt",'') = ''),
    (select max(m3."createdAt") from h2r_mortality m3      where m3.farm_id = f.id and coalesce(m3."deletedAt",'') = ''),
    (select max(vc."createdAt") from h2r_vaccinations vc   where vc.farm_id = f.id and coalesce(vc."deletedAt",'') = '')
  ) as last_active,
  -- oldest flock age in weeks (guarded cast so one bad date can't break the view)
  (select max(floor((extract(epoch from now()) -
        extract(epoch from (case when b."hatchDate" ~ '^\d{4}-\d\d-\d\d'
                                 then b."hatchDate"::timestamptz else null end))) / 604800))::int
     from h2r_batches b
     where b.farm_id = f.id and coalesce(b."deletedAt",'') = ''
       and b."hatchDate" ~ '^\d{4}-\d\d-\d\d') as oldest_weeks
from h2r_farms f
left join h2r_program_enrollment e on e.farm_id = f.id;

-- ---------------- 5. National totals (production only) -------
create or replace function h2r_program_overview()
returns json language sql stable security definer set search_path = public as $$
  select case when not h2r_is_program_admin() then null else (
    select json_build_object(
      'onboarded_farms', count(*),
      'birds_allocated', coalesce(sum(coalesce(e.birds_allocated,
                            (select sum(b."initialCount") from h2r_batches b
                               where b.farm_id = f.id and coalesce(b."deletedAt",'') = ''))), 0),
      'birds_alive',    coalesce(sum((select sum(b."currentCount") from h2r_batches b
                               where b.farm_id = f.id and coalesce(b."deletedAt",'') = '')), 0),
      'total_deaths',   coalesce(sum((select sum(m."count") from h2r_mortality m
                               where m.farm_id = f.id and coalesce(m."deletedAt",'') = '')), 0),
      'eggs_total',     coalesce(sum((select sum(ep."eggCount") from h2r_egg_production ep
                               where ep.farm_id = f.id and coalesce(ep."deletedAt",'') = '')), 0),
      'active_7d',      count(*) filter (where exists (
                            select 1 from h2r_activity_log a
                            where a.farm_id = f.id and a.logged_at >= now() - interval '7 days'))
    )
    from h2r_farms f
    left join h2r_program_enrollment e on e.farm_id = f.id
  ) end;
$$;

-- ---------------- 6. Redacted per-farm activity feed ---------
-- What a coordinator may see when drilling into a farm: production and
-- health events pass through; egg-sale lines are stripped of buyer and
-- amounts. Runs as definer + admin-gated, so no raw activity_log grant
-- is needed. A farm's own owner keeps the full feed via their own RLS.
create or replace function h2r_admin_farm_activity(fid uuid, lim int default 100)
returns table(actor_email text, action text, module text, batch_label text,
              summary text, amount numeric, logged_at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.actor_email, a.action, a.module, a.batch_label,
         case when a.module = 'sales' then 'recorded an egg sale' else a.summary end,
         case when a.module = 'sales' then null else a.amount end,
         a.logged_at
  from h2r_activity_log a
  where a.farm_id = fid and h2r_is_program_admin()
  order by a.logged_at desc
  limit lim;
$$;

-- ---------------- 6b. Re-assert accountability is owner-only --
-- An earlier build let program admins call this (exposing a farm's
-- cash handling). Coordinators must NOT see commercial figures, so we
-- restore the owner/manager-only guard here to converge older databases.
create or replace function h2r_worker_accountability(
  fid uuid, since timestamptz default now() - interval '30 days')
returns table(
  actor_id uuid, actor_email text, actor_role text,
  sales_count bigint, crates_sold numeric,
  cash_collected numeric, cash_owed numeric,
  eggs_logged numeric, deaths_logged numeric, feed_bags numeric,
  records_total bigint, last_active timestamptz
) language plpgsql stable security definer set search_path = public as $$
begin
  if not h2r_can_amend(fid) then
    raise exception 'Not authorised for this farm';
  end if;

  return query
  with acts as (
    select * from h2r_activity_log a
    where a.farm_id = fid and a.logged_at >= since
  ),
  sales as (
    select s.user_id,
           count(*)                                             as sales_count,
           coalesce(sum(s."eggCount")/30.0, 0)                  as crates_sold,
           coalesce(sum(s."amountPaid"), 0)                     as cash_collected,
           coalesce(sum(s."eggCount"*s."pricePerEgg" - s."amountPaid"), 0) as cash_owed
    from h2r_egg_sales s
    where s.farm_id = fid and coalesce(s."deletedAt",'') = ''
      and coalesce(nullif(s."createdAt",'')::timestamptz, now()) >= since
    group by s.user_id
  ),
  rollup as (
    select a.actor_id,
           max(a.actor_email) as actor_email,
           max(a.actor_role)  as actor_role,
           coalesce(sum(a.amount) filter (where a.module = 'eggs'), 0)      as eggs_logged,
           coalesce(sum(a.amount) filter (where a.module = 'mortality'), 0) as deaths_logged,
           coalesce(sum(a.amount) filter (where a.module = 'feed'), 0)      as feed_bags,
           count(*)           as records_total,
           max(a.logged_at)   as last_active
    from acts a
    group by a.actor_id
  )
  select r.actor_id, r.actor_email, r.actor_role,
         coalesce(sc.sales_count, 0), coalesce(sc.crates_sold, 0),
         coalesce(sc.cash_collected, 0), coalesce(sc.cash_owed, 0),
         r.eggs_logged, r.deaths_logged, r.feed_bags,
         r.records_total, r.last_active
  from rollup r
  left join sales sc on sc.user_id = r.actor_id
  order by r.records_total desc;
end;
$$;

-- ---------------- 7. Bootstrap the first admin ---------------
-- Makes the developer's own account a coordinator so the Command Center
-- can be tested immediately. Change/remove the email; add real
-- coordinators the same way (they must have signed into the app once).
insert into h2r_program_admins (user_id, email, name)
select id, email, 'Program Coordinator'
from auth.users
where email = 'brightdossantos99@gmail.com'
on conflict (user_id) do nothing;

-- ============================================================
-- The Command Center reads: h2r_farmer_registry (onboarded, production
-- only), h2r_beneficiaries (roster, for reconciliation),
-- h2r_program_overview(), h2r_program_enrollment (region/allocation
-- editing) and h2r_admin_farm_activity() (redacted per-farm feed).
-- Commercial data (sales, debtors, finances) is NOT exposed here.
-- ============================================================
