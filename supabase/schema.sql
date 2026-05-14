-- Supabase schema foundation for Shared Housing Expenses.
-- The Flutter app still uses the local SharedPreferences repository by default.
--
-- Security note:
-- Row Level Security is enabled below. Phase 5 replaces the broad Phase 3/4
-- development policies with practical interim policies for anon-client testing.
-- Full production membership enforcement still requires Supabase Auth.
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

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_amount_cents_positive'
  ) then
    alter table public.expenses
      add constraint expenses_amount_cents_positive
      check (amount_cents > 0)
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_note_length'
  ) then
    alter table public.expenses
      add constraint expenses_note_length
      check (note is null or char_length(note) <= 200)
      not valid;
  end if;
end $$;

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

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'network_notifications_note_snippet_length'
  ) then
    alter table public.network_notifications
      add constraint network_notifications_note_snippet_length
      check (note_snippet is null or char_length(note_snippet) <= 80)
      not valid;
  end if;
end $$;

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

create index if not exists network_notifications_network_recipient_idx
  on public.network_notifications (network_id, recipient_member_id);

alter table public.networks enable row level security;
alter table public.network_members enable row level security;
alter table public.expenses enable row level security;
alter table public.network_notifications enable row level security;

create or replace function public.phase5_member_belongs_to_network(
  member_id uuid,
  target_network_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.network_members
    where id = member_id
      and network_id = target_network_id
  );
$$;

create or replace function public.phase5_expense_members_match_network(
  target_network_id uuid,
  paid_member_id uuid,
  added_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.phase5_member_belongs_to_network(paid_member_id, target_network_id)
    and public.phase5_member_belongs_to_network(added_member_id, target_network_id);
$$;

create or replace function public.phase5_notification_matches_network(
  target_network_id uuid,
  recipient_member_id uuid,
  actor_member_id uuid,
  target_expense_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.phase5_member_belongs_to_network(recipient_member_id, target_network_id)
    and (
      actor_member_id is null
      or public.phase5_member_belongs_to_network(actor_member_id, target_network_id)
    )
    and (
      target_expense_id is null
      or exists (
        select 1
        from public.expenses
        where id = target_expense_id
          and network_id = target_network_id
      )
    );
$$;

create or replace function public.phase5_prevent_notification_identity_update()
returns trigger
language plpgsql
as $$
begin
  if new.id <> old.id
    or new.network_id <> old.network_id
    or new.recipient_member_id <> old.recipient_member_id
    or coalesce(new.actor_member_id, '00000000-0000-0000-0000-000000000000'::uuid)
      <> coalesce(old.actor_member_id, '00000000-0000-0000-0000-000000000000'::uuid)
    or new.actor_member_name <> old.actor_member_name
    or coalesce(new.expense_id, '00000000-0000-0000-0000-000000000000'::uuid)
      <> coalesce(old.expense_id, '00000000-0000-0000-0000-000000000000'::uuid)
    or new.amount_cents <> old.amount_cents
    or new.currency_symbol <> old.currency_symbol
    or coalesce(new.note_snippet, '') <> coalesce(old.note_snippet, '')
    or new.created_at <> old.created_at
  then
    raise exception 'Only notification read state can be updated.';
  end if;

  return new;
end $$;

drop trigger if exists phase5_prevent_notification_identity_update
  on public.network_notifications;
create trigger phase5_prevent_notification_identity_update
  before update on public.network_notifications
  for each row
  execute function public.phase5_prevent_notification_identity_update();

-- Remove broad Phase 3/4 development policies before installing Phase 5.
drop policy if exists phase3_dev_select_networks on public.networks;
drop policy if exists phase3_dev_insert_networks on public.networks;
drop policy if exists phase3_dev_update_networks on public.networks;
drop policy if exists phase3_dev_select_members on public.network_members;
drop policy if exists phase3_dev_insert_members on public.network_members;
drop policy if exists phase4_dev_select_expenses on public.expenses;
drop policy if exists phase4_dev_insert_expenses on public.expenses;
drop policy if exists phase4_dev_select_notifications on public.network_notifications;
drop policy if exists phase4_dev_insert_notifications on public.network_notifications;
drop policy if exists phase4_dev_update_notifications on public.network_notifications;

drop policy if exists phase5_interim_lookup_networks on public.networks;
create policy phase5_interim_lookup_networks
  on public.networks
  for select
  using (
    normalized_name is not null
    and network_password_hash is not null
    and network_password_salt is not null
  );

drop policy if exists phase5_interim_create_networks on public.networks;
create policy phase5_interim_create_networks
  on public.networks
  for insert
  with check (
    length(trim(name)) > 0
    and length(trim(normalized_name)) > 0
    and network_password_hash is not null
    and network_password_salt is not null
  );

-- Allows the create flow to attach the first inserted member as network owner.
-- Later arbitrary network profile updates should move behind Auth-backed RPC.
drop policy if exists phase5_interim_claim_new_network_owner on public.networks;
create policy phase5_interim_claim_new_network_owner
  on public.networks
  for update
  using (created_by_member_id is null)
  with check (
    created_by_member_id is not null
    and public.phase5_member_belongs_to_network(created_by_member_id, id)
  );

drop policy if exists phase5_interim_read_members_for_login on public.network_members;
create policy phase5_interim_read_members_for_login
  on public.network_members
  for select
  using (
    network_id is not null
    and password_hash is not null
    and password_salt is not null
  );

drop policy if exists phase5_interim_join_networks on public.network_members;
create policy phase5_interim_join_networks
  on public.network_members
  for insert
  with check (
    exists (
      select 1
      from public.networks
      where id = network_id
    )
    and length(trim(name)) > 0
    and length(trim(normalized_name)) > 0
    and password_hash is not null
    and password_salt is not null
  );

drop policy if exists phase5_interim_read_network_expenses on public.expenses;
create policy phase5_interim_read_network_expenses
  on public.expenses
  for select
  using (
    public.phase5_expense_members_match_network(
      network_id,
      paid_by_member_id,
      added_by_member_id
    )
  );

drop policy if exists phase5_interim_insert_network_expenses on public.expenses;
create policy phase5_interim_insert_network_expenses
  on public.expenses
  for insert
  with check (
    amount_cents > 0
    and (note is null or char_length(note) <= 200)
    and public.phase5_expense_members_match_network(
      network_id,
      paid_by_member_id,
      added_by_member_id
    )
  );

drop policy if exists phase5_interim_read_addressed_notifications on public.network_notifications;
create policy phase5_interim_read_addressed_notifications
  on public.network_notifications
  for select
  using (
    public.phase5_notification_matches_network(
      network_id,
      recipient_member_id,
      actor_member_id,
      expense_id
    )
  );

drop policy if exists phase5_interim_insert_addressed_notifications on public.network_notifications;
create policy phase5_interim_insert_addressed_notifications
  on public.network_notifications
  for insert
  with check (
    amount_cents > 0
    and (note_snippet is null or char_length(note_snippet) <= 80)
    and public.phase5_notification_matches_network(
      network_id,
      recipient_member_id,
      actor_member_id,
      expense_id
    )
  );

-- The trigger above prevents changing notification identity/content. Without
-- Supabase Auth, RLS still cannot prove which human controls recipient_member_id.
drop policy if exists phase5_interim_mark_addressed_notifications_read
  on public.network_notifications;
create policy phase5_interim_mark_addressed_notifications_read
  on public.network_notifications
  for update
  using (
    public.phase5_notification_matches_network(
      network_id,
      recipient_member_id,
      actor_member_id,
      expense_id
    )
  )
  with check (
    is_read = true
    and public.phase5_notification_matches_network(
      network_id,
      recipient_member_id,
      actor_member_id,
      expense_id
    )
  );

comment on table public.networks is
  'Shared housing expense networks. Phase 5 policies are interim until Supabase Auth links members to auth.users.';
comment on table public.network_members is
  'Members inside a network with app-level password hash metadata.';
comment on table public.expenses is
  'Network expenses stored in cents with payer and record ownership fields.';
comment on table public.network_notifications is
  'Local-style notification records for cloud-backed network activity.';
