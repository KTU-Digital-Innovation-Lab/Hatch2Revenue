-- ============================================================
-- Hatch2Revenue v13 cloud mirrors
--
-- Adds the server side for the v13 client migration:
--   * batches.supplier  (source of chicks / hatchery)
--   * h2r_measurements   (flock weight / temperature / water logs)
--   * h2r_poultry_houses (houses / coops)
--
-- Same conventions as every other h2r_* mirror: camelCase quoted
-- columns matched 1:1 to the local SQLite tables, farm-scoped RLS from
-- the roles model, and the h2r_touch trigger driving server_updated_at.
-- Depends on h2r_farms_schema.sql + h2r_roles_schema.sql. Safe to re-run.
-- ============================================================

-- Source of chicks on the batch mirror.
alter table h2r_batches add column if not exists "supplier" text;

-- ---------------- measurements (weight/temperature/water) ----
create table if not exists h2r_measurements (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  farm_id uuid references h2r_farms(id) on delete cascade,
  "batchId" text not null default '',
  "date" text not null default '',
  "type" integer not null default 0,     -- 0=weight, 1=temperature, 2=water
  "value" double precision not null default 0,
  "notes" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);
alter table h2r_measurements enable row level security;

drop trigger if exists trg_h2r_measurements_touch on h2r_measurements;
create trigger trg_h2r_measurements_touch
  before insert or update on h2r_measurements
  for each row execute function h2r_touch();

create index if not exists idx_h2r_measurements_pull on h2r_measurements (user_id, server_updated_at);
create index if not exists idx_h2r_measurements_farm on h2r_measurements (farm_id, server_updated_at);

-- Workers log readings; owner/manager amend; the whole team reads.
drop policy if exists "measurements read" on h2r_measurements;
create policy "measurements read" on h2r_measurements for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_approved(farm_id)));
drop policy if exists "measurements insert" on h2r_measurements;
create policy "measurements insert" on h2r_measurements for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_log(farm_id)));
drop policy if exists "measurements update" on h2r_measurements;
create policy "measurements update" on h2r_measurements for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
drop policy if exists "measurements delete" on h2r_measurements;
create policy "measurements delete" on h2r_measurements for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));

-- ---------------- poultry houses -----------------------------
create table if not exists h2r_poultry_houses (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  farm_id uuid references h2r_farms(id) on delete cascade,
  "name" text not null default '',
  "capacity" integer not null default 0,
  "location" text,
  "notes" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);
alter table h2r_poultry_houses enable row level security;

drop trigger if exists trg_h2r_poultry_houses_touch on h2r_poultry_houses;
create trigger trg_h2r_poultry_houses_touch
  before insert or update on h2r_poultry_houses
  for each row execute function h2r_touch();

create index if not exists idx_h2r_poultry_houses_pull on h2r_poultry_houses (user_id, server_updated_at);
create index if not exists idx_h2r_poultry_houses_farm on h2r_poultry_houses (farm_id, server_updated_at);

-- Owner/manager set up houses; the whole team reads.
drop policy if exists "houses read" on h2r_poultry_houses;
create policy "houses read" on h2r_poultry_houses for select using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_is_approved(farm_id)));
drop policy if exists "houses insert" on h2r_poultry_houses;
create policy "houses insert" on h2r_poultry_houses for insert with check (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and user_id = auth.uid() and h2r_can_amend(farm_id)));
drop policy if exists "houses update" on h2r_poultry_houses;
create policy "houses update" on h2r_poultry_houses for update using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
drop policy if exists "houses delete" on h2r_poultry_houses;
create policy "houses delete" on h2r_poultry_houses for delete using (
  (farm_id is null and user_id = auth.uid())
  or (farm_id is not null and h2r_can_amend(farm_id)));
