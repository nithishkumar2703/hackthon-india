-- Run this ONLY if you already ran setup.sql before.
-- It lets online hackathons have no state (so they only appear in the "Online" list).
alter table hackathons alter column state_id drop not null;
