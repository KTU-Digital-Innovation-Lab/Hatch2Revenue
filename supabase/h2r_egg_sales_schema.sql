-- Cloud mirror for the egg sales & debtors ledger (local table:
-- egg_sales, DB v10). Same conventions as every other h2r_* mirror:
-- camelCase quoted columns, per-user rows unless farm-scoped,
-- h2r_touch trigger driving server_updated_at pulls.
-- NOTE: the app starts syncing this table only when 'egg_sales' is
-- added to DatabaseService.syncedTables (client work, separate).

create table if not exists h2r_egg_sales (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  farm_id uuid references h2r_farms(id) on delete cascade,
  "date" text not null default '',
  "buyer" text not null default '',
  "eggCount" integer not null default 0,
  "pricePerEgg" double precision not null default 0,
  "amountPaid" double precision not null default 0,
  "notes" text,
  "createdAt" text not null default '',
  "updatedAt" text not null default '',
  "deletedAt" text,
  server_updated_at timestamptz not null default now()
);

alter table h2r_egg_sales enable row level security;

drop policy if exists "own or approved farm rows" on h2r_egg_sales;
create policy "own or approved farm rows" on h2r_egg_sales for all
  using (
    (farm_id is null and user_id = auth.uid())
    or (farm_id is not null and h2r_is_approved(farm_id))
  )
  with check (
    (farm_id is null and user_id = auth.uid())
    or (farm_id is not null and h2r_is_approved(farm_id))
  );

drop trigger if exists trg_h2r_egg_sales_touch on h2r_egg_sales;
create trigger trg_h2r_egg_sales_touch
  before insert or update on h2r_egg_sales
  for each row execute function h2r_touch();

create index if not exists idx_h2r_egg_sales_pull
  on h2r_egg_sales (user_id, server_updated_at);
create index if not exists idx_h2r_egg_sales_farm
  on h2r_egg_sales (farm_id, server_updated_at);
