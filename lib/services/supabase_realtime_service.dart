import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/network_notification.dart';
import 'supabase_config.dart';
import 'supabase_expense_network_repository.dart';

enum RealtimeConnectionState {
  disabled,
  connecting,
  connected,
  offline,
}

class SupabaseRealtimeService {
  SupabaseRealtimeService({
    SupabaseClient? client,
    SupabaseConfig config = SupabaseConfig.defaultConfig,
    Duration debounceDuration = const Duration(milliseconds: 650),
  })  : _client = client,
        _config = config,
        _debounceDuration = debounceDuration;

  final SupabaseClient? _client;
  final SupabaseConfig _config;
  final Duration _debounceDuration;
  final List<RealtimeChannel> _channels = [];
  Timer? _debounce;
  bool _isDisposed = false;

  bool get canInitialize => _config.shouldUseSupabase || _client != null;

  Future<RealtimeConnectionState> subscribe({
    required String networkId,
    required String memberId,
    required VoidCallback onRefresh,
    required void Function(NetworkNotification notification, String? actorId)
        onNotification,
  }) async {
    if (!canInitialize) return RealtimeConnectionState.disabled;
    final client = _client ?? Supabase.instance.client;
    try {
      _channels
        ..add(
          _networkChannel(
            client: client,
            name: 'maskan-expenses-$networkId',
            table: 'expenses',
            networkId: networkId,
            onRefresh: onRefresh,
          ),
        )
        ..add(
          _networkChannel(
            client: client,
            name: 'maskan-reset-requests-$networkId',
            table: 'expense_reset_requests',
            networkId: networkId,
            onRefresh: onRefresh,
          ),
        )
        ..add(
          _networkChannel(
            client: client,
            name: 'maskan-reset-approvals-$networkId',
            table: 'expense_reset_approvals',
            networkId: networkId,
            onRefresh: onRefresh,
          ),
        )
        ..add(
          _networkChannel(
            client: client,
            name: 'maskan-cycles-$networkId',
            table: 'expense_cycles',
            networkId: networkId,
            onRefresh: onRefresh,
          ),
        )
        ..add(
          _notificationsChannel(
            client: client,
            networkId: networkId,
            memberId: memberId,
            onRefresh: onRefresh,
            onNotification: onNotification,
          ),
        );
      for (final channel in _channels) {
        channel.subscribe();
      }
      return RealtimeConnectionState.connected;
    } catch (_) {
      return RealtimeConnectionState.offline;
    }
  }

  RealtimeChannel _networkChannel({
    required SupabaseClient client,
    required String name,
    required String table,
    required String networkId,
    required VoidCallback onRefresh,
  }) {
    return client.channel(name).onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'network_id',
            value: networkId,
          ),
          callback: (_) => _debounced(onRefresh),
        );
  }

  RealtimeChannel _notificationsChannel({
    required SupabaseClient client,
    required String networkId,
    required String memberId,
    required VoidCallback onRefresh,
    required void Function(NetworkNotification notification, String? actorId)
        onNotification,
  }) {
    return client.channel('maskan-notifications-$networkId-$memberId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'network_notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'recipient_member_id',
        value: memberId,
      ),
      callback: (payload) {
        final record = Map<String, dynamic>.from(payload.newRecord);
        if (record['network_id'] != networkId) return;
        onNotification(
          SupabaseExpenseNetworkRepository.notificationFromRow(record),
          record['actor_member_id'] as String?,
        );
        _debounced(onRefresh);
      },
    );
  }

  void _debounced(VoidCallback callback) {
    if (_isDisposed) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, callback);
  }

  void handleEventForTesting(VoidCallback callback) {
    _debounced(callback);
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _debounce?.cancel();
    final client =
        _client ?? (_config.shouldUseSupabase ? Supabase.instance.client : null);
    if (client != null) {
      for (final channel in _channels) {
        await client.removeChannel(channel);
      }
    }
    _channels.clear();
  }
}

typedef VoidCallback = void Function();
