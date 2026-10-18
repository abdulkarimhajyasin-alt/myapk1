import '../supabase/tests/local_only_test_client.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expense_network/services/supabase_expense_network_repository.dart';
import 'package:expense_network/services/expense_network_repository.dart';

void main() {
  final env = Platform.environment;
  test(
      'actual Android repository shares staging group and legacy resets with web',
      () async {
    expect(env['LOCAL_SUPABASE_API_URL'], 'http://127.0.0.1:56321');
    final name = env['MASKAN_STAGING_GROUP']!;
    final password = env['MASKAN_STAGING_PASSWORD']!;
    expect(name, startsWith('staging-shared-'));
    final client = SupabaseClient(
        env['LOCAL_SUPABASE_API_URL']!, env['LOCAL_SUPABASE_ANON_KEY']!,
        httpClient: LocalOnlyTestClient(env['LOCAL_SUPABASE_API_URL']!),
        authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit, autoRefreshToken: false));
    final repo = SupabaseExpenseNetworkRepository(client: client);
    try {
      if (env['MASKAN_STAGING_PHASE'] == 'join') {
        final network = await repo.joinNetwork(
            displayName: 'Android Member',
            networkName: name,
            password: password,
            memberPassword: password);
        final member =
            network.members.singleWhere((m) => m.name == 'Android Member');
        expect(network.totalExpensesCents, 3300);
        final operation = SupabaseExpenseNetworkRepository.createUuid();
        Future<void> add(int amount) async {
          await repo.addExpense(
              networkName: name,
              memberName: member.name,
              addedByMemberId: member.id,
              amountCents: amount,
              note: 'android retained fixture',
              clientGeneratedId: operation);
        }

        await add(700);
        await add(700);
        await expectLater(
            add(701),
            throwsA(isA<RepositoryException>()
                .having((e) => e.code, 'code', 'expense_operation_conflict')));
        var rows = await client
            .from('expenses')
            .select()
            .eq('client_generated_id', operation);
        expect(rows.length, 1);
        final extra = SupabaseExpenseNetworkRepository.createUuid();
        await repo.addExpense(
            networkName: name,
            memberName: member.name,
            addedByMemberId: member.id,
            amountCents: 300,
            note: 'android edit delete fixture',
            clientGeneratedId: extra);
        rows = await client
            .from('expenses')
            .select()
            .eq('client_generated_id', extra);
        await repo.updateExpense(
            networkName: name,
            networkId: network.id,
            expenseId: rows.single['id'],
            editedByMemberId: member.id,
            amountCents: 400,
            note: 'edited by Android');
        await repo.deleteExpense(
            networkName: name,
            networkId: network.id,
            expenseId: rows.single['id'],
            deletedByMemberId: member.id);
        await repo.createResetRequest(
            networkName: name, requestedByMemberId: member.id);
        expect((await repo.findNetwork(name))!.activeResetRequest, isNotNull);
      } else {
        expect(env['MASKAN_STAGING_PHASE'], 'verify');
        final network = await repo.authenticateMember(
            networkName: name,
            memberName: 'Android Member',
            memberPassword: password);
        final member =
            network.members.singleWhere((m) => m.name == 'Android Member');
        expect(network.totalExpensesCents, 0);
        final rows = await client
            .from('expenses')
            .select()
            .eq('added_by_member_id', member.id);
        expect(rows.length, 1);
        expect(rows.single['archived_at'], isNotNull);
        final update = await client
            .from('expenses')
            .update({'amount_cents': 1})
            .eq('id', rows.single['id'])
            .select();
        expect(update, isEmpty);
        final removed = await client
            .from('expenses')
            .delete()
            .eq('id', rows.single['id'])
            .select();
        expect(removed, isEmpty);
        await repo.leaveNetwork(networkId: network.id, memberId: member.id);
        expect(
            await client.from('expenses').select().eq('network_id', network.id),
            isEmpty);
      }
    } finally {
      await client.dispose();
    }
  },
      skip: env['MASKAN_STAGING_GROUP'] == null
          ? 'Requires guarded staging runner'
          : false,
      timeout: const Timeout(Duration(minutes: 2)));
}
