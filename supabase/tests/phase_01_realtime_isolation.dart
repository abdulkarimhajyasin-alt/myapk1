import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

final apiUrl = Platform.environment['LOCAL_SUPABASE_API_URL'];
final anonKey = Platform.environment['LOCAL_SUPABASE_ANON_KEY'];

class Identity {
  const Identity(this.client, this.memberId, this.networkId);
  final SupabaseClient client;
  final String memberId;
  final String networkId;
}

String uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

Future<Identity> createIdentity(String label, String suffix) async {
  final client = SupabaseClient(
    apiUrl!,
    anonKey!,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  final auth = await client.auth.signUp(
    email: 'phase1c-realtime-$label-$suffix@example.test',
    password: 'Local-Realtime-$label-$suffix',
  );
  if (auth.session == null) {
    throw StateError('Local Auth signup returned no session.');
  }
  final networkId = uuid();
  final memberId = uuid();
  await client.rpc('maskan_create_network', params: {
    'p_network_id': networkId,
    'p_member_id': memberId,
    'p_network_name': 'Realtime $label $suffix',
    'p_member_name': '${label.toUpperCase()}1',
    'p_network_password_hash': 'synthetic-network-hash-$label',
    'p_network_password_salt': 'synthetic-network-salt-$label',
    'p_member_password_hash': 'synthetic-member-hash-$label',
    'p_member_password_salt': 'synthetic-member-salt-$label',
    'p_currency_code': 'EUR',
    'p_currency_symbol': 'EUR',
  });
  return Identity(client, memberId, networkId);
}

Future<({RealtimeChannel channel, List<Map<String, dynamic>> records})>
    subscribe(
  Identity identity,
  String suffix,
) async {
  final records = <Map<String, dynamic>>[];
  final ready = Completer<void>();
  final channel =
      identity.client.channel('phase-01c-$suffix').onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'expenses',
            callback: (payload) => records.add(payload.newRecord),
          );
  channel.subscribe((status, [error]) {
    if (status == RealtimeSubscribeStatus.subscribed && !ready.isCompleted) {
      ready.complete();
    } else if ((status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) &&
        !ready.isCompleted) {
      ready.completeError(StateError('Realtime subscription failed.'));
    }
  });
  await ready.future.timeout(const Duration(seconds: 15));
  return (channel: channel, records: records);
}

Future<void> insertExpense(Identity identity, int amountCents) =>
    identity.client.from('expenses').insert({
      'id': uuid(),
      'network_id': identity.networkId,
      'paid_by_member_id': identity.memberId,
      'paid_by_member_name': 'Synthetic',
      'added_by_member_id': identity.memberId,
      'added_by_member_name': 'Synthetic',
      'amount_cents': amountCents,
    });

Future<void> main() async {
  if (apiUrl == null || anonKey == null) {
    throw StateError('Local Supabase API URL and anon key are required.');
  }
  final suffix = uuid().replaceAll('-', '');
  final identityA = await createIdentity('a', suffix);
  final identityB = await createIdentity('b', suffix);
  final subscriptionA = await subscribe(identityA, 'a-$suffix');
  final subscriptionB = await subscribe(identityB, 'b-$suffix');
  try {
    await insertExpense(identityA, 101);
    await insertExpense(identityB, 202);
    await Future<void>.delayed(const Duration(seconds: 5));
    final aOwn = subscriptionA.records
        .any((r) => r['network_id'] == identityA.networkId);
    final aForeign = subscriptionA.records
        .any((r) => r['network_id'] == identityB.networkId);
    final bOwn = subscriptionB.records
        .any((r) => r['network_id'] == identityB.networkId);
    final bForeign = subscriptionB.records
        .any((r) => r['network_id'] == identityA.networkId);
    if (!aOwn || aForeign || !bOwn || bForeign) {
      throw StateError(
          'Realtime isolation failed (A own=$aOwn, A foreign=$aForeign, B own=$bOwn, B foreign=$bForeign).');
    }
    stdout.writeln('PASS | Realtime A receives A and not B');
    stdout.writeln('PASS | Realtime B receives B and not A');
  } finally {
    await subscriptionA.channel.unsubscribe();
    await subscriptionB.channel.unsubscribe();
    identityA.client.dispose();
    identityB.client.dispose();
  }
}
