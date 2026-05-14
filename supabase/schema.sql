-- Supabase schema foundation for Shared Housing Expenses.
-- Phase 2 creates the cloud data model only. The Flutter app still uses the
-- local SharedPreferences repository by default.
--
-- Security note:
-- Row Level Security is enabled below, but policies are intentionally deferred
-- to Phase 3/4 when the authentication and membership model is activated.
-- Do not use a Supabase service-role key in the Flutter app.

create extension if not exists pgcrypto;

create table if not exists public.networks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  normalized_name text unique not null,
  network_password_hash text,
  network_password_salt text,
  currency_code text not null default 'USD',
  currency_symbol text not null default '$',
  created_by_member_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.network_members (
  id uuid primary key default gen_random_uuid(),
  network_id uuid not null references public.networks(id) on delete cascade,
  name text not null,
  normalized_name text not null,
  password_hash text,
  password_salt text,
  created_at timestamptz not null default now(),
  unique (network_id, normalized_name)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'networks_created_by_member_id_fkey'
  ) then
    alter table public.networks
      add constraint networks_created_by_member_id_fkey
      foreign key (created_by_member_id)
      references public.network_members(id)
      on delete set null;
  end if;
end $$;

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  network_id uuid not null references public.networks(id) on delete cascade,
  paid_by_member_id uuid not null references public.network_members(id),
  paid_by_member_name text not null,
  added_by_member_id uuid not null references public.network_members(id),
  added_by_member_name text not null,
  amount_cents bigint not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.network_notifications (
  id uuid primary key default gen_random_uuid(),
  network_id uuid not null references public.networks(id) on delete cascade,
  recipient_member_id uuid not null references public.network_members(id) on delete cascade,
  actor_member_id uuid references public.network_members(id),
  actor_member_name text not null,
  expense_id uuid references public.expenses(id) on delete cascade,
  amount_cents bigint not null,
  currency_symbol text not null,
  note_snippet text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists networks_normalized_name_idx
  on public.networks (normalized_name);

create index if not exists network_members_network_id_idx
  on public.network_members (network_id);

create index if not exists network_members_network_id_normalized_name_idx
  on public.network_members (network_id, normalized_name);

create index if not exists expenses_network_id_created_at_idx
  on public.expenses (network_id, created_at desc);

create index if not exists expenses_paid_by_member_id_idx
  on public.expenses (paid_by_member_id);

create index if not exists expenses_added_by_member_id_idx
  on public.expenses (added_by_member_id);

create index if not exists network_notifications_recipient_read_created_idx
  on public.network_notifications (recipient_member_id, is_read, created_at desc);

alter table public.networks enable row level security;
alter table public.network_members enable row level security;
alter table public.expenses enable row level security;
alter table public.network_notifications enable row level security;

comment on table public.networks is
  'Shared housing expense networks. RLS policies are added in a later phase.';
comment on table public.network_members is
  'Members inside a network with app-level password hash metadata.';
comment on table public.expenses is
  'Network expenses stored in cents with payer and record ownership fields.';
comment on table public.network_notifications is
  'Local-style notification records for cloud-backed network activity.';
