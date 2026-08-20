-- Repeatable Phase 1 isolation test. Run after schema.sql and the Phase 1
-- migration on a disposable local Supabase database. The transaction rolls back.
begin;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase1-a1@example.test', '', now(), '{}', '{}', now(), now()),
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'phase1-b1@example.test', '', now(), '{}', '{}', now(), now());

insert into public.networks (id, name, normalized_name) values
  ('a0000000-0000-0000-0000-000000000000', 'Phase 1 Network A', 'phase 1 network a'),
  ('b0000000-0000-0000-0000-000000000000', 'Phase 1 Network B', 'phase 1 network b');
insert into public.network_members (id, network_id, auth_user_id, name, normalized_name) values
  ('a1000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000',
   '10000000-0000-0000-0000-000000000001', 'A1', 'a1'),
  ('a2000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000',
   null, 'A2', 'a2'),
  ('b1000000-0000-0000-0000-000000000000', 'b0000000-0000-0000-0000-000000000000',
   '20000000-0000-0000-0000-000000000001', 'B1', 'b1');
update public.networks set created_by_member_id =
  case when id = 'a0000000-0000-0000-0000-000000000000'
       then 'a1000000-0000-0000-0000-000000000000'::uuid
       else 'b1000000-0000-0000-0000-000000000000'::uuid end;
insert into public.expenses (
  id, network_id, paid_by_member_id, paid_by_member_name,
  added_by_member_id, added_by_member_name, amount_cents, note
) values
  ('aa000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000000',
   'a1000000-0000-0000-0000-000000000000', 'A1',
   'a1000000-0000-0000-0000-000000000000', 'A1', 100, 'A expense'),
  ('bb000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000000',
   'b1000000-0000-0000-0000-000000000000', 'B1',
   'b1000000-0000-0000-0000-000000000000', 'B1', 200, 'B expense');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare affected integer;
begin
  if (select count(*) from public.maskan_networks) <> 1 then
    raise exception 'A1 network isolation failed';
  end if;
  if (select count(*) from public.maskan_network_members) <> 2 then
    raise exception 'A1 member isolation failed';
  end if;
  if (select count(*) from public.expenses) <> 1 then
    raise exception 'A1 expense/Realtime visibility isolation failed';
  end if;
  if exists (
    select 1 from public.maskan_network_members
    where password_hash is not null or password_salt is not null
  ) then
    raise exception 'Safe member view disclosed credentials';
  end if;
  if has_column_privilege('authenticated', 'public.network_members', 'password_hash', 'SELECT')
     or has_column_privilege('authenticated', 'public.network_members', 'password_salt', 'SELECT') then
    raise exception 'Authenticated role has sensitive-column SELECT';
  end if;

  insert into public.expenses (
    id, network_id, paid_by_member_id, paid_by_member_name,
    added_by_member_id, added_by_member_name, amount_cents
  ) values (
    'aa000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000000',
    'a1000000-0000-0000-0000-000000000000', 'A1',
    'a1000000-0000-0000-0000-000000000000', 'A1', 300
  );
  update public.expenses set note = 'allowed update'
  where id = 'aa000000-0000-0000-0000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'A1 allowed update failed'; end if;
  delete from public.expenses where id = 'aa000000-0000-0000-0000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'A1 allowed delete failed'; end if;

  begin
    insert into public.expenses (
      id, network_id, paid_by_member_id, paid_by_member_name,
      added_by_member_id, added_by_member_name, amount_cents
    ) values (
      'aa000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000000',
      'a1000000-0000-0000-0000-000000000000', 'A1',
      'a2000000-0000-0000-0000-000000000000', 'A2', 400
    );
    raise exception 'A1 spoofed A2 actor was accepted';
  exception when insufficient_privilege then null; end;

  begin
    insert into public.expenses (
      id, network_id, paid_by_member_id, paid_by_member_name,
      added_by_member_id, added_by_member_name, amount_cents
    ) values (
      'bb000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000000',
      'b1000000-0000-0000-0000-000000000000', 'B1',
      'b1000000-0000-0000-0000-000000000000', 'B1', 500
    );
    raise exception 'A1 cross-network insert was accepted';
  exception when insufficient_privilege then null; end;

  update public.expenses set note = 'cross-network attack'
  where id = 'bb000000-0000-0000-0000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'A1 cross-network update was accepted'; end if;
  delete from public.expenses where id = 'bb000000-0000-0000-0000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'A1 cross-network delete was accepted'; end if;
end $$;

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
do $$
begin
  if (select count(*) from public.maskan_networks) <> 1
     or exists (select 1 from public.maskan_networks where name = 'Phase 1 Network A') then
    raise exception 'B1 inverse network isolation failed';
  end if;
  if (select count(*) from public.maskan_network_members) <> 1
     or (select count(*) from public.expenses) <> 1 then
    raise exception 'B1 inverse member/expense isolation failed';
  end if;
end $$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform count(*) from public.networks;
    raise exception 'anon listed private networks';
  exception when insufficient_privilege then null; end;
  begin
    perform count(*) from public.network_members;
    raise exception 'anon listed members';
  exception when insufficient_privilege then null; end;
  begin
    perform count(*) from public.expenses;
    raise exception 'anon read expenses/Realtime-visible rows';
  exception when insufficient_privilege then null; end;
  if has_column_privilege('anon', 'public.network_members', 'password_hash', 'SELECT')
     or has_column_privilege('anon', 'public.networks', 'network_password_hash', 'SELECT') then
    raise exception 'anon can select credential columns';
  end if;
  if to_regprocedure('public.maskan_discover_networks()') is not null then
    raise exception 'broad network discovery RPC still exists';
  end if;
end $$;

reset role;
rollback;
