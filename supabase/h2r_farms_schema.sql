-- ============================================================
-- Hatch2Revenue Phase A — Farms, worker approval, feed catalog
--
-- * Owners create a farm; workers join with an invite code and sit
--   in "pending" until the owner APPROVES them. RLS hides all farm
--   data from non-approved members — enforced server-side.
-- * h2r_feed_catalog holds the owner-set official feed prices.
--   Strictly the owner can change them; every change is audited.
-- ============================================================

create table h2r_farms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  invite_code text unique not null default substr(md5(random()::text), 1, 8),
  created_at timestamptz not null default now(),
  server_updated_at timestamptz not null default now()
);

create table h2r_farm_members (
  farm_id uuid not null references h2r_farms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null default '',
  role text not null default 'worker',
  status text not null default 'pending', -- pending | approved | rejected
  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  server_updated_at timestamptz not null default now(),
  primary key (farm_id, user_id)
);

create table h2r_feed_catalog (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references h2r_farms(id) on delete cascade,
  feed_name text not null,
  price_per_bag numeric(12,2) not null,
  kg_per_bag numeric(6,1) not null default 50,
  market_min numeric(12,2),
  market_max numeric(12,2),
  server_updated_at timestamptz not null default now(),
  unique (farm_id, feed_name)
);

create table h2r_feed_price_history (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references h2r_farms(id) on delete cascade,
  feed_name text not null,
  old_price numeric(12,2),
  new_price numeric(12,2) not null,
  changed_by uuid,
  changed_at timestamptz not null default now()
);

-- Helper: is the caller an APPROVED member (or the owner) of [farm]?
create or replace function h2r_is_approved(farm uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from h2r_farms f where f.id = farm and f.owner_id = auth.uid()
  ) or exists (
    select 1 from h2r_farm_members m
    where m.farm_id = farm and m.user_id = auth.uid() and m.status = 'approved'
  );
$$;

create or replace function h2r_is_owner(farm uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from h2r_farms f where f.id = farm and f.owner_id = auth.uid()
  );
$$;

-- Creating a farm: owner joins as approved member + the feed catalog
-- is seeded with the owner-provided market defaults (GHS, 50 kg bags).
create or replace function h2r_setup_new_farm()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into h2r_farm_members (farm_id, user_id, email, role, status, approved_at)
  values (
    new.id, new.owner_id,
    coalesce((select email from auth.users where id = new.owner_id), ''),
    'owner', 'approved', now()
  );
  insert into h2r_feed_catalog (farm_id, feed_name, price_per_bag, kg_per_bag, market_min, market_max)
  values
    (new.id, 'Chick Starter',    365, 50, 360, 370),
    (new.id, 'Grower Mash',      435, 50, 350, 520),
    (new.id, 'Layer Mash',       480, 50, 357, 600),
    (new.id, 'Broiler Starter',  405, 50, 400, 410),
    (new.id, 'Broiler Finisher', 385, 50, 380, 390);
  return new;
end;
$$;

create trigger trg_h2r_setup_new_farm
after insert on h2r_farms
for each row execute function h2r_setup_new_farm();

-- Audit every price change (strictly-owner writes are enforced by RLS;
-- this trigger records who changed what).
create or replace function h2r_audit_price_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.price_per_bag is distinct from old.price_per_bag then
    insert into h2r_feed_price_history (farm_id, feed_name, old_price, new_price, changed_by)
    values (new.farm_id, new.feed_name, old.price_per_bag, new.price_per_bag, auth.uid());
  end if;
  new.server_updated_at := now();
  return new;
end;
$$;

create trigger trg_h2r_audit_price
before update on h2r_feed_catalog
for each row execute function h2r_audit_price_change();

-- Join a farm by invite code → lands as PENDING worker. The owner
-- must approve before any farm data becomes visible.
create or replace function h2r_join_farm(code text)
returns json language plpgsql security definer set search_path = public as $$
declare
  f record;
  existing text;
begin
  select id, name into f from h2r_farms
  where lower(invite_code) = lower(trim(code));
  if f.id is null then
    raise exception 'Invalid invite code';
  end if;

  select status into existing from h2r_farm_members
  where farm_id = f.id and user_id = auth.uid();

  if existing is null then
    insert into h2r_farm_members (farm_id, user_id, email)
    values (
      f.id, auth.uid(),
      coalesce((select email from auth.users where id = auth.uid()), '')
    );
    existing := 'pending';
  end if;

  return json_build_object('farm_id', f.id, 'farm_name', f.name, 'status', existing);
end;
$$;

-- Fetch the caller's membership (works while still pending).
create or replace function h2r_my_membership()
returns json language plpgsql stable security definer set search_path = public as $$
declare
  m record;
begin
  select fm.farm_id, fm.role, fm.status, f.name, f.invite_code, f.owner_id
    into m
  from h2r_farm_members fm
  join h2r_farms f on f.id = fm.farm_id
  where fm.user_id = auth.uid() and fm.status <> 'rejected'
  order by fm.requested_at desc
  limit 1;
  if m.farm_id is null then
    return null;
  end if;
  return json_build_object(
    'farm_id', m.farm_id, 'farm_name', m.name, 'role', m.role,
    'status', m.status,
    'invite_code', case when m.owner_id = auth.uid() then m.invite_code else null end
  );
end;
$$;

-- ---------------- RLS ----------------------------------------

alter table h2r_farms enable row level security;
alter table h2r_farm_members enable row level security;
alter table h2r_feed_catalog enable row level security;
alter table h2r_feed_price_history enable row level security;

create policy "members read farm" on h2r_farms for select
  using (owner_id = auth.uid() or exists (
    select 1 from h2r_farm_members m
    where m.farm_id = id and m.user_id = auth.uid()
  ));
create policy "create own farm" on h2r_farms for insert
  with check (owner_id = auth.uid());
create policy "owner updates farm" on h2r_farms for update
  using (owner_id = auth.uid());

create policy "see own or managed memberships" on h2r_farm_members for select
  using (user_id = auth.uid() or h2r_is_owner(farm_id));
create policy "owner manages members" on h2r_farm_members for update
  using (h2r_is_owner(farm_id));
create policy "owner removes members, member leaves" on h2r_farm_members for delete
  using (user_id = auth.uid() or h2r_is_owner(farm_id));

create policy "approved read catalog" on h2r_feed_catalog for select
  using (h2r_is_approved(farm_id));
create policy "strictly owner writes catalog" on h2r_feed_catalog for update
  using (h2r_is_owner(farm_id));
create policy "strictly owner adds catalog" on h2r_feed_catalog for insert
  with check (h2r_is_owner(farm_id));
create policy "strictly owner deletes catalog" on h2r_feed_catalog for delete
  using (h2r_is_owner(farm_id));

create policy "approved read price history" on h2r_feed_price_history for select
  using (h2r_is_approved(farm_id));

-- Data tables become farm-scoped. Solo users (no farm) keep working:
-- rows without a farm stay private to their author.
do $$
declare t text;
begin
  foreach t in array array[
    'h2r_batches', 'h2r_vaccinations', 'h2r_feed_records',
    'h2r_feed_inventory', 'h2r_mortality', 'h2r_egg_production',
    'h2r_financial_transactions'
  ] loop
    execute format('alter table %I add column if not exists farm_id uuid references h2r_farms(id) on delete cascade', t);
    execute format('drop policy if exists "own rows" on %I', t);
    execute format(
      'create policy "own or approved farm rows" on %I for all using (
         (farm_id is null and user_id = auth.uid())
         or (farm_id is not null and h2r_is_approved(farm_id))
       ) with check (
         (farm_id is null and user_id = auth.uid())
         or (farm_id is not null and h2r_is_approved(farm_id))
       )', t);
    execute format('create index if not exists idx_%s_farm on %I (farm_id, server_updated_at)', t, t);
  end loop;
end;
$$;
