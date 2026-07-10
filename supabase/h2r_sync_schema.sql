-- ============================================================
-- Hatch2Revenue cloud sync tables
-- Mirrors of the app's local SQLite tables (camelCase columns
-- quoted so the client can push/pull rows without any mapping).
-- Per-user isolation via RLS; server_updated_at drives pulls.
-- Lives in the same Supabase project as FarmNest, namespaced h2r_*.
-- ============================================================

create or replace function h2r_touch()
returns trigger language plpgsql as $$
begin
  new.server_updated_at := now();
  if new.user_id is null then
    new.user_id := auth.uid();
  end if;
  return new;
end;
$$;

-- ------------------------------------------------------------

create table h2r_batches (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  "name" text not null default '',
  "description" text,
  "type" integer not null default 0,
  "initialCount" integer not null default 0,
  "currentCount" integer not null default 0,
  "hatchDate" text not null default '',
  "source" text,
  "initialCost" double precision,
  "coopId" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

create table h2r_vaccinations (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  "batchId" text not null default '',
  "vaccineName" text not null default '',
  "type" integer not null default 0,
  "scheduledDate" text not null default '',
  "administeredDate" text,
  "status" integer not null default 0,
  "dosage" double precision,
  "unit" text,
  "administeredBy" text,
  "notes" text,
  "reminderEnabled" integer not null default 0,
  "reminderDaysBefore" integer not null default 0,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

create table h2r_feed_records (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  "batchId" text not null default '',
  "date" text not null default '',
  "feedType" integer not null default 0,
  "bagsUsed" integer not null default 0,
  "kgPerBag" double precision not null default 50,
  "unitPricePerBag" double precision not null default 0,
  "supplier" text,
  "batchNumber" text,
  "notes" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

create table h2r_feed_inventory (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  "feedTypeName" text not null default '',
  "quantityKg" double precision not null default 0,
  "unitPrice" double precision not null default 0,
  "expiryDate" text not null default '',
  "supplier" text,
  "batchNumber" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

create table h2r_mortality (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  "batchId" text not null default '',
  "date" text not null default '',
  "count" integer not null default 0,
  "cause" integer,
  "notes" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

create table h2r_egg_production (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  "batchId" text not null default '',
  "date" text not null default '',
  "eggCount" integer not null default 0,
  "damagedCount" integer not null default 0,
  "pricePerEgg" double precision not null default 0,
  "notes" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

create table h2r_financial_transactions (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  "date" text not null default '',
  "type" integer not null default 0,
  "category" integer not null default 0,
  "amount" double precision not null default 0,
  "description" text,
  "batchId" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

-- RLS + triggers + pull index for every h2r table -------------

do $$
declare t text;
begin
  foreach t in array array[
    'h2r_batches', 'h2r_vaccinations', 'h2r_feed_records',
    'h2r_feed_inventory', 'h2r_mortality', 'h2r_egg_production',
    'h2r_financial_transactions'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format(
      'create policy "own rows" on %I for all '
      'using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t
    );
    execute format(
      'create trigger trg_%s_touch before insert or update on %I '
      'for each row execute function h2r_touch()',
      t, t
    );
    execute format(
      'create index idx_%s_pull on %I (user_id, server_updated_at)',
      t, t
    );
  end loop;
end;
$$;
