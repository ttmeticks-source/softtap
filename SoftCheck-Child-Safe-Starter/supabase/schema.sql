-- SoftCheck child-safe foundation. Run in Supabase SQL Editor.
-- IMPORTANT: schema alone does not establish COPPA/GDPR compliance.
-- Never put the service_role key in a mobile app.

create extension if not exists pgcrypto;

create table if not exists public.guardian_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  contact_email text not null,
  created_at timestamptz not null default now()
);

-- Consent is written/updated ONLY by a trusted server-side function after
-- the consent method has been reviewed and verified. No client insert/update.
create table if not exists public.guardian_consents (
  id uuid primary key default gen_random_uuid(),
  guardian_user_id uuid not null references auth.users(id) on delete cascade,
  child_ref uuid not null default gen_random_uuid(),
  status text not null default 'pending' check (status in ('pending','verified','revoked','expired')),
  consent_method text,
  consent_scope jsonb not null default '{"checkins":true,"friends":false,"messages":false,"video_uploads":false,"push_notifications":false}'::jsonb,
  verified_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.child_profiles (
  id uuid primary key default gen_random_uuid(),
  guardian_user_id uuid not null references auth.users(id) on delete cascade,
  consent_id uuid not null unique references public.guardian_consents(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 1 and 24),
  social_enabled boolean not null default false,
  messages_enabled boolean not null default false,
  video_uploads_enabled boolean not null default false,
  push_notifications_enabled boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.child_checkins (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.child_profiles(id) on delete cascade,
  checkin_date date not null,
  mood text not null check (mood in ('great','okay','meh','low','rough')),
  note text check (char_length(coalesce(note, '')) <= 1000),
  created_at timestamptz not null default now(),
  unique (child_id, checkin_date)
);

create table if not exists public.child_friendships (
  id uuid primary key default gen_random_uuid(),
  requester_child_id uuid not null references public.child_profiles(id) on delete cascade,
  target_child_id uuid not null references public.child_profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','blocked')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  check (requester_child_id <> target_child_id),
  unique (requester_child_id, target_child_id)
);

create table if not exists public.child_messages (
  id uuid primary key default gen_random_uuid(),
  friendship_id uuid not null references public.child_friendships(id) on delete cascade,
  sender_child_id uuid not null references public.child_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now(),
  moderation_status text not null default 'pending' check (moderation_status in ('pending','approved','hidden','removed'))
);

create table if not exists public.child_blocks (
  blocker_child_id uuid not null references public.child_profiles(id) on delete cascade,
  blocked_child_id uuid not null references public.child_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_child_id, blocked_child_id),
  check (blocker_child_id <> blocked_child_id)
);

create table if not exists public.child_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_child_id uuid references public.child_profiles(id) on delete set null,
  reported_child_id uuid references public.child_profiles(id) on delete set null,
  message_id uuid references public.child_messages(id) on delete set null,
  reason text not null check (char_length(reason) between 3 and 100),
  details text check (char_length(coalesce(details, '')) <= 1000),
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);

alter table public.guardian_profiles enable row level security;
alter table public.guardian_consents enable row level security;
alter table public.child_profiles enable row level security;
alter table public.child_checkins enable row level security;
alter table public.child_friendships enable row level security;
alter table public.child_messages enable row level security;
alter table public.child_blocks enable row level security;
alter table public.child_reports enable row level security;

-- Parent can read/update only their guardian profile.
create policy "guardian reads own profile" on public.guardian_profiles
  for select to authenticated using (auth.uid() = user_id);
create policy "guardian inserts own profile" on public.guardian_profiles
  for insert to authenticated with check (auth.uid() = user_id);
create policy "guardian updates own profile" on public.guardian_profiles
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Intentionally NO client policies for guardian_consents. With RLS enabled and
-- no policies, client access is denied. A trusted Edge Function/server must verify consent.
-- No client policies for child_profiles yet: child provisioning must be server-controlled.
-- No client policies for social tables yet: do not enable child social features until
-- consent checks, parent controls, accepted-friend enforcement, blocking, moderation,
-- retention/deletion and abuse limits are implemented and independently tested.

-- Before launch, add narrowly scoped policies/functions that enforce ALL of:
-- 1) verified and unrevoked guardian consent for each requested feature;
-- 2) parent-controlled feature switches on every server request;
-- 3) messages only within an accepted friendship and never across a block;
-- 4) reports, moderation, abuse-rate limits, safe storage and account deletion;
-- 5) least-privilege access for parent and child data.
