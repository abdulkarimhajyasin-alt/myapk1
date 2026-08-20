-- Phase 2: migrate Maskan credentials from legacy FNV to versioned PBKDF2.
-- Modern encoded format:
-- $maskan$pbkdf2-sha256$v=1$i=600000$l=32$<salt-base64url>$<digest-base64url>

alter table private.network_credentials
  rename column password_hash to legacy_password_hash;
alter table private.network_credentials
  rename column password_salt to legacy_password_salt;
alter table private.network_credentials
  alter column legacy_password_hash drop not null,
  alter column legacy_password_salt drop not null,
  add column credential_version smallint not null default 1,
  add column algorithm text not null default 'legacy-fnv1a-64-v1',
  add column password_digest text,
  add column modernized_at timestamptz,
  add column updated_at timestamptz not null default now();

alter table private.member_credentials
  rename column password_hash to legacy_password_hash;
alter table private.member_credentials
  rename column password_salt to legacy_password_salt;
alter table private.member_credentials
  alter column legacy_password_hash drop not null,
  alter column legacy_password_salt drop not null,
  add column credential_version smallint not null default 1,
  add column algorithm text not null default 'legacy-fnv1a-64-v1',
  add column password_digest text,
  add column modernized_at timestamptz,
  add column updated_at timestamptz not null default now(),
  add column auth_password_version smallint not null default 0;

alter table private.network_credentials
  add constraint network_credentials_phase2_state_check check (
    (
      credential_version = 1
      and algorithm = 'legacy-fnv1a-64-v1'
      and legacy_password_hash is not null
      and legacy_password_salt is not null
      and password_digest is null
      and modernized_at is null
    ) or (
      credential_version >= 2
      and algorithm = 'pbkdf2-hmac-sha256-v1'
      and legacy_password_hash is null
      and legacy_password_salt is null
      and password_digest like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%'
      and modernized_at is not null
    )
  );

alter table private.member_credentials
  add constraint member_credentials_phase2_state_check check (
    (
      credential_version = 1
      and algorithm = 'legacy-fnv1a-64-v1'
      and legacy_password_hash is not null
      and legacy_password_salt is not null
      and password_digest is null
      and modernized_at is null
    ) or (
      credential_version >= 2
      and algorithm = 'pbkdf2-hmac-sha256-v1'
      and legacy_password_hash is null
      and legacy_password_salt is null
      and password_digest like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%'
      and modernized_at is not null
    )
  );

alter table private.member_credentials
  add constraint member_credentials_auth_sync_version_check
  check (auth_password_version >= 0 and auth_password_version <= credential_version);

create or replace function private.maskan_reject_credential_downgrade()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.credential_version >= 2 and (
    new.credential_version < old.credential_version
    or new.algorithm <> 'pbkdf2-hmac-sha256-v1'
    or new.password_digest is null
    or new.legacy_password_hash is not null
    or new.legacy_password_salt is not null
  ) then
    raise exception 'Credential downgrade is forbidden' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger maskan_network_credential_no_downgrade
before update on private.network_credentials
for each row execute function private.maskan_reject_credential_downgrade();

create trigger maskan_member_credential_no_downgrade
before update on private.member_credentials
for each row execute function private.maskan_reject_credential_downgrade();

create table private.member_claim_tokens (
  member_id uuid primary key references public.network_members(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  token_hash text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

revoke all on private.network_credentials from public, anon, authenticated;
revoke all on private.member_credentials from public, anon, authenticated;
revoke all on private.member_claim_tokens from public, anon, authenticated;
revoke all on function private.maskan_reject_credential_downgrade() from public, anon, authenticated;

-- Internal credential reads are deliberately exposed only to service_role for
-- the narrow Edge Function. Flutter cannot execute these functions.
create or replace function public.maskan_password_lookup_network(
  p_network_id uuid,
  p_network_name text
)
returns table (
  network_id uuid,
  network_name text,
  credential_version smallint,
  algorithm text,
  password_digest text,
  legacy_password_hash text,
  legacy_password_salt text
)
language sql
stable
security definer
set search_path = ''
as $$
  select n.id, n.name, c.credential_version, c.algorithm,
         c.password_digest, c.legacy_password_hash, c.legacy_password_salt
  from public.networks n
  join private.network_credentials c on c.network_id = n.id
  where (
    p_network_id is not null and n.id = p_network_id
  ) or (
    p_network_id is null
    and n.normalized_name = lower(regexp_replace(btrim(p_network_name), '\s+', ' ', 'g'))
  )
  limit 1
$$;

create or replace function public.maskan_password_lookup_member(
  p_network_name text,
  p_member_name text,
  p_member_id uuid
)
returns table (
  network_id uuid,
  network_name text,
  member_id uuid,
  member_name text,
  auth_user_id uuid,
  credential_version smallint,
  algorithm text,
  password_digest text,
  legacy_password_hash text,
  legacy_password_salt text,
  auth_password_version smallint
)
language sql
stable
security definer
set search_path = ''
as $$
  select n.id, n.name, m.id, m.name, m.auth_user_id,
         c.credential_version, c.algorithm, c.password_digest,
         c.legacy_password_hash, c.legacy_password_salt,
         c.auth_password_version
  from public.networks n
  join public.network_members m on m.network_id = n.id
  join private.member_credentials c on c.member_id = m.id
  where n.normalized_name = lower(regexp_replace(btrim(p_network_name), '\s+', ' ', 'g'))
    and (
      (p_member_id is not null and m.id = p_member_id)
      or (p_member_id is null and m.normalized_name = lower(regexp_replace(btrim(p_member_name), '\s+', ' ', 'g')))
    )
  limit 1
$$;

create or replace function public.maskan_password_upgrade_network(
  p_network_id uuid,
  p_expected_legacy_hash text,
  p_modern_digest text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_modern_digest not like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%' then
    raise exception 'Invalid modern credential' using errcode = '23514';
  end if;
  update private.network_credentials
  set credential_version = 2,
      algorithm = 'pbkdf2-hmac-sha256-v1',
      password_digest = p_modern_digest,
      legacy_password_hash = null,
      legacy_password_salt = null,
      modernized_at = now(),
      updated_at = now()
  where network_id = p_network_id
    and credential_version = 1
    and legacy_password_hash = p_expected_legacy_hash;
  return found;
end;
$$;

create or replace function public.maskan_password_upgrade_member(
  p_member_id uuid,
  p_expected_legacy_hash text,
  p_modern_digest text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_modern_digest not like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%' then
    raise exception 'Invalid modern credential' using errcode = '23514';
  end if;
  update private.member_credentials
  set credential_version = 2,
      algorithm = 'pbkdf2-hmac-sha256-v1',
      password_digest = p_modern_digest,
      legacy_password_hash = null,
      legacy_password_salt = null,
      modernized_at = now(),
      updated_at = now()
  where member_id = p_member_id
    and credential_version = 1
    and legacy_password_hash = p_expected_legacy_hash;
  return found;
end;
$$;

create or replace function public.maskan_password_create_network(
  p_auth_user_id uuid,
  p_network_id uuid,
  p_member_id uuid,
  p_network_name text,
  p_member_name text,
  p_network_password_digest text,
  p_member_password_digest text,
  p_currency_code text,
  p_currency_symbol text
)
returns table (network_id uuid, member_id uuid, network_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_network_name text;
  normalized_member_name text;
begin
  if p_auth_user_id is null or not exists (select 1 from auth.users where id = p_auth_user_id) then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if exists (select 1 from public.network_members where auth_user_id = p_auth_user_id) then
    raise exception 'Auth user already owns a Maskan member' using errcode = '23505';
  end if;
  if p_network_password_digest not like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%'
     or p_member_password_digest not like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%' then
    raise exception 'Invalid modern credential' using errcode = '23514';
  end if;

  normalized_network_name := lower(regexp_replace(btrim(p_network_name), '\s+', ' ', 'g'));
  normalized_member_name := lower(regexp_replace(btrim(p_member_name), '\s+', ' ', 'g'));
  if normalized_network_name = '' or normalized_member_name = '' then
    raise exception 'Required account fields are missing' using errcode = '23514';
  end if;

  insert into public.networks (
    id, name, normalized_name, currency_code, currency_symbol, created_at, updated_at
  ) values (
    p_network_id, btrim(p_network_name), normalized_network_name,
    upper(btrim(p_currency_code)), p_currency_symbol, now(), now()
  );
  insert into private.network_credentials (
    network_id, credential_version, algorithm, password_digest,
    legacy_password_hash, legacy_password_salt, modernized_at, updated_at
  ) values (
    p_network_id, 2, 'pbkdf2-hmac-sha256-v1', p_network_password_digest,
    null, null, now(), now()
  );

  insert into public.network_members (
    id, network_id, auth_user_id, name, normalized_name, created_at
  ) values (
    p_member_id, p_network_id, p_auth_user_id, btrim(p_member_name),
    normalized_member_name, now()
  );
  insert into private.member_credentials (
    member_id, credential_version, algorithm, password_digest,
    legacy_password_hash, legacy_password_salt, modernized_at, updated_at, auth_password_version
  ) values (
    p_member_id, 2, 'pbkdf2-hmac-sha256-v1', p_member_password_digest,
    null, null, now(), now(), 2
  );
  update public.networks set created_by_member_id = p_member_id where id = p_network_id;
  insert into public.expense_cycles (network_id, cycle_number, status, started_at)
  values (p_network_id, 1, 'active', now());
  return query select p_network_id, p_member_id, btrim(p_network_name);
end;
$$;

create or replace function public.maskan_password_join_network(
  p_auth_user_id uuid,
  p_network_id uuid,
  p_member_id uuid,
  p_member_name text,
  p_member_password_digest text,
  p_verified_network_digest text
)
returns table (network_id uuid, member_id uuid, network_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_network public.networks%rowtype;
  normalized_member_name text;
begin
  if p_auth_user_id is null or not exists (select 1 from auth.users where id = p_auth_user_id) then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if exists (select 1 from public.network_members where auth_user_id = p_auth_user_id) then
    raise exception 'Auth user already owns a Maskan member' using errcode = '23505';
  end if;
  if p_member_password_digest not like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%'
     or p_verified_network_digest not like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%' then
    raise exception 'Invalid modern credential' using errcode = '23514';
  end if;
  select * into strict resolved_network from public.networks where id = p_network_id;
  if not exists (
    select 1 from private.network_credentials c
    where c.network_id = p_network_id
      and c.credential_version >= 2
      and c.password_digest = p_verified_network_digest
  ) then
    raise exception 'Invalid network credentials' using errcode = 'P0001';
  end if;

  normalized_member_name := lower(regexp_replace(btrim(p_member_name), '\s+', ' ', 'g'));
  if normalized_member_name = '' then
    raise exception 'Required member fields are missing' using errcode = '23514';
  end if;
  insert into public.network_members (
    id, network_id, auth_user_id, name, normalized_name, created_at
  ) values (
    p_member_id, resolved_network.id, p_auth_user_id, btrim(p_member_name),
    normalized_member_name, now()
  );
  insert into private.member_credentials (
    member_id, credential_version, algorithm, password_digest,
    legacy_password_hash, legacy_password_salt, modernized_at, updated_at, auth_password_version
  ) values (
    p_member_id, 2, 'pbkdf2-hmac-sha256-v1', p_member_password_digest,
    null, null, now(), now(), 2
  );
  return query select resolved_network.id, p_member_id, resolved_network.name;
exception
  when no_data_found then
    raise exception 'Invalid network credentials' using errcode = 'P0001';
end;
$$;

create or replace function public.maskan_password_find_auth_user(p_email text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from auth.users where lower(email) = lower(btrim(p_email)) limit 1
$$;

create or replace function public.maskan_password_mark_auth_synced(
  p_member_id uuid,
  p_credential_version smallint
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update private.member_credentials
  set auth_password_version = p_credential_version, updated_at = now()
  where member_id = p_member_id and credential_version = p_credential_version
    and auth_password_version < p_credential_version;
  if not found and not exists (
    select 1 from private.member_credentials
    where member_id = p_member_id and auth_password_version = credential_version
  ) then
    raise exception 'Credential changed during Auth synchronization' using errcode = '40001';
  end if;
end;
$$;

create or replace function public.maskan_password_issue_claim(
  p_member_id uuid,
  p_auth_user_id uuid,
  p_token_hash text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_token_hash !~ '^[0-9a-f]{64}$'
     or not exists (select 1 from auth.users where id = p_auth_user_id) then
    raise exception 'Invalid claim request' using errcode = '23514';
  end if;
  insert into private.member_claim_tokens (
    member_id, auth_user_id, token_hash, expires_at, created_at
  ) values (
    p_member_id, p_auth_user_id, p_token_hash, now() + interval '2 minutes', now()
  ) on conflict (member_id) do update
    set auth_user_id = excluded.auth_user_id,
        token_hash = excluded.token_hash,
        expires_at = excluded.expires_at,
        created_at = excluded.created_at;
end;
$$;

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
     or claim.expires_at <= now()
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

create or replace function public.maskan_password_reset_context(
  p_caller_auth_user_id uuid,
  p_network_id uuid,
  p_admin_member_id uuid,
  p_target_member_id uuid
)
returns table (target_auth_user_id uuid, target_member_name text, network_name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_admin_member_id = p_target_member_id
     or not exists (
       select 1 from public.network_members a
       join public.networks n on n.id = a.network_id
       where a.id = p_admin_member_id
         and a.auth_user_id = p_caller_auth_user_id
         and a.network_id = p_network_id
         and n.created_by_member_id = a.id
     ) then
    raise exception 'Password reset denied' using errcode = '42501';
  end if;
  return query
  select m.auth_user_id, m.name, n.name
  from public.network_members m
  join public.networks n on n.id = m.network_id
  where m.id = p_target_member_id and m.network_id = p_network_id;
  if not found then
    raise exception 'Password reset denied' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.maskan_password_reset_member(
  p_caller_auth_user_id uuid,
  p_network_id uuid,
  p_admin_member_id uuid,
  p_target_member_id uuid,
  p_modern_digest text
)
returns table (
  id uuid, network_id uuid, name text, normalized_name text,
  password_hash text, password_salt text, avatar_color text,
  avatar_initials text, avatar_image_path text, avatar_image_url text,
  created_at timestamptz, credential_version smallint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_modern_digest not like '$maskan$pbkdf2-sha256$v=1$i=600000$l=32$%'
     or p_admin_member_id = p_target_member_id
     or not exists (
       select 1 from public.network_members a
       join public.networks n on n.id = a.network_id
       where a.id = p_admin_member_id
         and a.auth_user_id = p_caller_auth_user_id
         and a.network_id = p_network_id
         and n.created_by_member_id = a.id
     ) then
    raise exception 'Password reset denied' using errcode = '42501';
  end if;
  update private.member_credentials c
  set credential_version = greatest(c.credential_version + 1, 2),
      algorithm = 'pbkdf2-hmac-sha256-v1',
      password_digest = p_modern_digest,
      legacy_password_hash = null,
      legacy_password_salt = null,
      modernized_at = now(),
      updated_at = now()
  where c.member_id = p_target_member_id
    and exists (
      select 1 from public.network_members m
      where m.id = p_target_member_id and m.network_id = p_network_id
    );
  if not found then
    raise exception 'Password reset denied' using errcode = '42501';
  end if;
  delete from private.member_claim_tokens where member_id = p_target_member_id;
  return query
  select m.id, m.network_id, m.name, m.normalized_name,
         null::text, null::text, m.avatar_color, m.avatar_initials,
         m.avatar_image_path, m.avatar_image_url, m.created_at,
         c.credential_version
  from public.network_members m join private.member_credentials c on c.member_id = m.id where m.id = p_target_member_id;
end;
$$;

-- Retire every client-callable legacy credential authority. The functions stay
-- present only so Phase 1 remains reproducible and can be removed later.
revoke all on function public.maskan_discover_network(text) from public, anon, authenticated;
revoke all on function public.maskan_verify_member_credentials(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.maskan_create_network(uuid, uuid, text, text, text, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.maskan_join_network(uuid, text, text, uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.maskan_claim_legacy_member(uuid, text) from public, anon, authenticated;
revoke all on function public.phase5_reset_member_password(uuid, uuid, uuid, text, text) from public, anon, authenticated;

revoke all on function public.maskan_password_lookup_network(uuid, text) from public, anon, authenticated;
revoke all on function public.maskan_password_lookup_member(text, text, uuid) from public, anon, authenticated;
revoke all on function public.maskan_password_upgrade_network(uuid, text, text) from public, anon, authenticated;
revoke all on function public.maskan_password_upgrade_member(uuid, text, text) from public, anon, authenticated;
revoke all on function public.maskan_password_create_network(uuid, uuid, uuid, text, text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.maskan_password_join_network(uuid, uuid, uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.maskan_password_find_auth_user(text) from public, anon, authenticated;
revoke all on function public.maskan_password_issue_claim(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.maskan_password_reset_context(uuid, uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.maskan_password_mark_auth_synced(uuid, smallint) from public, anon, authenticated;
revoke all on function public.maskan_password_reset_member(uuid, uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.maskan_password_lookup_network(uuid, text) to service_role;
grant execute on function public.maskan_password_lookup_member(text, text, uuid) to service_role;
grant execute on function public.maskan_password_upgrade_network(uuid, text, text) to service_role;
grant execute on function public.maskan_password_upgrade_member(uuid, text, text) to service_role;
grant execute on function public.maskan_password_create_network(uuid, uuid, uuid, text, text, text, text, text, text) to service_role;
grant execute on function public.maskan_password_join_network(uuid, uuid, uuid, text, text, text) to service_role;
grant execute on function public.maskan_password_find_auth_user(text) to service_role;
grant execute on function public.maskan_password_issue_claim(uuid, uuid, text) to service_role;
grant execute on function public.maskan_password_reset_context(uuid, uuid, uuid, uuid) to service_role;
grant execute on function public.maskan_password_mark_auth_synced(uuid, smallint) to service_role;
grant execute on function public.maskan_password_reset_member(uuid, uuid, uuid, uuid, text) to service_role;

revoke all on function public.maskan_claim_member(uuid, text) from public, anon;
grant execute on function public.maskan_claim_member(uuid, text) to authenticated;
