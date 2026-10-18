begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Fail closed on inconsistent historical state; never silently repair/delete history.
do $$ begin
  if exists (select 1 from public.expense_cycles where status in ('active','pending_reset')
             group by network_id having count(*) > 1) then
    raise exception 'Review duplicate open cycles before applying hardening';
  end if;
  if exists(select 1 from public.expenses e join public.expense_cycles c on c.id=e.cycle_id
    where e.archived_at is null and (c.status='closed' or c.network_id<>e.network_id)) then
    raise exception 'Review invalid active expense cycle assignments before hardening';
  end if;
  if exists(select 1 from public.expense_reset_requests r join public.expense_cycles c on c.id=r.cycle_id
    where r.status='pending' and (c.status='closed' or c.network_id<>r.network_id
      or r.requested_by_member_id is null or cardinality(r.required_member_ids)=0
      or not(r.requested_by_member_id=any(r.required_member_ids))
      or exists(select 1 from public.network_members m where m.network_id=r.network_id
        and m.created_at<=r.created_at and not(m.id=any(r.required_member_ids)))
      or exists(select 1 from unnest(r.required_member_ids) required(id) where not exists(
        select 1 from public.network_members m where m.id=required.id and m.network_id=r.network_id)))) then
    raise exception 'Review unsafe historical pending approval snapshots before hardening';
  end if;
end $$;
create unique index expense_cycles_one_open_idx on public.expense_cycles(network_id)
  where status in ('active','pending_reset');

-- RPCs take the per-network advisory lock BEFORE row locks. Direct REST row
-- triggers use try-lock: PostgreSQL may already own a tuple lock, so waiting
-- here would invert the order against completion. Return 40001 for a retry.
create function private.maskan_lock_network(p_network_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  if p_network_id is null then raise exception 'network_required' using errcode='23514'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('maskan-finance:' || p_network_id::text, 0));
end $$;
revoke all on function private.maskan_lock_network(uuid) from public, anon, authenticated;

create function private.maskan_guard_expense()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  v_network uuid := case when tg_op='DELETE' then old.network_id else new.network_id end;
  v_cycle uuid;
  v_existing public.expenses%rowtype;
  v_client boolean := current_user in ('anon','authenticated');
begin
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('maskan-finance:' || v_network::text,0)) then
    raise exception 'network_busy_retry' using errcode='40001';
  end if;
  if not v_client then
    -- Trusted completion and verified account redaction/cascades remain valid.
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op <> 'INSERT' then
    if old.archived_at is not null then raise exception 'archived_expense_immutable' using errcode='42501'; end if;
    if old.added_by_member_id is distinct from public.maskan_current_member_id() then
      raise exception 'expense_author_required' using errcode='42501';
    end if;
    if tg_op='DELETE' then return old; end if;
    if (to_jsonb(new) - array['amount_cents','note']) is distinct from
       (to_jsonb(old) - array['amount_cents','note']) then
      raise exception 'protected_expense_fields' using errcode='42501';
    end if;
    return new;
  end if;
  if new.archived_at is not null or new.added_by_member_id is distinct from public.maskan_current_member_id() then
    raise exception 'invalid_expense_identity' using errcode='42501';
  end if;
  select c.id into v_cycle from public.expense_cycles c
    where c.network_id=v_network and c.status in ('active','pending_reset');
  if v_cycle is null or (new.cycle_id is not null and new.cycle_id<>v_cycle) then
    raise exception 'stale_expense_cycle' using errcode='40001';
  end if;
  new.cycle_id := v_cycle;
  -- An operation key is scoped to its network, not a similarity heuristic.
  -- Distinct payloads must never be reported as an already-synced expense.
  if new.client_generated_id is not null then
    if btrim(new.client_generated_id)='' then raise exception 'invalid_operation_id' using errcode='23514'; end if;
    select * into v_existing from public.expenses e
      where e.network_id=v_network and e.client_generated_id=new.client_generated_id;
    if found and (v_existing.cycle_id,v_existing.added_by_member_id,v_existing.paid_by_member_id,v_existing.amount_cents,v_existing.note)
      is distinct from (new.cycle_id,new.added_by_member_id,new.paid_by_member_id,new.amount_cents,new.note) then
      raise exception 'expense_operation_conflict' using errcode='P0001';
    end if;
  end if;
  select m.name into new.paid_by_member_name from public.network_members m
    where m.id=new.paid_by_member_id and m.network_id=v_network;
  if not found then raise exception 'invalid_payer' using errcode='42501'; end if;
  select m.name into new.added_by_member_name from public.network_members m where m.id=new.added_by_member_id;
  new.created_at := clock_timestamp();
  return new;
end $$;
revoke all on function private.maskan_guard_expense() from public, anon, authenticated;
create trigger maskan_guard_expense before insert or update or delete on public.expenses
  for each row execute function private.maskan_guard_expense();
revoke update on public.expenses from authenticated;
revoke update (cycle_id,paid_by_member_id,paid_by_member_name,amount_cents,note,archived_at) on public.expenses from authenticated;
grant update (amount_cents,note) on public.expenses to authenticated;
drop policy maskan_expenses_update on public.expenses;
create policy maskan_expenses_update on public.expenses for update to authenticated
  using (archived_at is null and added_by_member_id=(select public.maskan_current_member_id()))
  with check (archived_at is null and added_by_member_id=(select public.maskan_current_member_id()));
drop policy maskan_expenses_delete on public.expenses;
create policy maskan_expenses_delete on public.expenses for delete to authenticated
  using (archived_at is null and added_by_member_id=(select public.maskan_current_member_id()));

-- Protect direct legacy cycle inserts and the old Android pending-marker UPDATE.
create function private.maskan_guard_cycle()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_request public.expense_reset_requests%rowtype;
begin
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('maskan-finance:'||new.network_id::text,0)) then
    raise exception 'network_busy_retry' using errcode='40001';
  end if;
  if current_user not in ('anon','authenticated') then return new; end if;
  if tg_op='INSERT' then
    if new.status<>'active' or new.closed_at is not null or not public.maskan_can_create_active_cycle(new.network_id,new.cycle_number) then
      raise exception 'invalid_initial_cycle' using errcode='42501';
    end if;
    return new;
  end if;
  if (to_jsonb(new)-array['status','requested_by_member_id','requested_by_member_name']) is distinct from
     (to_jsonb(old)-array['status','requested_by_member_id','requested_by_member_name']) or new.status<>'pending_reset' then
    raise exception 'protected_cycle_fields' using errcode='42501';
  end if;
  -- A legacy follow-up arriving after completion is a harmless no-op.
  if old.status='closed' then return null; end if;
  select * into v_request from public.expense_reset_requests r
    where r.network_id=old.network_id and r.cycle_id=old.id and r.status='pending';
  if not found or v_request.requested_by_member_id is distinct from public.maskan_current_member_id()
    or new.requested_by_member_id is distinct from v_request.requested_by_member_id then
    raise exception 'pending_request_required' using errcode='42501';
  end if;
  new.requested_by_member_name := v_request.requested_by_member_name;
  return new;
end $$;
revoke all on function private.maskan_guard_cycle() from public, anon, authenticated;
create trigger maskan_guard_cycle before insert or update on public.expense_cycles
  for each row execute function private.maskan_guard_cycle();
grant update(status,requested_by_member_id,requested_by_member_name) on public.expense_cycles to authenticated;
create or replace function public.maskan_can_create_active_cycle(target_network_id uuid,target_cycle_number integer)
returns boolean language sql stable security definer set search_path='' as $$
  select public.maskan_is_network_member(target_network_id)
    and not exists(select 1 from public.expense_cycles where network_id=target_network_id and status in ('active','pending_reset'))
    and target_cycle_number=(select coalesce(max(cycle_number),0)+1 from public.expense_cycles where network_id=target_network_id)
$$;

-- Closed-cycle retries return false (no new side effect), preserving the boolean
-- contract that legacy clients use to decide whether to send notifications.
create or replace function public.maskan_complete_expense_cycle(p_network_id uuid,p_cycle_id uuid,p_reset_request_id uuid default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare
  v_member uuid;
  v_cycle public.expense_cycles%rowtype;
  v_request public.expense_reset_requests%rowtype;
  v_time timestamptz;
begin
  if not public.maskan_is_network_member(p_network_id) then raise exception 'membership_required' using errcode='42501'; end if;
  perform private.maskan_lock_network(p_network_id);
  select m.id into v_member from public.network_members m where m.auth_user_id=auth.uid() and m.network_id=p_network_id;
  if v_member is null then raise exception 'membership_required' using errcode='42501'; end if;
  select * into v_cycle from public.expense_cycles c where c.id=p_cycle_id and c.network_id=p_network_id for update;
  if not found then raise exception 'cycle_not_found' using errcode='P0002'; end if;
  if p_reset_request_id is null then
    if not exists(select 1 from public.networks where id=p_network_id and created_by_member_id=v_member) then
      raise exception 'owner_required' using errcode='42501';
    end if;
  else
    select * into v_request from public.expense_reset_requests r
      where r.id=p_reset_request_id and r.network_id=p_network_id and r.cycle_id=p_cycle_id for update;
    if not found then raise exception 'request_not_found' using errcode='42501'; end if;
  end if;
  if v_cycle.status='closed' then return false; end if;
  if p_reset_request_id is null then
    if exists(select 1 from public.expense_reset_requests where network_id=p_network_id and status='pending') then
      raise exception 'pending_request' using errcode='23514';
    end if;
  elsif v_request.status<>'pending' or cardinality(v_request.required_member_ids)=0 or exists(
    select 1 from unnest(v_request.required_member_ids) as required(member_id)
    where not exists(select 1 from public.expense_reset_approvals a where a.reset_request_id=v_request.id and a.member_id=required.member_id)
  ) then return false;
  end if;
  v_time := clock_timestamp();
  update public.expenses set cycle_id=p_cycle_id,archived_at=v_time
    where network_id=p_network_id and archived_at is null and (cycle_id=p_cycle_id or cycle_id is null);
  update public.expense_cycles set status='closed',closed_at=v_time where id=p_cycle_id;
  insert into public.expense_cycles(network_id,cycle_number,status,started_at)
    values(p_network_id,v_cycle.cycle_number+1,'active',v_time);
  if p_reset_request_id is not null then
    update public.expense_reset_requests set status='completed',completed_at=v_time where id=p_reset_request_id;
  end if;
  insert into public.network_notifications(network_id,recipient_member_id,actor_member_id,actor_member_name,amount_cents,currency_symbol,kind,reset_request_id)
    select n.id,m.id,null,n.name,0,n.currency_symbol,'cycleStarted',p_reset_request_id
    from public.networks n join public.network_members m on m.network_id=n.id where n.id=p_network_id;
  return true;
end $$;
revoke all on function public.maskan_complete_expense_cycle(uuid,uuid,uuid) from public,anon;
grant execute on function public.maskan_complete_expense_cycle(uuid,uuid,uuid) to authenticated;

create function private.maskan_prepare_reset_request()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('maskan-finance:'||new.network_id::text,0)) then
    raise exception 'network_busy_retry' using errcode='40001';
  end if;
  if new.requested_by_member_id is distinct from public.maskan_current_member_id()
    or not public.maskan_is_network_member(new.network_id) then
    raise exception 'requester_required' using errcode='42501';
  end if;
  if not exists(select 1 from public.expense_cycles c where c.id=new.cycle_id and c.network_id=new.network_id and c.status='active') then
    raise exception 'stale_expense_cycle' using errcode='40001';
  end if;
  select array_agg(m.id order by m.id),array_agg(m.name order by m.id)
    into new.required_member_ids,new.required_member_names from public.network_members m where m.network_id=new.network_id;
  select name into new.requested_by_member_name from public.network_members where id=new.requested_by_member_id;
  new.status := 'pending'; new.completed_at := null; new.created_at := clock_timestamp();
  return new;
end $$;
revoke all on function private.maskan_prepare_reset_request() from public,anon,authenticated;
create trigger maskan_prepare_reset_request before insert on public.expense_reset_requests
  for each row execute function private.maskan_prepare_reset_request();

create function private.maskan_guard_approval()
returns trigger language plpgsql security invoker set search_path='' as $$
declare v_request public.expense_reset_requests%rowtype;
begin
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('maskan-finance:'||new.network_id::text,0)) then
    raise exception 'network_busy_retry' using errcode='40001';
  end if;
  if current_user in ('anon','authenticated') and new.member_id is distinct from public.maskan_current_member_id() then
    raise exception 'approval_owner_required' using errcode='42501';
  end if;
  if tg_op='UPDATE' then
    if (new.id,new.network_id,new.member_id,new.reset_request_id) is distinct from (old.id,old.network_id,old.member_id,old.reset_request_id) then
      raise exception 'approval_identity_immutable' using errcode='42501';
    end if;
    return old;
  end if;
  select * into v_request from public.expense_reset_requests r where r.id=new.reset_request_id and r.network_id=new.network_id;
  if not found or not (new.member_id=any(v_request.required_member_ids)) then
    raise exception 'approval_not_required' using errcode='42501';
  end if;
  if exists(select 1 from public.expense_reset_approvals a where a.reset_request_id=new.reset_request_id and a.member_id=new.member_id) then
    return null; -- Legacy plain INSERT and merge-upsert retries both succeed without mutation.
  end if;
  if v_request.status<>'pending' then raise exception 'request_not_pending' using errcode='42501'; end if;
  select name into new.member_name from public.network_members where id=new.member_id and network_id=new.network_id;
  if not found then raise exception 'membership_required' using errcode='42501'; end if;
  new.approved_at := clock_timestamp();
  return new;
end $$;
revoke all on function private.maskan_guard_approval() from public,anon,authenticated;
create trigger maskan_guard_approval before insert or update on public.expense_reset_approvals
  for each row execute function private.maskan_guard_approval();
-- Required for the published Android merge-upsert payload, protected by the trigger.
grant update(reset_request_id,network_id,member_id,member_name,approved_at) on public.expense_reset_approvals to authenticated;
create policy maskan_approvals_retry on public.expense_reset_approvals for update to authenticated
  using(member_id=(select public.maskan_current_member_id())) with check(member_id=(select public.maskan_current_member_id()));
-- Approvals are durable votes. No shipped client withdraws votes through DELETE.
revoke delete on public.expense_reset_approvals from authenticated;

create function private.maskan_finish_reset_request()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.expense_reset_approvals(reset_request_id,network_id,member_id,member_name)
    values(new.id,new.network_id,new.requested_by_member_id,new.requested_by_member_name);
  update public.expense_cycles set status='pending_reset',requested_by_member_id=new.requested_by_member_id,
    requested_by_member_name=new.requested_by_member_name where id=new.cycle_id;
  insert into public.network_notifications(network_id,recipient_member_id,actor_member_id,actor_member_name,amount_cents,currency_symbol,kind,reset_request_id)
    select new.network_id,m.id,new.requested_by_member_id,new.requested_by_member_name,0,n.currency_symbol,'resetRequest',new.id
    from public.network_members m join public.networks n on n.id=m.network_id
    where m.network_id=new.network_id and m.id<>new.requested_by_member_id;
  return new;
end $$;
revoke all on function private.maskan_finish_reset_request() from public,anon,authenticated;
create trigger maskan_finish_reset_request after insert on public.expense_reset_requests
  for each row execute function private.maskan_finish_reset_request();

create function private.maskan_finish_approval()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_cycle uuid;
begin
  -- The initiating vote runs nested inside request creation; finish that first.
  if pg_trigger_depth()>1 or auth.uid() is null then return new; end if;
  select cycle_id into v_cycle from public.expense_reset_requests where id=new.reset_request_id;
  perform public.maskan_complete_expense_cycle(new.network_id,v_cycle,new.reset_request_id);
  return new;
end $$;
revoke all on function private.maskan_finish_approval() from public,anon,authenticated;
create trigger maskan_finish_approval after insert on public.expense_reset_approvals
  for each row execute function private.maskan_finish_approval();

create function public.maskan_request_expense_reset(p_network_id uuid,p_cycle_id uuid)
returns public.expense_reset_requests language plpgsql security definer set search_path='' as $$
declare v_result public.expense_reset_requests%rowtype; v_member uuid;
begin
  if not public.maskan_is_network_member(p_network_id) then raise exception 'membership_required' using errcode='42501'; end if;
  perform private.maskan_lock_network(p_network_id);
  v_member := public.maskan_current_member_id();
  if v_member is null or not public.maskan_is_network_member(p_network_id) then
    raise exception 'membership_required' using errcode='42501';
  end if;
  select * into v_result from public.expense_reset_requests where network_id=p_network_id and cycle_id=p_cycle_id and requested_by_member_id=v_member and status in ('pending','completed')
    order by created_at desc limit 1;
  if found then return v_result; end if;
  insert into public.expense_reset_requests(network_id,cycle_id,requested_by_member_id,requested_by_member_name)
    values(p_network_id,p_cycle_id,v_member,'') returning * into v_result;
  return v_result;
end $$;
create function public.maskan_approve_expense_reset(p_network_id uuid,p_reset_request_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_request public.expense_reset_requests%rowtype; v_member uuid;
begin
  if not public.maskan_is_network_member(p_network_id) then raise exception 'membership_required' using errcode='42501'; end if;
  perform private.maskan_lock_network(p_network_id);
  v_member := public.maskan_current_member_id();
  if v_member is null or not public.maskan_is_network_member(p_network_id) then
    raise exception 'membership_required' using errcode='42501';
  end if;
  select * into v_request from public.expense_reset_requests where id=p_reset_request_id and network_id=p_network_id;
  if not found or not(v_member=any(v_request.required_member_ids)) then raise exception 'approval_not_required' using errcode='42501'; end if;
  if v_request.status='completed' then return true; end if;
  if v_request.status<>'pending' then raise exception 'request_not_pending' using errcode='42501'; end if;
  insert into public.expense_reset_approvals(reset_request_id,network_id,member_id,member_name)
    values(p_reset_request_id,p_network_id,v_member,'');
  perform public.maskan_complete_expense_cycle(p_network_id,v_request.cycle_id,p_reset_request_id);
  return exists(select 1 from public.expense_reset_requests where id=p_reset_request_id and status='completed');
end $$;
revoke all on function public.maskan_request_expense_reset(uuid,uuid) from public,anon;
revoke all on function public.maskan_approve_expense_reset(uuid,uuid) from public,anon;
grant execute on function public.maskan_request_expense_reset(uuid,uuid),public.maskan_approve_expense_reset(uuid,uuid) to authenticated;

-- Reset/cycle events now originate exactly once from the same transaction.
-- Suppress redundant legacy client notifications (minimal-return INSERTs).
create function private.maskan_guard_notification_insert()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_user in ('anon','authenticated') and new.kind in ('resetRequest','cycleStarted') then return null; end if;
  return new;
end $$;
revoke all on function private.maskan_guard_notification_insert() from public,anon,authenticated;
create trigger maskan_guard_notification_insert before insert on public.network_notifications
  for each row execute function private.maskan_guard_notification_insert();
create or replace function public.phase5_prevent_notification_identity_update()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  -- Verified account deletion anonymizes actor fields as the function owner.
  if current_user in ('anon','authenticated') and (to_jsonb(new)-'is_read') is distinct from (to_jsonb(old)-'is_read') then
    raise exception 'Only notification read state can be updated.' using errcode='42501';
  end if;
  return new;
end $$;
revoke all on function public.phase5_prevent_notification_identity_update() from public,anon,authenticated;

-- No current RLS policy or client uses the retired phase5 lookup predicates.
-- Keep the definitions for historical migration reproducibility, remove exposure.
do $$ declare f record; begin
  for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'phase5_member_belongs_to_network','phase5_network_exists','phase5_expense_members_match_network',
      'phase5_network_has_no_active_expenses','phase5_network_can_be_deleted_after_leave','phase5_notification_matches_network',
      'phase5_cycle_member_belongs_to_network','phase5_reset_request_matches_network','phase5_reset_approval_matches_network')
  loop execute format('revoke all on function %s from public, anon, authenticated',f.signature); end loop;
end $$;

-- FK indexes support account deletion/cascades; keep existing indexes regardless of usage counters.
create index if not exists networks_created_by_member_idx on public.networks(created_by_member_id);
create index if not exists expense_cycles_requested_by_member_idx on public.expense_cycles(requested_by_member_id);
create index if not exists expense_reset_requests_cycle_idx on public.expense_reset_requests(cycle_id);
create index if not exists expense_reset_requests_requester_idx on public.expense_reset_requests(requested_by_member_id);
create index if not exists expense_reset_approvals_member_idx on public.expense_reset_approvals(member_id);
create index if not exists expense_reset_approvals_network_idx on public.expense_reset_approvals(network_id);
create index if not exists network_notifications_actor_idx on public.network_notifications(actor_member_id);
create index if not exists network_notifications_expense_idx on public.network_notifications(expense_id);
create index if not exists network_notifications_reset_idx on public.network_notifications(reset_request_id);

-- Cancellation and member removal must release the pending marker, under the
-- same lock as approval/completion. Historical snapshots stay unchanged.
create function private.maskan_guard_request_delete()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('maskan-finance:'||old.network_id::text,0)) then
    raise exception 'network_busy_retry' using errcode='40001';
  end if;
  return old;
end $$;
create function private.maskan_release_pending_cycle()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.status='pending' and (tg_op='DELETE' or new.status='cancelled') then
    update public.expense_cycles set status='active',requested_by_member_id=null,requested_by_member_name=null
      where id=old.cycle_id and status='pending_reset';
  end if;
  return null;
end $$;
revoke all on function private.maskan_guard_request_delete(),private.maskan_release_pending_cycle() from public,anon,authenticated;
create trigger maskan_guard_request_delete before delete on public.expense_reset_requests
  for each row execute function private.maskan_guard_request_delete();
create trigger maskan_release_pending_cycle after delete or update on public.expense_reset_requests
  for each row execute function private.maskan_release_pending_cycle();

create function private.maskan_guard_membership_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_network uuid := case when tg_op='DELETE' then old.network_id else new.network_id end;
begin
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended('maskan-finance:'||v_network::text,0)) then
    raise exception 'network_busy_retry' using errcode='40001';
  end if;
  if tg_op='DELETE' then
    update public.expense_reset_requests set status='cancelled',completed_at=clock_timestamp()
      where network_id=v_network and status='pending' and old.id=any(required_member_ids);
    return old;
  end if;
  return new;
end $$;
revoke all on function private.maskan_guard_membership_change() from public,anon,authenticated;
create trigger maskan_guard_membership_change before insert or delete or update of network_id,auth_user_id on public.network_members
  for each row execute function private.maskan_guard_membership_change();

-- Preserve verified account deletion and legacy leave, with canonical lock order.
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

  select m.network_id into v_network_id from public.network_members m where m.auth_user_id=v_auth_user_id;
  if v_network_id is null then raise exception 'account_not_found' using errcode='P0002'; end if;
  perform private.maskan_lock_network(v_network_id);

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
  if not public.maskan_is_network_member(p_network_id) then raise exception 'membership_required' using errcode='42501'; end if;
  perform private.maskan_lock_network(p_network_id);
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
-- Safe reconciliation of validated historical requests: the requester already
-- consented by creating the request. Do not auto-complete historical requests.
insert into public.expense_reset_approvals(reset_request_id,network_id,member_id,member_name)
  select r.id,r.network_id,r.requested_by_member_id,r.requested_by_member_name
  from public.expense_reset_requests r where r.status='pending'
  on conflict(reset_request_id,member_id) do nothing;
insert into public.network_notifications(network_id,recipient_member_id,actor_member_id,actor_member_name,amount_cents,currency_symbol,kind,reset_request_id)
  select r.network_id,m.id,r.requested_by_member_id,r.requested_by_member_name,0,n.currency_symbol,'resetRequest',r.id
  from public.expense_reset_requests r join public.networks n on n.id=r.network_id
  join public.network_members m on m.network_id=r.network_id
  where r.status='pending' and m.id<>r.requested_by_member_id and m.id=any(r.required_member_ids)
    and not exists(select 1 from public.network_notifications existing where existing.reset_request_id=r.id
      and existing.recipient_member_id=m.id and existing.kind='resetRequest');
update public.expense_cycles c set status='pending_reset',requested_by_member_id=r.requested_by_member_id,
  requested_by_member_name=r.requested_by_member_name
  from public.expense_reset_requests r where r.cycle_id=c.id and r.status='pending';

-- Completed reset history is not a client-deletable cancellation request.
drop policy maskan_reset_requests_delete on public.expense_reset_requests;
create policy maskan_reset_requests_delete on public.expense_reset_requests for delete to authenticated
  using(status='pending' and requested_by_member_id=(select public.maskan_current_member_id()));
create index if not exists member_claim_tokens_auth_user_idx on private.member_claim_tokens(auth_user_id);

create or replace function public.maskan_claim_member(
  p_member_id uuid,
  p_claim_token text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  claim private.member_claim_tokens%rowtype;
  supplied_hash text;
begin
  if caller_id is null or coalesce(p_claim_token, '') = '' then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
  end if;
  supplied_hash := encode(extensions.digest(convert_to(p_claim_token, 'UTF8'), 'sha256'), 'hex');
  select * into strict claim from private.member_claim_tokens
  where member_id = p_member_id for update;
  if claim.auth_user_id <> caller_id
     or claim.expires_at <= clock_timestamp()
     or claim.token_hash <> supplied_hash then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.network_members where auth_user_id = caller_id and id <> p_member_id
  ) then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
  end if;
  update public.network_members
  set auth_user_id = caller_id
  where id = p_member_id and (auth_user_id is null or auth_user_id = caller_id);
  if not found then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
  end if;
  delete from private.member_claim_tokens where member_id = p_member_id;
exception
  when no_data_found then
    raise exception 'Invalid member credentials' using errcode = 'P0001';
end;
$$;
commit;
