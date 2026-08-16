-- Community hackathons (posted by anyone, NO login required)
-- Run this once in the Supabase SQL editor.
-- Safe to re-run even if an earlier version was already run.

-- Community hackathons posted by visitors. Separate from the auto-fetched
-- `hackathons` table so the daily finder never touches them.
create table if not exists public.user_hackathons (
  id          serial primary key,
  user_name   text,
  title       text not null,
  description text,
  start_date  date,        -- registration starts
  deadline    date,        -- registration deadline; post is auto-deleted after this
  website     text,
  contact     text,
  delete_pass text,        -- poster's 6-digit password; required to delete
  is_active   boolean default true,
  created_at  timestamptz default now()
);

-- Make an older version of the table compatible: drop the login-only policies
-- and column first, then add/rename columns.
drop policy if exists "users insert own" on public.user_hackathons;
drop policy if exists "users update own" on public.user_hackathons;
drop policy if exists "users delete own" on public.user_hackathons;
alter table public.user_hackathons drop column if exists user_id;
alter table public.user_hackathons add column if not exists start_date date;
alter table public.user_hackathons add column if not exists deadline date;
-- Sort out delete_pass vs the old delete_token: if only delete_token exists,
-- rename it; if both exist, copy any old passwords over and drop the old column.
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='user_hackathons'
               and column_name='delete_token') then
    if exists (select 1 from information_schema.columns
               where table_schema='public' and table_name='user_hackathons'
                 and column_name='delete_pass') then
      update public.user_hackathons set delete_pass = delete_token
       where delete_pass is null and delete_token is not null;
      alter table public.user_hackathons drop column delete_token;
    else
      alter table public.user_hackathons rename column delete_token to delete_pass;
    end if;
  end if;
end $$;
alter table public.user_hackathons add column if not exists delete_pass text;

drop index if exists user_hackathons_delete_token_idx;
create unique index if not exists user_hackathons_delete_pass_idx on public.user_hackathons (delete_pass);
create index if not exists user_hackathons_active_idx on public.user_hackathons (is_active, deadline);

-- RLS: anyone can read + insert posts. Direct table deletes are blocked for
-- everyone; deletion ONLY works through delete_post() below, which checks the
-- poster's 6-digit password. This is what lets each user delete only their own post.
alter table public.user_hackathons enable row level security;

drop policy if exists "public read user_hackathons" on public.user_hackathons;
create policy "public read user_hackathons"
  on public.user_hackathons for select using (true);

drop policy if exists "public insert user_hackathons" on public.user_hackathons;

-- HIDE the secret delete_pass from the public. Anyone can read the post's public
-- fields (title, dates, contact...) but NOT the password column, so nobody can
-- steal it and delete someone else's post. Only the poster's browser knows the
-- password; delete_post() checks it server-side. Inserting is done ONLY through
-- insert_community_post() below (a server function), never directly.
revoke all on public.user_hackathons from anon, authenticated;
grant select (id, user_name, title, description, start_date, deadline, website, contact, is_active, created_at)
  on public.user_hackathons to anon, authenticated;
grant usage on sequence public.user_hackathons_id_seq to anon, authenticated;

-- Post a hackathon (validates input server-side, returns only the new id).
drop function if exists public.insert_community_post(text,text,text,date,date,text,text,text);
create or replace function public.insert_community_post(
  p_user_name text, p_title text, p_description text, p_start_date date,
  p_deadline date, p_website text, p_contact text, p_delete_pass text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare new_id integer;
begin
  if p_title is null or trim(p_title) = '' then
    raise exception 'Title is required';
  end if;
  if p_deadline is null then
    raise exception 'Deadline is required';
  end if;
  if p_delete_pass is null or p_delete_pass !~ '^[0-9]{6}$' then
    raise exception 'Delete password must be exactly 6 digits';
  end if;
  insert into public.user_hackathons
    (user_name, title, description, start_date, deadline, website, contact, delete_pass)
  values (p_user_name, p_title, p_description, p_start_date, p_deadline, p_website, p_contact, p_delete_pass)
  returning id into new_id;
  return jsonb_build_object('id', new_id);
end;
$$;
grant execute on function public.insert_community_post(text,text,text,date,date,text,text,text) to anon, authenticated;

-- Delete a post ONLY if the caller provides the correct 6-digit password.
-- Runs as the table owner (security definer) but only deletes the matching row,
-- so nobody can delete someone else's post.
drop function if exists public.delete_post(integer, text);
create or replace function public.delete_post(p_id integer, p_pass text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare deleted integer;
begin
  if p_pass is null or p_pass = '' then
    return false;
  end if;
  delete from public.user_hackathons
   where id = p_id and delete_pass = p_pass
   returning 1 into deleted;
  return coalesce(deleted, 0) = 1;
end;
$$;
grant execute on function public.delete_post(integer, text) to anon, authenticated;

-- List the posts belonging to a set of passwords (used by "My Posts").
drop function if exists public.my_posts(text[]);
create or replace function public.my_posts(passes text[])
returns setof public.user_hackathons
language sql
security definer
set search_path = public
as $$
  select * from public.user_hackathons where delete_pass = any(passes);
$$;
grant execute on function public.my_posts(text[]) to anon, authenticated;

-- Not used anymore (no login): drop if it exists from the earlier version.
drop function if exists public.delete_my_account();

-- AUTO-REMOVE expired posts: runs daily at 22:30 UTC (= 4:00 AM IST). Posts whose
-- deadline has passed get deleted from the database, freeing storage automatically.
-- (If you already scheduled this once, it will not duplicate.)
create extension if not exists pg_cron;
select cron.unschedule('delete-expired-community')
  where exists (select 1 from cron.job where jobname = 'delete-expired-community');
select cron.schedule('delete-expired-community', '30 22 * * *',
  $$ delete from public.user_hackathons where deadline is not null and deadline < current_date $$);
