begin;

-- Google Play account-deletion readiness. The destructive RPC accepts no user
-- or member identifier: the sole account authority is the caller's auth.uid().

create table private.account_deletion_rate_limits (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  failed_attempts integer not null default 0,
  total_attempts integer not null default 0,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now(),
  constraint account_deletion_rate_limits_counts_check
    check (failed_attempts >= 0 and total_attempts >= 0)
);

alter table private.account_deletion_rate_limits enable row level security;
alter table private.account_deletion_rate_limits force row level security;
revoke all on table private.account_deletion_rate_limits
  from public, anon, authenticated;

create table private.account_deletion_authorizations (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  token_hash text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table private.account_deletion_authorizations enable row level security;
alter table private.account_deletion_authorizations force row level security;
revoke all on table private.account_deletion_authorizations
  from public, anon, authenticated;

create or replace function public.maskan_account_deletion_rate_limit_check()
returns table(allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_failed_attempts integer;
  v_total_attempts integer;
  v_expires_at timestamptz;
begin
  if v_auth_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  delete from private.account_deletion_rate_limits
  where expires_at <= v_now;

  insert into private.account_deletion_rate_limits (
    auth_user_id,
    window_started_at,
    failed_attempts,
    total_attempts,
    expires_at,
    updated_at
  ) values (
    v_auth_user_id,
    v_now,
    0,
    1,
    v_now + interval '5 minutes',
    v_now
  )
  on conflict (auth_user_id) do update
    set total_attempts =
          private.account_deletion_rate_limits.total_attempts + 1,
        updated_at = v_now
  returning failed_attempts, total_attempts, expires_at
    into v_failed_attempts, v_total_attempts, v_expires_at;

  allowed := v_failed_attempts < 5 and v_total_attempts <= 10;
  retry_after_seconds := greatest(
    1,
    ceil(extract(epoch from (v_expires_at - v_now)))::integer
  );
  return next;
end;
$$;

create or replace function public.maskan_account_deletion_rate_limit_failure()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid := auth.uid();
begin
  if v_auth_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  update private.account_deletion_rate_limits
  set failed_attempts = failed_attempts + 1,
      updated_at = clock_timestamp()
  where auth_user_id = v_auth_user_id
    and expires_at > clock_timestamp();
end;
$$;

create or replace function public.maskan_account_deletion_context()
returns table (
  member_id uuid,
  network_id uuid,
  network_name text,
  member_count bigint,
  is_owner boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid := auth.uid();
begin
  if v_auth_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  return query
  select
    m.id,
    m.network_id,
    n.name,
    count(all_members.id),
    n.created_by_member_id = m.id
  from public.network_members as m
  join public.networks as n on n.id = m.network_id
  join public.network_members as all_members
    on all_members.network_id = m.network_id
  where m.auth_user_id = v_auth_user_id
  group by m.id, m.network_id, n.name, n.created_by_member_id;

  if not found then
    raise exception 'account_not_found' using errcode = 'P0002';
  end if;
end;
$$;

-- Only the trusted Edge Function can mint a short-lived, one-use deletion
-- authorization after it has re-authenticated the account password.
create or replace function public.maskan_authorize_account_deletion(
  p_auth_user_id uuid,
  p_token_hash text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_auth_user_id is null
     or p_token_hash !~ '^[0-9a-f]{64}$'
     or not exists (
       select 1 from auth.users as u where u.id = p_auth_user_id
     ) then
    raise exception 'invalid_deletion_authorization'
      using errcode = '23514';
  end if;

  insert into private.account_deletion_authorizations (
    auth_user_id,
    token_hash,
    expires_at,
    created_at
  ) values (
    p_auth_user_id,
    p_token_hash,
    clock_timestamp() + interval '2 minutes',
    clock_timestamp()
  )
  on conflict (auth_user_id) do update
    set token_hash = excluded.token_hash,
        expires_at = excluded.expires_at,
        created_at = excluded.created_at;
end;
$$;

create or replace function public.maskan_delete_account_data(
  p_deletion_token text,
  p_confirm_network_deletion boolean default false
)
returns table (
  deleted_member_id uuid,
  deleted_network_id uuid,
  network_deleted boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_auth_user_id uuid := auth.uid();
  v_member_id uuid;
  v_network_id uuid;
  v_member_count bigint;
  v_is_owner boolean;
  v_token_hash text;
begin
  if v_auth_user_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if coalesce(p_deletion_token, '') = '' then
    raise exception 'reauthentication_required' using errcode = '42501';
  end if;

  v_token_hash := encode(
    extensions.digest(convert_to(p_deletion_token, 'UTF8'), 'sha256'),
    'hex'
  );
  delete from private.account_deletion_authorizations as deletion_authorization
  where deletion_authorization.auth_user_id = v_auth_user_id
    and deletion_authorization.token_hash = v_token_hash
    and deletion_authorization.expires_at > clock_timestamp();
  if not found then
    raise exception 'reauthentication_required' using errcode = '42501';
  end if;

  select m.id, m.network_id
  into v_member_id, v_network_id
  from public.network_members as m
  where m.auth_user_id = v_auth_user_id
  for update;
  if v_member_id is null then
    raise exception 'account_not_found' using errcode = 'P0002';
  end if;

  perform n.id
  from public.networks as n
  where n.id = v_network_id
  for update;
  perform m.id
  from public.network_members as m
  where m.network_id = v_network_id
  order by m.id
  for update;

  select
    count(*),
    bool_or(n.created_by_member_id = v_member_id)
  into v_member_count, v_is_owner
  from public.network_members as m
  join public.networks as n on n.id = m.network_id
  where m.network_id = v_network_id;

  if v_member_count = 1 then
    if not coalesce(p_confirm_network_deletion, false) then
      raise exception 'network_confirmation_required' using errcode = 'P0001';
    end if;

    delete from public.networks as n where n.id = v_network_id;
    delete from private.account_deletion_rate_limits as rate_limit
    where rate_limit.auth_user_id = v_auth_user_id;

    return query select v_member_id, v_network_id, true;
    return;
  end if;

  if coalesce(v_is_owner, false) then
    raise exception 'owner_transfer_required' using errcode = 'P0001';
  end if;

  -- Shared financial records remain available to the other members, but the
  -- deleted account's identifiers and display name are removed.
  update public.expenses as expense
  set paid_by_member_id = null,
      paid_by_member_name = 'Deleted account'
  where expense.network_id = v_network_id
    and expense.paid_by_member_id = v_member_id;

  update public.expenses as expense
  set added_by_member_id = null,
      added_by_member_name = 'Deleted account'
  where expense.network_id = v_network_id
    and expense.added_by_member_id = v_member_id;

  update public.expense_cycles as cycle
  set requested_by_member_id = null,
      requested_by_member_name = null
  where cycle.network_id = v_network_id
    and cycle.requested_by_member_id = v_member_id;

  update public.expense_reset_requests as request
  set requested_by_member_id = null,
      requested_by_member_name = 'Deleted account',
      status = case
        when request.status = 'pending' then 'cancelled'
        else request.status
      end,
      completed_at = case
        when request.status = 'pending' then clock_timestamp()
        else request.completed_at
      end
  where request.network_id = v_network_id
    and request.requested_by_member_id = v_member_id;

  update public.expense_reset_requests as request
  set required_member_ids = array_remove(
        request.required_member_ids,
        v_member_id
      ),
      required_member_names = coalesce(
        (
          select array_agg(entry.member_name order by entry.ordinality)
          from unnest(
            request.required_member_ids,
            request.required_member_names
          ) with ordinality as entry(member_id, member_name, ordinality)
          where entry.member_id <> v_member_id
        ),
        '{}'::text[]
      ),
      status = case
        when request.status = 'pending' then 'cancelled'
        else request.status
      end,
      completed_at = case
        when request.status = 'pending' then clock_timestamp()
        else request.completed_at
      end
  where request.network_id = v_network_id
    and v_member_id = any(request.required_member_ids);

  delete from public.network_notifications as notification
  where notification.network_id = v_network_id
    and notification.recipient_member_id = v_member_id;

  update public.network_notifications as notification
  set actor_member_id = null,
      actor_member_name = 'Deleted account'
  where notification.network_id = v_network_id
    and notification.actor_member_id = v_member_id;

  -- Cascades remove the private member credential, claim token, reset
  -- approvals, and any remaining recipient-only notification rows.
  delete from public.network_members as member
  where member.id = v_member_id
    and member.auth_user_id = v_auth_user_id;
  if not found then
    raise exception 'account_delete_conflict' using errcode = '40001';
  end if;

  delete from private.account_deletion_rate_limits as rate_limit
  where rate_limit.auth_user_id = v_auth_user_id;

  return query select v_member_id, v_network_id, false;
end;
$$;

-- Keep the older membership-only action from orphaning an Auth account or
-- leaving a multi-member network without an owner. Last-member exits must use
-- the verified account-deletion path above.
create or replace function public.maskan_leave_network(p_network_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_member_id uuid;
  v_member_count integer;
begin
  select m.id into v_caller_member_id
  from public.network_members as m
  where m.auth_user_id = auth.uid()
    and m.network_id = p_network_id;
  if v_caller_member_id is null then
    raise exception 'membership_required' using errcode = '42501';
  end if;

  select count(*) into v_member_count
  from public.network_members as m
  where m.network_id = p_network_id;

  if v_member_count = 1 then
    raise exception 'account_deletion_required' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.networks as n
    where n.id = p_network_id
      and n.created_by_member_id = v_caller_member_id
  ) then
    raise exception 'owner_transfer_required' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.expenses as expense
    where expense.network_id = p_network_id
      and expense.archived_at is null
  ) then
    raise exception 'Network expenses must be settled before leaving'
      using errcode = '23514';
  end if;

  delete from public.network_notifications as notification
  where notification.network_id = p_network_id
    and (
      notification.recipient_member_id = v_caller_member_id
      or notification.actor_member_id = v_caller_member_id
    );
  delete from public.expense_reset_requests as request
  where request.network_id = p_network_id
    and (
      request.status = 'pending'
      or request.requested_by_member_id = v_caller_member_id
    );
  delete from public.expense_reset_approvals as approval
  where approval.network_id = p_network_id
    and approval.member_id = v_caller_member_id;
  delete from public.network_members as member
  where member.id = v_caller_member_id
    and member.auth_user_id = auth.uid();
end;
$$;

revoke all on function public.maskan_account_deletion_rate_limit_check()
  from public, anon;
revoke all on function public.maskan_account_deletion_rate_limit_failure()
  from public, anon;
revoke all on function public.maskan_account_deletion_context()
  from public, anon;
revoke all on function public.maskan_delete_account_data(text, boolean)
  from public, anon;

grant execute on function public.maskan_account_deletion_rate_limit_check()
  to authenticated;
grant execute on function public.maskan_account_deletion_rate_limit_failure()
  to authenticated;
grant execute on function public.maskan_account_deletion_context()
  to authenticated;
grant execute on function public.maskan_delete_account_data(text, boolean)
  to authenticated;
revoke all on function public.maskan_leave_network(uuid) from public, anon;
grant execute on function public.maskan_leave_network(uuid) to authenticated;

revoke all on function public.maskan_authorize_account_deletion(uuid, text)
  from public, anon, authenticated;
grant execute on function public.maskan_authorize_account_deletion(uuid, text)
  to service_role;

commit;
