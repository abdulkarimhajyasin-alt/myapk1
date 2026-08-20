begin;

-- Phase 1: Supabase Auth membership isolation and production RLS.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

alter table public.network_members
  add column if not exists auth_user_id uuid references auth.users(id) on delete set null;

create unique index if not exists network_members_auth_user_id_uidx
  on public.network_members (auth_user_id)
  where auth_user_id is not null;

create index if not exists network_members_auth_user_network_idx
  on public.network_members (auth_user_id, network_id)
  where auth_user_id is not null;

-- Backfill only when immutable member UUID metadata and the deterministic
-- legacy Auth email both prove the mapping. Names are never used.
with safe_candidates as (
  select users.id as auth_user_id, members.id as member_id
  from auth.users as users
  join public.network_members as members
    on (users.raw_user_meta_data ->> 'maskan_member_id') ~*
       '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
   and members.id = (users.raw_user_meta_data ->> 'maskan_member_id')::uuid
  where lower(coalesce(users.email, '')) =
        lower('maskan-' || members.id::text || '@auth.maskan.app')
), unambiguous_candidates as (
  select auth_user_id, member_id
  from safe_candidates
  where (select count(*) from safe_candidates c where c.member_id = safe_candidates.member_id) = 1
    and (select count(*) from safe_candidates c where c.auth_user_id = safe_candidates.auth_user_id) = 1
)
update public.network_members as members
set auth_user_id = candidates.auth_user_id
from unambiguous_candidates as candidates
where members.id = candidates.member_id
  and members.auth_user_id is null;

create table if not exists private.network_credentials (
  network_id uuid primary key references public.networks(id) on delete cascade,
  password_hash text not null check (length(password_hash) > 0),
  password_salt text not null check (length(password_salt) > 0),
  migrated_at timestamptz not null default now()
);

create table if not exists private.member_credentials (
  member_id uuid primary key references public.network_members(id) on delete cascade,
  password_hash text not null check (length(password_hash) > 0),
  password_salt text not null check (length(password_salt) > 0),
  migrated_at timestamptz not null default now()
);

insert into private.network_credentials (network_id, password_hash, password_salt)
select id, network_password_hash, network_password_salt
from public.networks
where network_password_hash is not null and network_password_salt is not null
on conflict (network_id) do nothing;

insert into private.member_credentials (member_id, password_hash, password_salt)
select id, password_hash, password_salt
from public.network_members
where password_hash is not null and password_salt is not null
on conflict (member_id) do nothing;

-- Values remain preserved in private.*; clearing public copies prevents
-- PostgREST and Realtime payloads from disclosing verification material.
update public.networks
set network_password_hash = null, network_password_salt = null
where network_password_hash is not null or network_password_salt is not null;

update public.network_members
set password_hash = null, password_salt = null
where password_hash is not null or password_salt is not null;

create or replace function private.maskan_legacy_password_hash(
  password_salt text,
  raw_password text
)
returns text
language plpgsql
immutable
strict
security invoker
set search_path = ''
as $$
declare
  input_value text := password_salt || ':' || btrim(raw_password);
  hash_value numeric := 5472609002491880229;
  code_point integer;
  code_unit integer;
  position integer;
begin
  for position in 1..char_length(input_value) loop
    code_point := ascii(substr(input_value, position, 1));
    if code_point <= 65535 then
      code_unit := code_point;
      hash_value := mod(((hash_value::bigint # code_unit)::numeric * 1099511628211), 9223372036854775808);
    else
      code_point := code_point - 65536;
      code_unit := 55296 + (code_point >> 10);
      hash_value := mod(((hash_value::bigint # code_unit)::numeric * 1099511628211), 9223372036854775808);
      code_unit := 56320 + (code_point & 1023);
      hash_value := mod(((hash_value::bigint # code_unit)::numeric * 1099511628211), 9223372036854775808);
    end if;
  end loop;
  return lpad(to_hex(hash_value::bigint), 16, '0');
end;
$$;

-- Deliberately narrow exact-name lookup: it cannot enumerate networks or secrets.
create or replace function public.maskan_discover_network(p_network_name text)
returns table (
  id uuid,
  name text,
  currency_code text,
  currency_symbol text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select n.id, n.name, n.currency_code, n.currency_symbol, n.created_at, n.updated_at
  from public.networks n
  where n.normalized_name = lower(regexp_replace(btrim(p_network_name), '\s+', ' ', 'g'))
  limit 1
$$;

create or replace function public.maskan_verify_member_credentials(
  p_network_id uuid,
  p_member_id uuid,
  p_member_name text,
  p_member_password text
)
returns table (network_id uuid, member_id uuid, network_name text, member_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_member public.network_members%rowtype;
  credential private.member_credentials%rowtype;
begin
  if p_member_id is not null then
    select * into resolved_member
    from public.network_members m
    where m.id = p_member_id and m.network_id = p_network_id;
  else
    select * into resolved_member
    from public.network_members m
    where m.network_id = p_network_id
      and m.normalized_name = lower(regexp_replace(btrim(p_member_name), '\s+', ' ', 'g'));
  end if;
  if not found then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
  end if;

  select * into strict credential
  from private.member_credentials c where c.member_id = resolved_member.id;
  if private.maskan_legacy_password_hash(credential.password_salt, p_member_password)
     <> credential.password_hash then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
  end if;

  return query
  select n.id, resolved_member.id, n.name, resolved_member.name
  from public.networks n where n.id = resolved_member.network_id;
exception
  when no_data_found then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
end;
$$;

create or replace function public.maskan_claim_legacy_member(
  p_member_id uuid,
  p_member_password text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  credential private.member_credentials%rowtype;
begin
  if caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.network_members
    where auth_user_id = caller_id and id <> p_member_id
  ) then
    raise exception 'Auth user already owns another Maskan member' using errcode = '23505';
  end if;
  select * into strict credential from private.member_credentials
  where member_id = p_member_id;
  if private.maskan_legacy_password_hash(credential.password_salt, p_member_password)
     <> credential.password_hash then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
  end if;
  update public.network_members
  set auth_user_id = caller_id
  where id = p_member_id and (auth_user_id is null or auth_user_id = caller_id);
  if not found then
    raise exception 'Member is already linked to another auth user' using errcode = '42501';
  end if;
exception
  when no_data_found then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
end;
$$;

-- Preserve the RPC name/arguments while narrowing the returned projection.
drop function if exists public.phase5_reset_member_password(uuid, uuid, uuid, text, text);
create or replace function public.phase5_reset_member_password(
  target_network_id uuid,
  admin_member_id uuid,
  target_member_id uuid,
  new_password_hash text,
  new_password_salt text
)
returns table (
  id uuid, network_id uuid, name text, normalized_name text,
  password_hash text, password_salt text, avatar_color text,
  avatar_initials text, avatar_image_path text, avatar_image_url text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_member_id uuid := (
    select m.id from public.network_members m
    where m.auth_user_id = auth.uid() limit 1
  );
begin
  if caller_member_id is null or caller_member_id <> admin_member_id then
    raise exception 'Admin member auth mismatch' using errcode = '42501';
  end if;
  if admin_member_id = target_member_id then
    raise exception 'Admin cannot reset own password through this flow' using errcode = '42501';
  end if;
  if coalesce(btrim(new_password_hash), '') = '' or coalesce(btrim(new_password_salt), '') = '' then
    raise exception 'Password hash and salt are required' using errcode = '23514';
  end if;
  if not exists (
    select 1 from public.networks n
    where n.id = target_network_id and n.created_by_member_id = caller_member_id
  ) then
    raise exception 'Only the network owner can reset member passwords' using errcode = '42501';
  end if;
  update private.member_credentials
  set password_hash = new_password_hash, password_salt = new_password_salt,
      migrated_at = now()
  where member_id = target_member_id
    and exists (
      select 1 from public.network_members m
      where m.id = target_member_id and m.network_id = target_network_id
    );
  if not found then
    raise exception 'Target member not found in this network' using errcode = 'P0002';
  end if;
  return query
  select m.id, m.network_id, m.name, m.normalized_name,
         null::text, null::text, m.avatar_color, m.avatar_initials,
         m.avatar_image_path, m.avatar_image_url, m.created_at
  from public.network_members m where m.id = target_member_id;
end;
$$;

create or replace function public.maskan_current_member_id()
returns uuid language sql stable security definer set search_path = ''
as $$
  select members.id from public.network_members as members
  where members.auth_user_id = auth.uid() limit 1;
$$;

create or replace function public.maskan_current_network_id()
returns uuid language sql stable security definer set search_path = ''
as $$
  select members.network_id from public.network_members as members
  where members.auth_user_id = auth.uid() limit 1;
$$;

create or replace function public.maskan_is_network_member(target_network_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.network_members as members
    where members.auth_user_id = auth.uid()
      and members.network_id = target_network_id
  );
$$;

create or replace function public.maskan_is_current_member(target_member_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.network_members as members
    where members.auth_user_id = auth.uid() and members.id = target_member_id
  );
$$;

create or replace function public.maskan_can_create_active_cycle(
  target_network_id uuid,
  target_cycle_number integer
)
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.maskan_is_network_member(target_network_id)
    and not exists (
      select 1 from public.expense_cycles c
      where c.network_id = target_network_id and c.status = 'active'
    )
    and target_cycle_number = (
      select coalesce(max(c.cycle_number), 0) + 1
      from public.expense_cycles c where c.network_id = target_network_id
    );
$$;

revoke all on function public.maskan_current_member_id() from public, anon;
revoke all on function public.maskan_current_network_id() from public, anon;
revoke all on function public.maskan_is_network_member(uuid) from public, anon;
revoke all on function public.maskan_is_current_member(uuid) from public, anon;
revoke all on function public.maskan_can_create_active_cycle(uuid, integer) from public, anon;
grant execute on function public.maskan_current_member_id() to authenticated;
grant execute on function public.maskan_current_network_id() to authenticated;
grant execute on function public.maskan_is_network_member(uuid) to authenticated;
grant execute on function public.maskan_is_current_member(uuid) to authenticated;
grant execute on function public.maskan_can_create_active_cycle(uuid, integer) to authenticated;

create or replace function public.maskan_create_network(
  p_network_id uuid,
  p_member_id uuid,
  p_network_name text,
  p_member_name text,
  p_network_password_hash text,
  p_network_password_salt text,
  p_member_password_hash text,
  p_member_password_salt text,
  p_currency_code text,
  p_currency_symbol text
)
returns table (network_id uuid, member_id uuid, network_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  normalized_network_name text;
  normalized_member_name text;
begin
  if caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if exists (select 1 from public.network_members where auth_user_id = caller_id) then
    raise exception 'Auth user already owns a Maskan member' using errcode = '23505';
  end if;

  normalized_network_name := lower(regexp_replace(btrim(p_network_name), '\s+', ' ', 'g'));
  normalized_member_name := lower(regexp_replace(btrim(p_member_name), '\s+', ' ', 'g'));
  if normalized_network_name = '' or normalized_member_name = ''
     or coalesce(p_network_password_hash, '') = ''
     or coalesce(p_network_password_salt, '') = ''
     or coalesce(p_member_password_hash, '') = ''
     or coalesce(p_member_password_salt, '') = '' then
    raise exception 'Required account fields are missing' using errcode = '23514';
  end if;

  insert into public.networks (
    id, name, normalized_name, currency_code, currency_symbol,
    created_at, updated_at
  ) values (
    p_network_id, btrim(p_network_name), normalized_network_name,
    upper(btrim(p_currency_code)), p_currency_symbol, now(), now()
  );
  insert into private.network_credentials (network_id, password_hash, password_salt)
  values (p_network_id, p_network_password_hash, p_network_password_salt);

  insert into public.network_members (
    id, network_id, auth_user_id, name, normalized_name, created_at
  ) values (
    p_member_id, p_network_id, caller_id, btrim(p_member_name),
    normalized_member_name, now()
  );
  insert into private.member_credentials (member_id, password_hash, password_salt)
  values (p_member_id, p_member_password_hash, p_member_password_salt);

  update public.networks set created_by_member_id = p_member_id
  where id = p_network_id;
  insert into public.expense_cycles (network_id, cycle_number, status, started_at)
  values (p_network_id, 1, 'active', now());

  return query select p_network_id, p_member_id, btrim(p_network_name);
end;
$$;

create or replace function public.maskan_join_network(
  p_network_id uuid,
  p_network_name text,
  p_network_password text,
  p_member_id uuid,
  p_member_name text,
  p_member_password_hash text,
  p_member_password_salt text
)
returns table (network_id uuid, member_id uuid, network_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  resolved_network public.networks%rowtype;
  credential private.network_credentials%rowtype;
  normalized_member_name text;
begin
  if caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if exists (select 1 from public.network_members where auth_user_id = caller_id) then
    raise exception 'Auth user already owns a Maskan member' using errcode = '23505';
  end if;

  if p_network_id is not null then
    select * into resolved_network from public.networks where id = p_network_id;
  else
    select * into resolved_network from public.networks
    where normalized_name = lower(regexp_replace(btrim(p_network_name), '\s+', ' ', 'g'));
  end if;
  if not found then
    raise exception 'Invalid network credentials' using errcode = 'P0001';
  end if;

  select * into strict credential from private.network_credentials
  where network_id = resolved_network.id;
  if private.maskan_legacy_password_hash(credential.password_salt, p_network_password)
     <> credential.password_hash then
    raise exception 'Invalid network credentials' using errcode = 'P0001';
  end if;

  normalized_member_name := lower(regexp_replace(btrim(p_member_name), '\s+', ' ', 'g'));
  if normalized_member_name = ''
     or coalesce(p_member_password_hash, '') = ''
     or coalesce(p_member_password_salt, '') = '' then
    raise exception 'Required member fields are missing' using errcode = '23514';
  end if;

  insert into public.network_members (
    id, network_id, auth_user_id, name, normalized_name, created_at
  ) values (
    p_member_id, resolved_network.id, caller_id, btrim(p_member_name),
    normalized_member_name, now()
  );
  insert into private.member_credentials (member_id, password_hash, password_salt)
  values (p_member_id, p_member_password_hash, p_member_password_salt);

  return query select resolved_network.id, p_member_id, resolved_network.name;
exception
  when no_data_found then
    raise exception 'Invalid network credentials' using errcode = 'P0001';
end;
$$;

create or replace function public.maskan_leave_network(p_network_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_member_id uuid;
  member_count integer;
begin
  select m.id into caller_member_id
  from public.network_members m
  where m.auth_user_id = auth.uid() and m.network_id = p_network_id;
  if caller_member_id is null then
    raise exception 'Membership required' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.expenses e
    where e.network_id = p_network_id and e.archived_at is null
  ) then
    raise exception 'Network expenses must be settled before leaving' using errcode = '23514';
  end if;
  select count(*) into member_count from public.network_members where network_id = p_network_id;
  if member_count = 1 then
    delete from public.networks where id = p_network_id;
    return;
  end if;
  delete from public.network_notifications
  where network_id = p_network_id
    and (recipient_member_id = caller_member_id or actor_member_id = caller_member_id);
  delete from public.expense_reset_requests
  where network_id = p_network_id
    and (status = 'pending' or requested_by_member_id = caller_member_id);
  delete from public.expense_reset_approvals
  where network_id = p_network_id and member_id = caller_member_id;
  delete from public.network_members where id = caller_member_id;
end;
$$;

create or replace function public.maskan_complete_expense_cycle(
  p_network_id uuid,
  p_cycle_id uuid,
  p_reset_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_member_id uuid;
  completion_time timestamptz := now();
begin
  select m.id into caller_member_id from public.network_members m
  where m.auth_user_id = auth.uid() and m.network_id = p_network_id;
  if caller_member_id is null then
    raise exception 'Membership required' using errcode = '42501';
  end if;

  if p_reset_request_id is null then
    if not exists (
      select 1 from public.networks n
      where n.id = p_network_id and n.created_by_member_id = caller_member_id
    ) then
      raise exception 'Only the network owner can start a cycle directly' using errcode = '42501';
    end if;
  else
    if not exists (
      select 1 from public.expense_reset_requests r
      where r.id = p_reset_request_id and r.network_id = p_network_id
        and r.cycle_id = p_cycle_id and r.status = 'pending'
        and not exists (
          select 1 from unnest(r.required_member_ids) as required(required_member_id)
          where not exists (
            select 1 from public.expense_reset_approvals a
            where a.reset_request_id = r.id and a.member_id = required_member_id
          )
        )
    ) then
      return false;
    end if;
  end if;

  update public.expenses
  set cycle_id = p_cycle_id, archived_at = completion_time
  where network_id = p_network_id and archived_at is null
    and (cycle_id = p_cycle_id or cycle_id is null);
  update public.expense_cycles
  set status = 'closed', closed_at = completion_time
  where id = p_cycle_id and network_id = p_network_id;
  if not found then
    raise exception 'Active cycle not found' using errcode = 'P0002';
  end if;
  insert into public.expense_cycles (network_id, cycle_number, status, started_at)
  select p_network_id, coalesce(max(cycle_number), 0) + 1, 'active', completion_time
  from public.expense_cycles where network_id = p_network_id;
  if p_reset_request_id is not null then
    update public.expense_reset_requests
    set status = 'completed', completed_at = completion_time
    where id = p_reset_request_id;
  end if;
  return true;
end;
$$;

create or replace view public.maskan_networks
with (security_invoker = true)
as
select id, name, normalized_name, null::text as network_password_hash,
       null::text as network_password_salt, currency_code, currency_symbol,
       created_by_member_id, created_at, updated_at
from public.networks;

create or replace view public.maskan_network_members
with (security_invoker = true)
as
select id, network_id, name, normalized_name, null::text as password_hash,
       null::text as password_salt, avatar_color, avatar_initials,
       avatar_image_path, avatar_image_url, created_at
from public.network_members;

alter table public.networks enable row level security;
alter table public.network_members enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_cycles enable row level security;
alter table public.expense_reset_requests enable row level security;
alter table public.expense_reset_approvals enable row level security;
alter table public.network_notifications enable row level security;

-- Remove every development/interim policy so no permissive policy survives.
do $$
declare policy_row record;
begin
  for policy_row in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public' and tablename in (
      'networks', 'network_members', 'expenses', 'expense_cycles',
      'expense_reset_requests', 'expense_reset_approvals', 'network_notifications'
    )
  loop
    execute format('drop policy %I on %I.%I', policy_row.policyname,
                   policy_row.schemaname, policy_row.tablename);
  end loop;
end $$;

create policy maskan_networks_select on public.networks for select to authenticated
using (public.maskan_is_network_member(id));
create policy maskan_networks_update on public.networks for update to authenticated
using (created_by_member_id = public.maskan_current_member_id())
with check (created_by_member_id = public.maskan_current_member_id());

create policy maskan_members_select on public.network_members for select to authenticated
using (public.maskan_is_network_member(network_id));
create policy maskan_members_update_self on public.network_members for update to authenticated
using (id = public.maskan_current_member_id())
with check (id = public.maskan_current_member_id() and auth_user_id = auth.uid());

create policy maskan_expenses_select on public.expenses for select to authenticated
using (public.maskan_is_network_member(network_id));
create policy maskan_expenses_insert on public.expenses for insert to authenticated
with check (
  public.maskan_is_network_member(network_id)
  and added_by_member_id = public.maskan_current_member_id()
  and exists (
    select 1 from public.network_members payer
    where payer.id = paid_by_member_id and payer.network_id = expenses.network_id
  )
  and (
    cycle_id is null or exists (
      select 1 from public.expense_cycles target_cycle
      where target_cycle.id = cycle_id and target_cycle.network_id = expenses.network_id
    )
  )
);
create policy maskan_expenses_update on public.expenses for update to authenticated
using (added_by_member_id = public.maskan_current_member_id())
with check (
  added_by_member_id = public.maskan_current_member_id()
  and (
    paid_by_member_id is null or exists (
      select 1 from public.network_members payer
      where payer.id = paid_by_member_id and payer.network_id = expenses.network_id
    )
  )
  and (
    cycle_id is null or exists (
      select 1 from public.expense_cycles target_cycle
      where target_cycle.id = cycle_id and target_cycle.network_id = expenses.network_id
    )
  )
);
create policy maskan_expenses_delete on public.expenses for delete to authenticated
using (added_by_member_id = public.maskan_current_member_id());

create policy maskan_cycles_select on public.expense_cycles for select to authenticated
using (public.maskan_is_network_member(network_id));
create policy maskan_cycles_insert on public.expense_cycles for insert to authenticated
with check (
  public.maskan_can_create_active_cycle(network_id, cycle_number)
  and status = 'active'
  and closed_at is null
  and (requested_by_member_id is null or requested_by_member_id = public.maskan_current_member_id())
);
create policy maskan_cycles_update on public.expense_cycles for update to authenticated
using (public.maskan_is_network_member(network_id))
with check (public.maskan_is_network_member(network_id));
create policy maskan_cycles_delete on public.expense_cycles for delete to authenticated
using (public.maskan_is_network_member(network_id));

create policy maskan_reset_requests_select on public.expense_reset_requests for select to authenticated
using (public.maskan_is_network_member(network_id));
create policy maskan_reset_requests_insert on public.expense_reset_requests for insert to authenticated
with check (
  public.maskan_is_network_member(network_id)
  and requested_by_member_id = public.maskan_current_member_id()
  and exists (
    select 1 from public.expense_cycles target_cycle
    where target_cycle.id = cycle_id
      and target_cycle.network_id = expense_reset_requests.network_id
  )
);
create policy maskan_reset_requests_update on public.expense_reset_requests for update to authenticated
using (public.maskan_is_network_member(network_id))
with check (public.maskan_is_network_member(network_id));
create policy maskan_reset_requests_delete on public.expense_reset_requests for delete to authenticated
using (requested_by_member_id = public.maskan_current_member_id());

create policy maskan_reset_approvals_select on public.expense_reset_approvals for select to authenticated
using (public.maskan_is_network_member(network_id));
create policy maskan_reset_approvals_insert on public.expense_reset_approvals for insert to authenticated
with check (
  public.maskan_is_network_member(network_id)
  and member_id = public.maskan_current_member_id()
  and exists (
    select 1 from public.expense_reset_requests request
    where request.id = reset_request_id
      and request.network_id = expense_reset_approvals.network_id
  )
);
create policy maskan_reset_approvals_delete on public.expense_reset_approvals for delete to authenticated
using (member_id = public.maskan_current_member_id());

create policy maskan_notifications_select on public.network_notifications for select to authenticated
using (recipient_member_id = public.maskan_current_member_id());
create policy maskan_notifications_insert on public.network_notifications for insert to authenticated
with check (
  public.maskan_is_network_member(network_id)
  and (
    actor_member_id = public.maskan_current_member_id()
    or (actor_member_id is null and kind = 'cycle_started')
  )
  and exists (
    select 1 from public.network_members recipient
    where recipient.id = recipient_member_id
      and recipient.network_id = network_notifications.network_id
  )
  and (
    expense_id is null or exists (
      select 1 from public.expenses expense
      where expense.id = expense_id
        and expense.network_id = network_notifications.network_id
    )
  )
  and (
    reset_request_id is null or exists (
      select 1 from public.expense_reset_requests request
      where request.id = reset_request_id
        and request.network_id = network_notifications.network_id
    )
  )
);
create policy maskan_notifications_update on public.network_notifications for update to authenticated
using (recipient_member_id = public.maskan_current_member_id())
with check (recipient_member_id = public.maskan_current_member_id());
create policy maskan_notifications_delete on public.network_notifications for delete to authenticated
using (
  recipient_member_id = public.maskan_current_member_id()
  or actor_member_id = public.maskan_current_member_id()
);

-- Remove anonymous/direct access first, then grant only the columns and RPCs required.
revoke all on public.networks, public.network_members, public.expenses,
  public.expense_cycles, public.expense_reset_requests,
  public.expense_reset_approvals, public.network_notifications from anon, authenticated;
revoke all on public.maskan_networks, public.maskan_network_members from anon, authenticated;
grant select on public.maskan_networks, public.maskan_network_members to authenticated;
grant select (id, name, normalized_name, currency_code, currency_symbol,
              created_by_member_id, created_at, updated_at) on public.networks to authenticated;
grant update (name, normalized_name, currency_code, currency_symbol, updated_at)
  on public.networks to authenticated;
grant select (id, network_id, name, normalized_name, avatar_color, avatar_initials,
              avatar_image_path, avatar_image_url, created_at)
  on public.network_members to authenticated;
grant update (avatar_color, avatar_initials, avatar_image_path, avatar_image_url)
  on public.network_members to authenticated;
grant select, insert, delete on public.expenses to authenticated;
grant update (cycle_id, paid_by_member_id, paid_by_member_name, amount_cents,
              note, archived_at) on public.expenses to authenticated;
grant select, insert on public.expense_cycles to authenticated;
grant select, insert, delete on public.expense_reset_requests to authenticated;
grant select, insert, delete on public.expense_reset_approvals to authenticated;
grant select, insert, delete on public.network_notifications to authenticated;
grant update (is_read) on public.network_notifications to authenticated;

revoke all on function private.maskan_legacy_password_hash(text, text) from public, anon, authenticated;
revoke all on function public.maskan_discover_network(text) from public;
revoke all on function public.maskan_verify_member_credentials(uuid, uuid, text, text) from public;
revoke all on function public.maskan_create_network(uuid, uuid, text, text, text, text, text, text, text, text) from public;
revoke all on function public.maskan_join_network(uuid, text, text, uuid, text, text, text) from public;
revoke all on function public.maskan_claim_legacy_member(uuid, text) from public;
revoke all on function public.maskan_leave_network(uuid) from public;
revoke all on function public.maskan_complete_expense_cycle(uuid, uuid, uuid) from public;
revoke all on function public.phase5_reset_member_password(uuid, uuid, uuid, text, text) from public;
grant execute on function public.maskan_discover_network(text) to anon, authenticated;
grant execute on function public.maskan_verify_member_credentials(uuid, uuid, text, text) to anon, authenticated;
grant execute on function public.maskan_create_network(uuid, uuid, text, text, text, text, text, text, text, text) to authenticated;
grant execute on function public.maskan_join_network(uuid, text, text, uuid, text, text, text) to authenticated;
grant execute on function public.maskan_claim_legacy_member(uuid, text) to authenticated;
grant execute on function public.maskan_leave_network(uuid) to authenticated;
grant execute on function public.maskan_complete_expense_cycle(uuid, uuid, uuid) to authenticated;
grant execute on function public.phase5_reset_member_password(uuid, uuid, uuid, text, text) to authenticated;

-- Avatar object ownership is derived from the durable member mapping, not mutable JWT metadata.
drop policy if exists maskan_member_avatar_insert on storage.objects;
drop policy if exists maskan_member_avatar_upload on storage.objects;
drop policy if exists maskan_member_avatar_update on storage.objects;
drop policy if exists maskan_member_avatar_delete on storage.objects;
create policy maskan_member_avatar_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'member-avatars'
  and (storage.foldername(name))[1] = public.maskan_current_network_id()::text
  and (storage.foldername(name))[2] = public.maskan_current_member_id()::text
);
create policy maskan_member_avatar_update on storage.objects for update to authenticated
using (
  bucket_id = 'member-avatars'
  and (storage.foldername(name))[1] = public.maskan_current_network_id()::text
  and (storage.foldername(name))[2] = public.maskan_current_member_id()::text
)
with check (
  bucket_id = 'member-avatars'
  and (storage.foldername(name))[1] = public.maskan_current_network_id()::text
  and (storage.foldername(name))[2] = public.maskan_current_member_id()::text
);
create policy maskan_member_avatar_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'member-avatars'
  and (storage.foldername(name))[1] = public.maskan_current_network_id()::text
  and (storage.foldername(name))[2] = public.maskan_current_member_id()::text
);

comment on column public.network_members.auth_user_id is
  'Durable Supabase Auth identity. Never infer membership from display names.';
comment on view public.maskan_networks is 'RLS-protected network projection without credentials.';
comment on view public.maskan_network_members is 'RLS-protected member projection without credentials or auth identifiers.';

commit;
