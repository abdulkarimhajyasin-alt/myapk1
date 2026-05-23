-- Supabase schema foundation for Maskan.
-- The Flutter app uses Supabase as its only network data source.
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
  avatar_color text,
  avatar_initials text,
  avatar_image_path text,
  avatar_image_url text,
  created_at timestamptz not null default now(),
  unique (network_id, normalized_name)
);

alter table public.network_members
  add column if not exists avatar_color text;
alter table public.network_members
  add column if not exists avatar_initials text;
alter table public.network_members
  add column if not exists avatar_image_path text;
alter table public.network_members
  add column if not exists avatar_image_url text;

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
  cycle_id uuid,
  paid_by_member_id uuid references public.network_members(id) on delete set null,
  paid_by_member_name text not null,
  added_by_member_id uuid references public.network_members(id) on delete set null,
  added_by_member_name text not null,
  amount_cents bigint not null,
  note text,
  archived_at timestamptz,
  client_generated_id text,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'expenses'
      and column_name = 'cycle_id'
  ) then
    alter table public.expenses add column cycle_id uuid;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'expenses'
      and column_name = 'archived_at'
  ) then
    alter table public.expenses add column archived_at timestamptz;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'expenses'
      and column_name = 'client_generated_id'
  ) then
    alter table public.expenses add column client_generated_id text;
  end if;

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

create table if not exists public.expense_cycles (
  id uuid primary key default gen_random_uuid(),
  network_id uuid not null references public.networks(id) on delete cascade,
  cycle_number integer not null,
  started_at timestamptz not null default now(),
  closed_at timestamptz,
  status text not null default 'active',
  requested_by_member_id uuid references public.network_members(id) on delete set null,
  requested_by_member_name text,
  unique (network_id, cycle_number)
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'expense_cycles_status_valid'
  ) then
    alter table public.expense_cycles
      add constraint expense_cycles_status_valid
      check (status in ('active', 'pending_reset', 'closed'))
      not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_cycle_id_fkey'
  ) then
    alter table public.expenses
      add constraint expenses_cycle_id_fkey
      foreign key (cycle_id)
      references public.expense_cycles(id)
      on delete set null;
  end if;
end $$;

insert into public.expense_cycles (network_id, cycle_number, started_at, status)
select networks.id, 1, networks.created_at, 'active'
from public.networks
where not exists (
  select 1
  from public.expense_cycles
  where expense_cycles.network_id = networks.id
);

create table if not exists public.expense_reset_requests (
  id uuid primary key default gen_random_uuid(),
  network_id uuid not null references public.networks(id) on delete cascade,
  cycle_id uuid not null references public.expense_cycles(id) on delete cascade,
  requested_by_member_id uuid references public.network_members(id) on delete set null,
  requested_by_member_name text not null,
  status text not null default 'pending',
  required_member_ids uuid[] not null default '{}',
  required_member_names text[] not null default '{}',
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.expense_reset_approvals (
  id uuid primary key default gen_random_uuid(),
  reset_request_id uuid not null references public.expense_reset_requests(id) on delete cascade,
  network_id uuid not null references public.networks(id) on delete cascade,
  member_id uuid not null references public.network_members(id) on delete cascade,
  member_name text not null,
  approved_at timestamptz not null default now(),
  unique (reset_request_id, member_id)
);

do $$
begin
  alter table public.expenses
    alter column paid_by_member_id drop not null,
    alter column added_by_member_id drop not null;

  alter table public.expense_reset_requests
    alter column requested_by_member_id drop not null;

  if exists (
    select 1
    from pg_constraint
    where conname = 'expenses_paid_by_member_id_fkey'
  ) then
    alter table public.expenses
      drop constraint expenses_paid_by_member_id_fkey;
  end if;

  if exists (
    select 1
    from pg_constraint
    where conname = 'expenses_added_by_member_id_fkey'
  ) then
    alter table public.expenses
      drop constraint expenses_added_by_member_id_fkey;
  end if;

  if exists (
    select 1
    from pg_constraint
    where conname = 'expense_reset_requests_requested_by_member_id_fkey'
  ) then
    alter table public.expense_reset_requests
      drop constraint expense_reset_requests_requested_by_member_id_fkey;
  end if;

  alter table public.expenses
    add constraint expenses_paid_by_member_id_fkey
    foreign key (paid_by_member_id)
    references public.network_members(id)
    on delete set null
    not valid;

  alter table public.expenses
    add constraint expenses_added_by_member_id_fkey
    foreign key (added_by_member_id)
    references public.network_members(id)
    on delete set null
    not valid;

  alter table public.expense_reset_requests
    add constraint expense_reset_requests_requested_by_member_id_fkey
    foreign key (requested_by_member_id)
    references public.network_members(id)
    on delete set null
    not valid;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'expense_reset_requests_status_valid'
  ) then
    alter table public.expense_reset_requests
      add constraint expense_reset_requests_status_valid
      check (status in ('pending', 'completed', 'cancelled'))
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
  kind text not null default 'expense',
  reset_request_id uuid references public.expense_reset_requests(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'network_notifications'
      and column_name = 'kind'
  ) then
    alter table public.network_notifications
      add column kind text not null default 'expense';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'network_notifications'
      and column_name = 'reset_request_id'
  ) then
    alter table public.network_notifications
      add column reset_request_id uuid references public.expense_reset_requests(id) on delete cascade;
  end if;

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

  if not exists (
    select 1
    from pg_constraint
    where conname = 'network_notifications_kind_valid'
  ) then
    alter table public.network_notifications
      add constraint network_notifications_kind_valid
      check (kind in ('expense', 'resetRequest', 'cycleStarted'))
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

create index if not exists expenses_cycle_id_idx
  on public.expenses (cycle_id);

create index if not exists expenses_active_network_idx
  on public.expenses (network_id, archived_at);

create index if not exists expense_cycles_network_status_idx
  on public.expense_cycles (network_id, status);

create unique index if not exists expense_cycles_one_active_idx
  on public.expense_cycles (network_id)
  where status = 'active';

create index if not exists expense_reset_requests_network_status_idx
  on public.expense_reset_requests (network_id, status, created_at desc);

create unique index if not exists expense_reset_requests_one_pending_idx
  on public.expense_reset_requests (network_id)
  where status = 'pending';

create index if not exists expense_reset_approvals_request_idx
  on public.expense_reset_approvals (reset_request_id, member_id);

create unique index if not exists expenses_network_client_generated_id_idx
  on public.expenses (network_id, client_generated_id)
  where client_generated_id is not null;

create index if not exists network_notifications_recipient_read_created_idx
  on public.network_notifications (recipient_member_id, is_read, created_at desc);

create index if not exists network_notifications_network_recipient_idx
  on public.network_notifications (network_id, recipient_member_id);

alter table public.networks enable row level security;
alter table public.network_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_cycles enable row level security;
alter table public.expense_reset_requests enable row level security;
alter table public.expense_reset_approvals enable row level security;
alter table public.network_notifications enable row level security;

do $$
begin
  alter publication supabase_realtime add table public.network_members;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.expenses;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.network_notifications;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.expense_reset_requests;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.expense_reset_approvals;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.expense_cycles;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

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

create or replace function public.phase5_network_exists(
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
    from public.networks
    where id = target_network_id
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
  select (
      paid_member_id is null
      or public.phase5_member_belongs_to_network(paid_member_id, target_network_id)
    )
    and (
      added_member_id is null
      or public.phase5_member_belongs_to_network(added_member_id, target_network_id)
    );
$$;

create or replace function public.phase5_network_has_no_active_expenses(
  target_network_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select sum(amount_cents)
      from public.expenses
      where network_id = target_network_id
        and archived_at is null
    ),
    0
  ) <= 0;
$$;

create or replace function public.phase5_network_can_be_deleted_after_leave(
  target_network_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.phase5_network_has_no_active_expenses(target_network_id)
    and (
      select count(*)
      from public.network_members
      where network_id = target_network_id
    ) <= 1;
$$;

create or replace function public.phase5_notification_matches_network(
  target_network_id uuid,
  recipient_member_id uuid,
  actor_member_id uuid,
  target_expense_id uuid,
  target_reset_request_id uuid
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
    )
    and (
      target_reset_request_id is null
      or exists (
        select 1
        from public.expense_reset_requests
        where id = target_reset_request_id
          and network_id = target_network_id
      )
    );
$$;

create or replace function public.phase5_cycle_member_belongs_to_network(
  target_network_id uuid,
  requester_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select requester_member_id is null
    or public.phase5_member_belongs_to_network(
      requester_member_id,
      target_network_id
    );
$$;

create or replace function public.phase5_reset_request_matches_network(
  target_network_id uuid,
  target_cycle_id uuid,
  requester_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.expense_cycles
    where id = target_cycle_id
      and network_id = target_network_id
  )
  and (
    requester_member_id is null
    or public.phase5_member_belongs_to_network(
      requester_member_id,
      target_network_id
    )
  );
$$;

create or replace function public.phase5_reset_approval_matches_network(
  target_network_id uuid,
  target_reset_request_id uuid,
  approving_member_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.phase5_member_belongs_to_network(
    approving_member_id,
    target_network_id
  )
  and exists (
    select 1
    from public.expense_reset_requests
    where id = target_reset_request_id
      and network_id = target_network_id
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
    or new.kind <> old.kind
    or coalesce(new.reset_request_id, '00000000-0000-0000-0000-000000000000'::uuid)
      <> coalesce(old.reset_request_id, '00000000-0000-0000-0000-000000000000'::uuid)
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
drop policy if exists phase5_interim_read_cycles on public.expense_cycles;
drop policy if exists phase5_interim_insert_cycles on public.expense_cycles;
drop policy if exists phase5_interim_update_cycles on public.expense_cycles;
drop policy if exists phase5_interim_delete_cycles on public.expense_cycles;
drop policy if exists phase5_interim_read_reset_requests on public.expense_reset_requests;
drop policy if exists phase5_interim_insert_reset_requests on public.expense_reset_requests;
drop policy if exists phase5_interim_update_reset_requests on public.expense_reset_requests;
drop policy if exists phase5_interim_delete_reset_requests on public.expense_reset_requests;
drop policy if exists phase5_interim_read_reset_approvals on public.expense_reset_approvals;
drop policy if exists phase5_interim_insert_reset_approvals on public.expense_reset_approvals;
drop policy if exists phase5_interim_delete_reset_approvals on public.expense_reset_approvals;

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

drop policy if exists phase5_interim_delete_empty_networks on public.networks;
create policy phase5_interim_delete_empty_networks
  on public.networks
  for delete
  using (
    public.phase5_network_can_be_deleted_after_leave(id)
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
    public.phase5_network_exists(network_id)
    and length(trim(name)) > 0
    and length(trim(normalized_name)) > 0
    and password_hash is not null
    and password_salt is not null
  );

drop policy if exists phase5_interim_update_member_profile
  on public.network_members;
create policy phase5_interim_update_member_profile
  on public.network_members
  for update
  using (
    public.phase5_network_exists(network_id)
    and id::text = coalesce(
      auth.jwt() -> 'user_metadata' ->> 'maskan_member_id',
      ''
    )
  )
  with check (
    public.phase5_network_exists(network_id)
    and length(trim(name)) > 0
    and length(trim(normalized_name)) > 0
    and id::text = coalesce(
      auth.jwt() -> 'user_metadata' ->> 'maskan_member_id',
      ''
    )
  );

drop policy if exists phase5_interim_leave_network
  on public.network_members;
create policy phase5_interim_leave_network
  on public.network_members
  for delete
  using (
    exists (
      select 1
      from public.networks
      where id = network_id
    )
    and public.phase5_network_has_no_active_expenses(network_id)
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

drop policy if exists phase5_interim_update_network_expenses on public.expenses;
create policy phase5_interim_update_network_expenses
  on public.expenses
  for update
  using (
    public.phase5_expense_members_match_network(
      network_id,
      paid_by_member_id,
      added_by_member_id
    )
  )
  with check (
    amount_cents > 0
    and archived_at is not null
    and public.phase5_expense_members_match_network(
      network_id,
      paid_by_member_id,
      added_by_member_id
    )
  );

drop policy if exists phase5_member_edit_own_active_expenses
  on public.expenses;
create policy phase5_member_edit_own_active_expenses
  on public.expenses
  for update
  using (
    archived_at is null
    and added_by_member_id::text = coalesce(
      auth.jwt() -> 'user_metadata' ->> 'maskan_member_id',
      ''
    )
    and public.phase5_expense_members_match_network(
      network_id,
      paid_by_member_id,
      added_by_member_id
    )
  )
  with check (
    amount_cents > 0
    and (note is null or char_length(note) <= 200)
    and archived_at is null
    and added_by_member_id::text = coalesce(
      auth.jwt() -> 'user_metadata' ->> 'maskan_member_id',
      ''
    )
    and public.phase5_expense_members_match_network(
      network_id,
      paid_by_member_id,
      added_by_member_id
    )
  );

drop policy if exists phase5_interim_delete_settled_network_expenses
  on public.expenses;
create policy phase5_interim_delete_settled_network_expenses
  on public.expenses
  for delete
  using (
    public.phase5_network_has_no_active_expenses(network_id)
  );

create policy phase5_interim_read_cycles
  on public.expense_cycles
  for select
  using (network_id is not null);

create policy phase5_interim_insert_cycles
  on public.expense_cycles
  for insert
  with check (
    status in ('active', 'pending_reset', 'closed')
    and public.phase5_cycle_member_belongs_to_network(
      network_id,
      requested_by_member_id
    )
  );

create policy phase5_interim_update_cycles
  on public.expense_cycles
  for update
  using (network_id is not null)
  with check (
    status in ('active', 'pending_reset', 'closed')
    and public.phase5_cycle_member_belongs_to_network(
      network_id,
      requested_by_member_id
    )
  );

create policy phase5_interim_delete_cycles
  on public.expense_cycles
  for delete
  using (
    public.phase5_network_has_no_active_expenses(network_id)
  );

create policy phase5_interim_read_reset_requests
  on public.expense_reset_requests
  for select
  using (
    public.phase5_reset_request_matches_network(
      network_id,
      cycle_id,
      requested_by_member_id
    )
  );

create policy phase5_interim_insert_reset_requests
  on public.expense_reset_requests
  for insert
  with check (
    status = 'pending'
    and public.phase5_reset_request_matches_network(
      network_id,
      cycle_id,
      requested_by_member_id
    )
  );

create policy phase5_interim_update_reset_requests
  on public.expense_reset_requests
  for update
  using (
    public.phase5_reset_request_matches_network(
      network_id,
      cycle_id,
      requested_by_member_id
    )
  )
  with check (
    status in ('pending', 'completed', 'cancelled')
    and public.phase5_reset_request_matches_network(
      network_id,
      cycle_id,
      requested_by_member_id
    )
  );

create policy phase5_interim_delete_reset_requests
  on public.expense_reset_requests
  for delete
  using (
    public.phase5_network_has_no_active_expenses(network_id)
  );

create policy phase5_interim_read_reset_approvals
  on public.expense_reset_approvals
  for select
  using (
    public.phase5_reset_approval_matches_network(
      network_id,
      reset_request_id,
      member_id
    )
  );

create policy phase5_interim_insert_reset_approvals
  on public.expense_reset_approvals
  for insert
  with check (
    public.phase5_reset_approval_matches_network(
      network_id,
      reset_request_id,
      member_id
    )
  );

create policy phase5_interim_delete_reset_approvals
  on public.expense_reset_approvals
  for delete
  using (
    public.phase5_network_has_no_active_expenses(network_id)
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
      expense_id,
      reset_request_id
    )
  );

drop policy if exists phase5_interim_insert_addressed_notifications on public.network_notifications;
create policy phase5_interim_insert_addressed_notifications
  on public.network_notifications
  for insert
  with check (
    amount_cents >= 0
    and (note_snippet is null or char_length(note_snippet) <= 80)
    and public.phase5_notification_matches_network(
      network_id,
      recipient_member_id,
      actor_member_id,
      expense_id,
      reset_request_id
    )
  );

-- The trigger above prevents changing notification identity/content. Without
-- Supabase Auth, RLS still cannot prove which human controls recipient_member_id.
drop policy if exists phase5_interim_mark_addressed_notifications_read
  on public.network_notifications;
drop policy if exists phase5_interim_delete_addressed_notifications
  on public.network_notifications;
create policy phase5_interim_delete_addressed_notifications
  on public.network_notifications
  for delete
  using (
    public.phase5_notification_matches_network(
      network_id,
      recipient_member_id,
      actor_member_id,
      expense_id,
      reset_request_id
    )
  );

comment on table public.networks is
  'Shared housing expense networks. Phase 5 policies are interim until Supabase Auth links members to auth.users.';
comment on table public.network_members is
  'Members inside a network with app-level password hash metadata.';
comment on table public.expenses is
  'Network expenses stored in cents with payer and record ownership fields.';
comment on table public.expense_cycles is
  'Expense cycles keep old settled records archived instead of deleted.';
comment on table public.expense_reset_requests is
  'Unanimous approval requests for closing a cycle and starting a new one.';
comment on table public.expense_reset_approvals is
  'Member approvals captured against the request membership snapshot.';
comment on table public.network_notifications is
  'Notification records for cloud-backed network activity.';

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'member-avatars',
  'member-avatars',
  true,
  1048576,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists maskan_member_avatar_public_read
  on storage.objects;
create policy maskan_member_avatar_public_read
  on storage.objects
  for select
  using (bucket_id = 'member-avatars');

drop policy if exists maskan_member_avatar_upload
  on storage.objects;
create policy maskan_member_avatar_upload
  on storage.objects
  for insert
  with check (
    bucket_id = 'member-avatars'
    and (storage.foldername(name))[2] = coalesce(
      auth.jwt() -> 'user_metadata' ->> 'maskan_member_id',
      ''
    )
  );

drop policy if exists maskan_member_avatar_update
  on storage.objects;
create policy maskan_member_avatar_update
  on storage.objects
  for update
  using (
    bucket_id = 'member-avatars'
    and (storage.foldername(name))[2] = coalesce(
      auth.jwt() -> 'user_metadata' ->> 'maskan_member_id',
      ''
    )
  )
  with check (
    bucket_id = 'member-avatars'
    and (storage.foldername(name))[2] = coalesce(
      auth.jwt() -> 'user_metadata' ->> 'maskan_member_id',
      ''
    )
  );
