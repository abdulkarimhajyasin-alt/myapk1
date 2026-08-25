-- Phase 2PV: durable, privacy-preserving rate limits for password operations.

create table private.password_rate_limits (
  key_hash text primary key,
  scope text not null,
  window_started_at timestamptz not null,
  failed_attempts integer not null default 0,
  total_attempts integer not null default 0,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now(),
  constraint password_rate_limits_key_hash_check
    check (key_hash ~ '^[0-9a-f]{64}$'),
  constraint password_rate_limits_scope_check
    check (scope in ('member_verify', 'network_join', 'member_reset')),
  constraint password_rate_limits_counts_check
    check (failed_attempts >= 0 and total_attempts >= 0)
);

create index password_rate_limits_expires_at_idx
  on private.password_rate_limits (expires_at);

alter table private.password_rate_limits enable row level security;
alter table private.password_rate_limits force row level security;

revoke all on table private.password_rate_limits from public, anon, authenticated;

create or replace function public.maskan_password_rate_limit_check(
  p_key_hash text,
  p_scope text
)
returns table(allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_failed_attempts integer;
  v_total_attempts integer;
  v_expires_at timestamptz;
begin
  if p_key_hash !~ '^[0-9a-f]{64}$'
     or p_scope not in ('member_verify', 'network_join', 'member_reset') then
    raise exception 'invalid rate-limit key';
  end if;

  -- Bound table growth without relying on Edge instance memory or a cron job.
  delete from private.password_rate_limits where expires_at <= v_now;

  insert into private.password_rate_limits (
    key_hash,
    scope,
    window_started_at,
    failed_attempts,
    total_attempts,
    expires_at,
    updated_at
  ) values (
    p_key_hash,
    p_scope,
    v_now,
    0,
    1,
    v_now + interval '5 minutes',
    v_now
  )
  on conflict (key_hash) do update
    set total_attempts = private.password_rate_limits.total_attempts + 1,
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

create or replace function public.maskan_password_rate_limit_failure(
  p_key_hash text
)
returns void
language sql
security definer
set search_path = pg_catalog, private
as $$
  update private.password_rate_limits
  set failed_attempts = failed_attempts + 1,
      updated_at = clock_timestamp()
  where key_hash = p_key_hash
    and expires_at > clock_timestamp();
$$;

create or replace function public.maskan_password_rate_limit_success(
  p_key_hash text
)
returns void
language sql
security definer
set search_path = pg_catalog, private
as $$
  delete from private.password_rate_limits where key_hash = p_key_hash;
$$;

create or replace function public.maskan_password_rate_limit_cleanup()
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  v_deleted bigint;
begin
  delete from private.password_rate_limits where expires_at <= clock_timestamp();
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.maskan_password_rate_limit_check(text, text)
  from public, anon, authenticated;
revoke all on function public.maskan_password_rate_limit_failure(text)
  from public, anon, authenticated;
revoke all on function public.maskan_password_rate_limit_success(text)
  from public, anon, authenticated;
revoke all on function public.maskan_password_rate_limit_cleanup()
  from public, anon, authenticated;

grant execute on function public.maskan_password_rate_limit_check(text, text)
  to service_role;
grant execute on function public.maskan_password_rate_limit_failure(text)
  to service_role;
grant execute on function public.maskan_password_rate_limit_success(text)
  to service_role;
grant execute on function public.maskan_password_rate_limit_cleanup()
  to service_role;
