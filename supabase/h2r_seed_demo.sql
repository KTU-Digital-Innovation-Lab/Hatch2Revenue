-- ============================================================
-- Hatch2Revenue — DEMO SEED: sample beneficiary farmers
--
-- Populates the National Command Center with a small, realistic set
-- of farmers across Ghanaian regions so the dashboard looks alive for
-- a demo / defense. The six are chosen so EACH at-risk signal fires:
--
--   Ama Mensah    (Ashanti)       healthy, laying, 97% survival
--   Kwabena Osei  (Eastern)       disease outbreak -> HIGH MORTALITY + a credit sale outstanding
--   Efua Boateng  (Greater Accra) fine, but silent 20 days -> INACTIVE
--   Yaw Darko     (Northern)      100 birds unaccounted -> UNEXPLAINED LOSS (possible diversion)
--   Adjoa Owusu   (Volta)         laying-age flock, zero eggs -> NO PRODUCTION
--   Kofi Antwi    (Western)       new brooding flock, healthy
--
-- Run ORDER:  h2r_command_center.sql  ->  h2r_program_admin.sql  ->  THIS FILE.
-- (The activity feed is filled by the command-center triggers as the
--  rows below are inserted, so those must exist first.)
--
-- Idempotent: re-running skips if the demo farmers already exist.
-- Everything is tagged with @demo.hatch2revenue.gh emails + notes='DEMO
-- SEED', so it is trivial to remove (see the cleanup line at the end).
-- These accounts have no password and cannot sign in.
-- ============================================================

do $$
declare
  seed   record;
  uid    uuid;
  fid    uuid;
  bid    text;
  anchor timestamptz;   -- newest activity for this farmer
  hatch  timestamptz;   -- flock arrival
  alive  int;
begin
  if exists (select 1 from auth.users where email like '%@demo.hatch2revenue.gh') then
    raise notice 'Demo farmers already present - skipping.';
    return;
  end if;

  for seed in
    select * from (values
      --  name,           email,                               region,          farm,             alloc, wks, deaths, gap, eggDays, lastDays, profile
      ('Ama Mensah',    'ama.mensah@demo.hatch2revenue.gh',    'Ashanti',       'Mensah Poultry',   500,  24,    15,   0,     12,       0, 'healthy'),
      ('Kwabena Osei',  'kwabena.osei@demo.hatch2revenue.gh',  'Eastern',       'Osei Farms',       400,  20,   110,   0,      8,       1, 'mortality'),
      ('Efua Boateng',  'efua.boateng@demo.hatch2revenue.gh',  'Greater Accra', 'Boateng Layers',   300,  22,    10,   0,     10,      20, 'inactive'),
      ('Yaw Darko',     'yaw.darko@demo.hatch2revenue.gh',     'Northern',      'Darko Poultry',    500,  26,    20, 100,      9,       2, 'diversion'),
      ('Adjoa Owusu',   'adjoa.owusu@demo.hatch2revenue.gh',   'Volta',         'Owusu Farm',       350,  19,     8,   0,      0,       3, 'noeggs'),
      ('Kofi Antwi',    'kofi.antwi@demo.hatch2revenue.gh',    'Western',       'Antwi Birds',      250,   3,     3,   0,      0,       0, 'brooding')
    ) as v(name,email,region,farm,alloc,wks,deaths,gap,egg_days,last_days,profile)
  loop
    uid    := gen_random_uuid();
    fid    := gen_random_uuid();
    hatch  := now() - (seed.wks || ' weeks')::interval;
    anchor := now() - (seed.last_days || ' days')::interval;
    alive  := seed.alloc - seed.deaths - seed.gap;   -- 'gap' = birds that vanished unlogged
    bid    := 'seed-' || left(md5(seed.email), 8);

    -- 1) A minimal auth user (no password; cannot log in)
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', seed.email, null, now(),
      hatch, now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('name', seed.name),
      '', '', '', '', '', '', '', ''
    );

    -- 2) Their farm (trigger auto-adds the owner membership + feed catalog)
    insert into h2r_farms (id, name, owner_id, created_at) values (fid, seed.farm, uid, hatch);
    update h2r_farm_members set email = seed.email where farm_id = fid and user_id = uid;

    -- 3) Program enrollment (per farm) + roster entry (matches by email)
    insert into h2r_program_enrollment (farm_id, region, farmer_name, birds_allocated, enrolled_at, notes)
      values (fid, seed.region, seed.name, seed.alloc, hatch, 'DEMO SEED');
    insert into h2r_beneficiaries (farmer_name, app_email, region, birds_allocated, enrolled_at, notes)
      values (seed.name, seed.email, seed.region, seed.alloc, hatch, 'DEMO SEED');

    -- 4) The flock. currentCount = alive (for the diversion case this is
    --    far below allocation - deaths, which is what the dashboard flags).
    insert into h2r_batches (id,user_id,farm_id,name,type,"initialCount","currentCount","hatchDate","createdAt","updatedAt")
      values (bid, uid, fid, 'Batch '||to_char(now(),'YYYY')||'-1',
        case when seed.wks < 4 then 0 when seed.wks < 16 then 1 else 2 end,
        seed.alloc, alive,
        to_char(hatch,'YYYY-MM-DD"T"HH24:MI:SS'),
        to_char(hatch,'YYYY-MM-DD"T"HH24:MI:SS'),
        to_char(hatch,'YYYY-MM-DD"T"HH24:MI:SS'));

    -- 5) Mortality: two entries (disease for the outbreak farmer)
    if seed.deaths > 0 then
      insert into h2r_mortality (id,user_id,farm_id,"batchId","date","count","cause","createdAt","updatedAt")
      select gen_random_uuid()::text, uid, fid, bid,
        to_char(anchor-(g*4||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
        case when g = 0 then ceil(seed.deaths/2.0)::int else floor(seed.deaths/2.0)::int end,
        case when seed.profile = 'mortality' then 0 else 5 end,   -- 0=disease, 5=unknown
        to_char(anchor-(g*4||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
        to_char(anchor-(g*4||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS')
      from generate_series(0,1) as g;
    end if;

    -- 6) Feed: two entries, feed type by flock age
    insert into h2r_feed_records (id,user_id,farm_id,"batchId","date","feedType","bagsUsed","kgPerBag","unitPricePerBag","createdAt","updatedAt")
    select gen_random_uuid()::text, uid, fid, bid,
      to_char(anchor-(g*3||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
      case when seed.wks < 4 then 0 when seed.wks < 16 then 1 else 2 end,
      2+g, 50, 480,
      to_char(anchor-(g*3||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
      to_char(anchor-(g*3||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS')
    from generate_series(0,1) as g;

    -- 7) Laying farmers only: daily eggs, a completed vaccine, one sale
    if seed.egg_days > 0 then
      insert into h2r_egg_production (id,user_id,farm_id,"batchId","date","eggCount","damagedCount","pricePerEgg","createdAt","updatedAt")
      select gen_random_uuid()::text, uid, fid, bid,
        to_char(anchor-(d||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
        greatest(0, round(alive*0.68 + (random()*40 - 20)))::int, round(random()*4)::int, 1.4,
        to_char(anchor-(d||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
        to_char(anchor-(d||' days')::interval,'YYYY-MM-DD"T"HH24:MI:SS')
      from generate_series(0, seed.egg_days - 1) as d;

      insert into h2r_vaccinations (id,user_id,farm_id,"batchId","vaccineName","type","scheduledDate","status","administeredDate","createdAt","updatedAt")
      values (gen_random_uuid()::text, uid, fid, bid, 'Newcastle Disease', 0,
        to_char(anchor-'5 days'::interval,'YYYY-MM-DD"T"HH24:MI:SS'), 1,
        to_char(anchor-'5 days'::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
        to_char(anchor-'5 days'::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
        to_char(anchor-'5 days'::interval,'YYYY-MM-DD"T"HH24:MI:SS'));

      -- 600 eggs (20 crates) at GHS 1.40; outbreak farmer's buyer still owes half
      insert into h2r_egg_sales (id,user_id,farm_id,"date","buyer","eggCount","pricePerEgg","amountPaid","createdAt","updatedAt")
      values (gen_random_uuid()::text, uid, fid,
        to_char(anchor-'2 days'::interval,'YYYY-MM-DD"T"HH24:MI:SS'), 'Market Trader',
        600, 1.4, case when seed.profile = 'mortality' then 420 else 840 end,
        to_char(anchor-'2 days'::interval,'YYYY-MM-DD"T"HH24:MI:SS'),
        to_char(anchor-'2 days'::interval,'YYYY-MM-DD"T"HH24:MI:SS'));
    end if;

  end loop;

  -- Two beneficiaries GIVEN birds but who never onboarded onto the app.
  -- They have no farm and no records, so the Command Center should show
  -- them as "not onboarded" — the abandonment blind spot made visible.
  insert into h2r_beneficiaries (farmer_name, app_email, region, birds_allocated, enrolled_at, notes)
  values
    ('Mariama Sule', 'mariama.sule@demo.hatch2revenue.gh', 'Savannah', 400, now() - '8 weeks'::interval, 'DEMO SEED'),
    ('Kojo Asante',  'kojo.asante@demo.hatch2revenue.gh',  'Bono',     300, now() - '6 weeks'::interval, 'DEMO SEED');

  -- Backdate the auto-logged activity so "last active" matches the demo
  -- dates (the trigger stamps logged_at = now(); occurred_at holds the
  -- real record date). This is what makes the INACTIVE farmer show as
  -- quiet for 20 days.
  update h2r_activity_log a set logged_at = a.occurred_at
  where a.farm_id in (select farm_id from h2r_program_enrollment where notes = 'DEMO SEED');

  raise notice 'Seeded % demo farmers.',
    (select count(*) from h2r_program_enrollment where notes = 'DEMO SEED');
end;
$$;

-- ------------------------------------------------------------
-- CLEANUP (run when you no longer want the demo data). Deleting the
-- auth users cascades to their farms, records and activity log; the
-- beneficiary roster has no FK, so clear it explicitly:
--
--   delete from auth.users where email like '%@demo.hatch2revenue.gh';
--   delete from h2r_beneficiaries where notes = 'DEMO SEED';
-- ------------------------------------------------------------
