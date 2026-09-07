-- ============================================================
-- Hatch2Revenue — Command / Operations Center backend
--
-- Turns the farm's synced records into a single, tamper-proof
-- ACTIVITY LOG that an owner/manager can watch from a web
-- dashboard: who did what, on which batch, for how much, and when.
--
-- Design:
--   * One append-only table, h2r_activity_log.
--   * Database triggers on every operational table write ONE
--     human-readable line to it whenever a row is inserted, amended
--     or soft-deleted. The line records user_id -> email/role, so a
--     worker's action is always attributed ("logged by ...").
--   * APPEND-ONLY: no UPDATE/DELETE policy exists, and only the
--     SECURITY DEFINER trigger writes rows, so a collection cannot
--     be quietly un-logged. This is the anti-theft guarantee.
--   * Only farm-scoped rows (farm_id not null) are logged — solo
--     users have no team to monitor and stay fully private.
--   * Read access is owner/manager only (h2r_can_amend), the same
--     people who may already see money and the debtor ledger.
--
-- Safe to re-run (idempotent). Requires the roles + farms schema
-- (h2r_farms_schema.sql, h2r_roles_schema.sql) to be in place.
-- ============================================================

-- ---------------- 1. The log table ---------------------------
create table if not exists h2r_activity_log (
  id            bigint generated always as identity primary key,
  farm_id       uuid not null references h2r_farms(id) on delete cascade,
  actor_id      uuid,                       -- user_id of the record's author
  actor_email   text not null default '',   -- denormalised at write time
  actor_role    text not null default '',
  action        text not null,              -- created | edited | completed | deleted
  module        text not null,              -- eggs|feed|mortality|sales|vaccination|batch
  entity_id     text,                       -- id of the source row
  batch_id      text,
  batch_label   text,
  summary       text not null default '',   -- ready-to-read line
  amount        numeric,                    -- money or count relevant to the event
  meta          jsonb not null default '{}'::jsonb,
  occurred_at   timestamptz not null default now(), -- app-reported time (createdAt)
  logged_at     timestamptz not null default now()  -- server time (ordering / realtime)
);

create index if not exists idx_h2r_activity_farm  on h2r_activity_log (farm_id, logged_at desc);
create index if not exists idx_h2r_activity_actor on h2r_activity_log (farm_id, actor_id);
create index if not exists idx_h2r_activity_mod   on h2r_activity_log (farm_id, module);

-- ---------------- 2. Small lookup helpers --------------------
-- Enum -> label maps mirror the Dart enums so the feed reads well.
create or replace function h2r_feed_name(v int)
returns text language sql immutable as $$
  select case v
    when 0 then 'Starter' when 1 then 'Grower' when 2 then 'Layer'
    when 3 then 'Finisher' when 4 then 'Custom' else 'feed' end;
$$;

create or replace function h2r_cause_name(v int)
returns text language sql immutable as $$
  select case v
    when 0 then 'disease' when 1 then 'predator' when 2 then 'heat stress'
    when 3 then 'cold' when 4 then 'suffocation' else 'unknown cause' end;
$$;

-- Who the actor is, resolved from the farm roster (falls back to auth).
create or replace function h2r_actor_email(fid uuid, uid uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select email from h2r_farm_members where farm_id = fid and user_id = uid limit 1),
    (select email from auth.users where id = uid),
    'unknown');
$$;

create or replace function h2r_actor_role(fid uuid, uid uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    case when exists (select 1 from h2r_farms f where f.id = fid and f.owner_id = uid)
         then 'owner' end,
    (select role from h2r_farm_members where farm_id = fid and user_id = uid limit 1),
    '');
$$;

-- ---------------- 3. The trigger that writes the log ---------
create or replace function h2r_log_activity()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  mod      text := tg_argv[0];
  j        jsonb := to_jsonb(new);
  oj       jsonb;
  fid      uuid;
  uid      uuid;
  bId      text;
  blabel   text;
  act      text;
  summ     text := '';
  amt      numeric;
  meta     jsonb := '{}'::jsonb;
  ec numeric; ppe numeric; paid numeric; total numeric; owed numeric;
  newstatus int; oldstatus int;
begin
  fid := nullif(j->>'farm_id','')::uuid;
  if fid is null then
    return new;                       -- solo / private row: never logged
  end if;
  uid := nullif(j->>'user_id','')::uuid;
  bId := nullif(j->>'batchId','');

  -- Decide the action, and skip pure re-syncs (only the server clock moved).
  if tg_op = 'INSERT' then
    act := 'created';
  else
    oj := to_jsonb(old);
    if coalesce(oj->>'deletedAt','') = '' and coalesce(j->>'deletedAt','') <> '' then
      act := 'deleted';
    elsif (j - 'server_updated_at' - 'updatedAt') = (oj - 'server_updated_at' - 'updatedAt') then
      return new;                     -- nothing meaningful changed
    else
      act := 'edited';
    end if;
  end if;

  -- Batch label for context (the batch's own name for the batch module).
  if mod = 'batch' then
    blabel := nullif(j->>'name','');
  elsif bId is not null then
    select "name" into blabel from h2r_batches where id = bId and farm_id = fid limit 1;
  end if;

  -- Build a readable line + structured meta per module.
  if act = 'deleted' then
    summ := format('removed a %s record', mod);
  elsif mod = 'eggs' then
    amt  := coalesce(nullif(j->>'eggCount','')::numeric, 0);
    summ := format('%s %s eggs (%s crates)',
              case when act = 'edited' then 'corrected' else 'logged' end,
              coalesce(j->>'eggCount','0'), to_char(amt/30.0, 'FM999990.0'));
    meta := jsonb_build_object('eggs', amt, 'damaged', nullif(j->>'damagedCount','')::numeric);
  elsif mod = 'feed' then
    amt  := coalesce(nullif(j->>'bagsUsed','')::numeric, 0);
    summ := format('%s %s bag(s) of %s feed',
              case when act = 'edited' then 'corrected' else 'logged' end,
              coalesce(j->>'bagsUsed','0'), h2r_feed_name(nullif(j->>'feedType','')::int));
    meta := jsonb_build_object('bags', amt, 'feedType', nullif(j->>'feedType','')::int);
  elsif mod = 'mortality' then
    amt  := coalesce(nullif(j->>'count','')::numeric, 0);
    summ := format('%s %s death(s)%s',
              case when act = 'edited' then 'amended' else 'recorded' end,
              coalesce(j->>'count','0'),
              case when nullif(j->>'cause','') is not null
                   then ' · ' || h2r_cause_name((j->>'cause')::int) else '' end);
    meta := jsonb_build_object('deaths', amt, 'cause', nullif(j->>'cause','')::int);
  elsif mod = 'sales' then
    ec    := coalesce(nullif(j->>'eggCount','')::numeric, 0);
    ppe   := coalesce(nullif(j->>'pricePerEgg','')::numeric, 0);
    paid  := coalesce(nullif(j->>'amountPaid','')::numeric, 0);
    total := ec * ppe;
    owed  := total - paid;
    amt   := total;
    summ  := format('%s %s crates to %s · ₵%s%s',
               case when act = 'edited' then 'amended sale of' else 'sold' end,
               to_char(ec/30.0, 'FM999990.0'),
               coalesce(nullif(j->>'buyer',''), 'a buyer'),
               to_char(total, 'FM999990.00'),
               case when owed > 0.005 then ' · owes ₵' || to_char(owed, 'FM999990.00')
                    else ' · paid' end);
    meta  := jsonb_build_object('buyer', j->>'buyer', 'total', total,
               'paid', paid, 'owed', owed, 'crates', round(ec/30.0, 1));
  elsif mod = 'vaccination' then
    newstatus := coalesce(nullif(j->>'status','')::int, 0);
    if act = 'created' then
      summ := format('scheduled %s', coalesce(nullif(j->>'vaccineName',''), 'a vaccine'));
    else
      oldstatus := coalesce(nullif(oj->>'status','')::int, 0);
      if newstatus = 1 and oldstatus <> 1 then
        act  := 'completed';
        summ := format('marked %s done', coalesce(nullif(j->>'vaccineName',''), 'a vaccine'));
      else
        summ := format('updated %s', coalesce(nullif(j->>'vaccineName',''), 'a vaccine'));
      end if;
    end if;
    meta := jsonb_build_object('vaccine', j->>'vaccineName', 'status', newstatus);
  elsif mod = 'batch' then
    amt  := coalesce(nullif(j->>'initialCount','')::numeric, 0);
    if act = 'created' then
      summ := format('created batch %s · %s birds',
                coalesce(nullif(j->>'name',''), '(unnamed)'), coalesce(j->>'initialCount','0'));
    else
      summ := format('updated batch %s', coalesce(nullif(j->>'name',''), '(unnamed)'));
    end if;
    meta := jsonb_build_object('initial', amt, 'current', nullif(j->>'currentCount','')::numeric);
  else
    summ := format('%s a %s record', act, mod);
  end if;

  insert into h2r_activity_log(
    farm_id, actor_id, actor_email, actor_role, action, module,
    entity_id, batch_id, batch_label, summary, amount, meta, occurred_at)
  values (
    fid, uid, h2r_actor_email(fid, uid), h2r_actor_role(fid, uid), act, mod,
    j->>'id', bId, blabel, summ, amt, meta,
    coalesce(nullif(j->>'createdAt','')::timestamptz, now()));

  return new;
end;
$$;

-- ---------------- 4. Wire the trigger to each table ----------
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('h2r_egg_production', 'eggs'),
      ('h2r_feed_records',   'feed'),
      ('h2r_mortality',      'mortality'),
      ('h2r_egg_sales',      'sales'),
      ('h2r_vaccinations',   'vaccination'),
      ('h2r_batches',        'batch')
    ) as v(tbl, moduleName)
  loop
    execute format('drop trigger if exists trg_%s_activity on %I', r.moduleName, r.tbl);
    execute format(
      'create trigger trg_%s_activity after insert or update on %I '
      'for each row execute function h2r_log_activity(%L)',
      r.moduleName, r.tbl, r.moduleName);
  end loop;
end;
$$;

-- ---------------- 5. Backfill existing history (one-time) ----
-- Only runs when the log is empty, so re-running the script is safe.
do $$
begin
  if (select count(*) from h2r_activity_log) = 0 then

    insert into h2r_activity_log(farm_id, actor_id, actor_email, actor_role, action,
      module, entity_id, batch_id, batch_label, summary, amount, meta, occurred_at, logged_at)
    select e.farm_id, e.user_id, h2r_actor_email(e.farm_id, e.user_id),
      h2r_actor_role(e.farm_id, e.user_id), 'created', 'eggs', e.id, e."batchId",
      (select "name" from h2r_batches b where b.id = e."batchId" and b.farm_id = e.farm_id),
      format('logged %s eggs (%s crates)', e."eggCount", to_char(e."eggCount"/30.0,'FM999990.0')),
      e."eggCount", jsonb_build_object('eggs', e."eggCount"),
      coalesce(nullif(e."createdAt",'')::timestamptz, now()),
      coalesce(nullif(e."createdAt",'')::timestamptz, now())
    from h2r_egg_production e
    where e.farm_id is not null and coalesce(e."deletedAt",'') = '';

    insert into h2r_activity_log(farm_id, actor_id, actor_email, actor_role, action,
      module, entity_id, batch_id, batch_label, summary, amount, meta, occurred_at, logged_at)
    select f.farm_id, f.user_id, h2r_actor_email(f.farm_id, f.user_id),
      h2r_actor_role(f.farm_id, f.user_id), 'created', 'feed', f.id, f."batchId",
      (select "name" from h2r_batches b where b.id = f."batchId" and b.farm_id = f.farm_id),
      format('logged %s bag(s) of %s feed', f."bagsUsed", h2r_feed_name(f."feedType")),
      f."bagsUsed", jsonb_build_object('bags', f."bagsUsed", 'feedType', f."feedType"),
      coalesce(nullif(f."createdAt",'')::timestamptz, now()),
      coalesce(nullif(f."createdAt",'')::timestamptz, now())
    from h2r_feed_records f
    where f.farm_id is not null and coalesce(f."deletedAt",'') = '';

    insert into h2r_activity_log(farm_id, actor_id, actor_email, actor_role, action,
      module, entity_id, batch_id, batch_label, summary, amount, meta, occurred_at, logged_at)
    select m.farm_id, m.user_id, h2r_actor_email(m.farm_id, m.user_id),
      h2r_actor_role(m.farm_id, m.user_id), 'created', 'mortality', m.id, m."batchId",
      (select "name" from h2r_batches b where b.id = m."batchId" and b.farm_id = m.farm_id),
      format('recorded %s death(s)%s', m."count",
        case when m."cause" is not null then ' · '||h2r_cause_name(m."cause") else '' end),
      m."count", jsonb_build_object('deaths', m."count", 'cause', m."cause"),
      coalesce(nullif(m."createdAt",'')::timestamptz, now()),
      coalesce(nullif(m."createdAt",'')::timestamptz, now())
    from h2r_mortality m
    where m.farm_id is not null and coalesce(m."deletedAt",'') = '';

    insert into h2r_activity_log(farm_id, actor_id, actor_email, actor_role, action,
      module, entity_id, batch_id, batch_label, summary, amount, meta, occurred_at, logged_at)
    select s.farm_id, s.user_id, h2r_actor_email(s.farm_id, s.user_id),
      h2r_actor_role(s.farm_id, s.user_id), 'created', 'sales', s.id, null, null,
      format('sold %s crates to %s · ₵%s%s',
        to_char(s."eggCount"/30.0,'FM999990.0'), coalesce(nullif(s."buyer",''),'a buyer'),
        to_char(s."eggCount"*s."pricePerEgg",'FM999990.00'),
        case when s."eggCount"*s."pricePerEgg" - s."amountPaid" > 0.005
             then ' · owes ₵'||to_char(s."eggCount"*s."pricePerEgg" - s."amountPaid",'FM999990.00')
             else ' · paid' end),
      s."eggCount"*s."pricePerEgg",
      jsonb_build_object('buyer', s."buyer", 'total', s."eggCount"*s."pricePerEgg",
        'paid', s."amountPaid", 'owed', s."eggCount"*s."pricePerEgg" - s."amountPaid",
        'crates', round(s."eggCount"/30.0,1)),
      coalesce(nullif(s."createdAt",'')::timestamptz, now()),
      coalesce(nullif(s."createdAt",'')::timestamptz, now())
    from h2r_egg_sales s
    where s.farm_id is not null and coalesce(s."deletedAt",'') = '';

    insert into h2r_activity_log(farm_id, actor_id, actor_email, actor_role, action,
      module, entity_id, batch_id, batch_label, summary, amount, meta, occurred_at, logged_at)
    select v.farm_id, v.user_id, h2r_actor_email(v.farm_id, v.user_id),
      h2r_actor_role(v.farm_id, v.user_id),
      case when v."status" = 1 then 'completed' else 'created' end, 'vaccination', v.id, v."batchId",
      (select "name" from h2r_batches b where b.id = v."batchId" and b.farm_id = v.farm_id),
      case when v."status" = 1 then format('marked %s done', v."vaccineName")
           else format('scheduled %s', v."vaccineName") end,
      null, jsonb_build_object('vaccine', v."vaccineName", 'status', v."status"),
      coalesce(nullif(v."createdAt",'')::timestamptz, now()),
      coalesce(nullif(v."createdAt",'')::timestamptz, now())
    from h2r_vaccinations v
    where v.farm_id is not null and coalesce(v."deletedAt",'') = '';

    insert into h2r_activity_log(farm_id, actor_id, actor_email, actor_role, action,
      module, entity_id, batch_id, batch_label, summary, amount, meta, occurred_at, logged_at)
    select b.farm_id, b.user_id, h2r_actor_email(b.farm_id, b.user_id),
      h2r_actor_role(b.farm_id, b.user_id), 'created', 'batch', b.id, b.id, b."name",
      format('created batch %s · %s birds', coalesce(nullif(b."name",''),'(unnamed)'), b."initialCount"),
      b."initialCount", jsonb_build_object('initial', b."initialCount", 'current', b."currentCount"),
      coalesce(nullif(b."createdAt",'')::timestamptz, now()),
      coalesce(nullif(b."createdAt",'')::timestamptz, now())
    from h2r_batches b
    where b.farm_id is not null and coalesce(b."deletedAt",'') = '';

  end if;
end;
$$;

-- ---------------- 6. Row-level security ----------------------
-- Read: owner/manager of the farm. Write: only the trigger (definer).
-- No update/delete policy => the log can never be altered. Append-only.
alter table h2r_activity_log enable row level security;

drop policy if exists "read activity" on h2r_activity_log;
create policy "read activity" on h2r_activity_log for select
  using (h2r_can_amend(farm_id));

-- ---------------- 7. Per-worker accountability ---------------
-- The transparency lens: for each teammate over [since], how much
-- they sold, collected, are still owed, and how many records they made.
-- Owner/manager only; enforced inside since this runs as definer.
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

-- ---------------- 8. Anomaly flags ---------------------------
-- Things worth a second look. security_invoker => the caller's RLS
-- applies, so an owner only ever sees their own farm's flags.
create or replace view h2r_activity_flags with (security_invoker = on) as
  -- Outstanding credit sales (buyer still owes money)
  select s.farm_id,
         case when s."amountPaid" = 0 then 'no_payment' else 'credit_outstanding' end as kind,
         case when s."amountPaid" = 0 then 'high' else 'medium' end as severity,
         h2r_actor_email(s.farm_id, s.user_id) as actor_email,
         format('%s owes ₵%s on a ₵%s sale',
           coalesce(nullif(s."buyer",''),'a buyer'),
           to_char(s."eggCount"*s."pricePerEgg" - s."amountPaid",'FM999990.00'),
           to_char(s."eggCount"*s."pricePerEgg",'FM999990.00')) as summary,
         s.id as ref_id,
         coalesce(nullif(s."createdAt",'')::timestamptz, now()) as occurred_at
  from h2r_egg_sales s
  where coalesce(s."deletedAt",'') = ''
    and s."eggCount"*s."pricePerEgg" - s."amountPaid" > 0.005

  union all
  -- Unusually large single mortality entry (tunable threshold)
  select m.farm_id, 'big_mortality', 'high',
         h2r_actor_email(m.farm_id, m.user_id),
         format('%s deaths recorded in one entry%s', m."count",
           case when m."cause" is not null then ' · '||h2r_cause_name(m."cause") else '' end),
         m.id, coalesce(nullif(m."createdAt",'')::timestamptz, now())
  from h2r_mortality m
  where coalesce(m."deletedAt",'') = '' and m."count" >= 20

  union all
  -- Records edited or removed after creation (owner/manager amendments)
  select a.farm_id, 'record_amended', 'low', a.actor_email,
         format('%s %s: %s', a.actor_email, a.action, a.summary),
         a.entity_id, a.logged_at
  from h2r_activity_log a
  where a.action in ('edited', 'deleted');

-- ---------------- 9. Realtime for the live feed --------------
do $$
begin
  begin
    alter publication supabase_realtime add table h2r_activity_log;
  exception
    when duplicate_object then null;   -- already published
    when undefined_object then null;   -- publication missing (older projects)
  end;
end;
$$;

-- ============================================================
-- Done. The web dashboard reads h2r_activity_log (live),
-- h2r_worker_accountability(farm_id) and h2r_activity_flags.
-- ============================================================
