-- Friendlier farm invite codes + owner rotation.
-- Run ONCE in the Supabase SQL editor (project natotrarjgglxionrabw):
-- Dashboard -> SQL Editor -> paste this file -> Run.

-- 6 characters from an unambiguous alphabet: no 0/O, no 1/I/L, so the
-- code survives being read out over a phone call.
create or replace function h2r_friendly_code()
returns text
language sql
volatile
as $$
  select string_agg(
    substr('abcdefghjkmnpqrstuvwxyz23456789',
           1 + floor(random() * 31)::int, 1), '')
  from generate_series(1, 6);
$$;

-- New farms get friendly codes automatically.
alter table h2r_farms
  alter column invite_code set default h2r_friendly_code();

-- Owner-only rotation: the old code stops working immediately;
-- already-approved members are unaffected. Returns the new code.
create or replace function h2r_rotate_invite_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  farm_row h2r_farms%rowtype;
  new_code text;
begin
  select * into farm_row
  from h2r_farms
  where owner_id = auth.uid()
  limit 1;

  if farm_row.id is null then
    raise exception 'Only the farm owner can rotate the invite code';
  end if;

  loop
    new_code := h2r_friendly_code();
    begin
      update h2r_farms set invite_code = new_code where id = farm_row.id;
      exit;
    exception when unique_violation then
      -- astronomically rare collision - draw again
    end;
  end loop;

  return new_code;
end;
$$;

grant execute on function h2r_rotate_invite_code() to authenticated;
