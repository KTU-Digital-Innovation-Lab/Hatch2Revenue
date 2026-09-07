-- Hatch2Revenue — in-app ratings & reviews.
--
-- Farmers rate the app (1–5 stars) and can leave a written review from
-- Settings → Rate this app. Every submission lands in this table.
--
-- WHERE THE DEVELOPER READS IT:
--   Supabase dashboard → Table Editor → h2r_feedback
--   Sort by created_at (newest first) or filter by rating. Export to CSV
--   from the same screen. The reviews are visible ONLY to you (via the
--   dashboard's service role); no app user can read another's feedback.
--
-- Apply once: paste this whole file into the Supabase SQL Editor and Run.

create table if not exists public.h2r_feedback (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid default auth.uid(),   -- filled by the server from the sign-in; null for offline/solo users
  user_email  text,                      -- convenience copy so you don't have to look up the id; may be null
  rating      int  not null check (rating between 1 and 5),
  review      text,                      -- optional written feedback
  app_version text,                      -- e.g. 1.7.1+21, so you know which build a review is about
  platform    text,                      -- android / ios / windows
  created_at  timestamptz not null default now()
);

create index if not exists idx_h2r_feedback_created
  on public.h2r_feedback (created_at desc);

alter table public.h2r_feedback enable row level security;

-- Anyone using the app — signed in or not — may leave feedback.
drop policy if exists "leave feedback" on public.h2r_feedback;
create policy "leave feedback"
  on public.h2r_feedback
  for insert
  to anon, authenticated
  with check (true);

-- No client role may read, edit, or delete feedback. Deliberately there
-- are no SELECT / UPDATE / DELETE policies, so the reviews are yours
-- alone through the dashboard.
