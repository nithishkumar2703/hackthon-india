-- ============================================================
-- HACKATHON INDIA - DATABASE SETUP
-- How to use: Supabase Dashboard > SQL Editor > New query
-- Copy this whole file, paste, click "Run".
-- ============================================================

-- 1. STATES (all Indian states/UTs)
create table states (
  id           serial primary key,
  name         text unique not null
);

insert into states (name) values
  ('Andhra Pradesh'), ('Arunachal Pradesh'), ('Assam'), ('Bihar'),
  ('Chhattisgarh'), ('Goa'), ('Gujarat'), ('Haryana'),
  ('Himachal Pradesh'), ('Jharkhand'), ('Karnataka'), ('Kerala'),
  ('Madhya Pradesh'), ('Maharashtra'), ('Manipur'), ('Meghalaya'),
  ('Mizoram'), ('Nagaland'), ('Odisha'), ('Punjab'),
  ('Rajasthan'), ('Sikkim'), ('Tamil Nadu'), ('Telangana'),
  ('Tripura'), ('Uttar Pradesh'), ('Uttarakhand'), ('West Bengal'),
  ('Andaman and Nicobar'), ('Chandigarh'), ('Delhi'), ('Jammu and Kashmir'),
  ('Ladakh'), ('Puducherry');

-- 2. ORGANIZERS (contact details - kept separate so one org can run many hackathons)
create table organizers (
  id           serial primary key,
  name         text not null,
  email        text,
  phone        text,          -- store as 91XXXXXXXXXX (no +, no spaces)
  whatsapp     text,          -- store as 91XXXXXXXXXX
  website      text
);

-- 3. HACKATHONS
create table hackathons (
  id            serial primary key,
  title         text not null,
  tagline       text,
  description   text,
  state_id      int references states(id),   -- null = online hackathon
  city          text,
  venue         text,
  mode          text default 'hybrid',      -- online | offline | hybrid
  start_date    date,
  end_date      date,
  deadline      date,
  thumbnail_url text,
  website_url   text,
  organizer_id  int references organizers(id),
  prize_pool    text,
  max_team_size int,
  is_active     boolean default true,
  created_at    timestamptz default now()
);

create index idx_hackathons_state on hackathons (state_id, start_date);

-- 4. COMMUNITY SUBMISSIONS (for the "Submit a hackathon" feature later)
create table submissions (
  id           serial primary key,
  email        text not null,
  title        text not null,
  state        text,
  description  text,
  url          text,
  status       text default 'pending',      -- pending | approved | rejected
  created_at   timestamptz default now()
);

-- 5. SECURITY RULES (anyone can READ hackathons/states; only server can write)
alter table hackathons enable row level security;
alter table states     enable row level security;
alter table organizers enable row level security;
alter table submissions enable row level security;

create policy "public read hackathons" on hackathons for select using (true);
create policy "public read states"     on states     for select using (true);
create policy "public read organizers" on organizers for select using (true);
create policy "public insert submissions" on submissions for insert with check (true);
create policy "public read submissions"   on submissions for select using (true);

-- 6. SAMPLE DATA (so the app has something to show immediately)
insert into organizers (name, email, phone, whatsapp, website) values
  ('Smart India Hackathon Team', 'sih@aicte-india.org', '911234567890', '911234567890', 'https://sih.gov.in');

insert into hackathons
  (title, tagline, description, state_id, city, venue, mode, start_date, end_date, deadline,
   thumbnail_url, website_url, organizer_id, prize_pool, max_team_size)
values
  ('Smart India Hackathon 2026', 'India''s biggest hackathon', 'A national-level hackathon where students solve real-world problems given by ministries and industries.',
   11, 'Online', 'Online', 'online', '2026-09-15', '2026-09-16', '2026-09-01',
   'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=400', 'https://sih.gov.in', 1, '₹1,00,000', 6);

-- Now add one hackathon for every state so every state shows results:
insert into hackathons (title, tagline, description, state_id, city, mode, start_date, end_date, deadline, website_url, organizer_id, prize_pool)
select
  'Demo Hackathon - ' || s.name,
  'Your state''s demo hackathon',
  'This is sample data so the app has content. Replace it with real hackathons.',
  s.id, 'Demo City', 'hybrid', '2026-10-01', '2026-10-02', '2026-09-20',
  'https://hackathon.devpost.com', 1, '₹50,000'
from states s;
