import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense_network.dart';
import '../models/member.dart';
import '../models/network_notification.dart';
import '../utils/currency_utils.dart';
import '../utils/password_hash_utils.dart';
import 'expense_network_repository.dart';

class SupabaseExpenseNetworkRepository implements ExpenseNetworkRepository {
  SupabaseExpenseNetworkRepository({
    required SupabaseClient client,
  }) : _client = client;

  SupabaseExpenseNetworkRepository.active()
      : _client = Supabase.instance.client;

  const SupabaseExpenseNetworkRepository.test() : _client = null;

  final SupabaseClient? _client;

  static const phaseNotImplementedCode = 'supabase_phase_not_implemented';

  @override
  Future<List<ExpenseNetwork>> getNetworks() async {
    try {
      final client = _requireClient();
      final rows = await client
          .from('networks')
          .select()
          .order('created_at', ascending: false);

      final networks = <ExpenseNetwork>[];
      for (final row in rows) {
        final networkRow = Map<String, dynamic>.from(row as Map);
        final members = await _loadMemberRows(networkRow['id'] as String);
        networks.add(networkFromRows(networkRow, members));
      }
      return networks;
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_networks_load_failed',
        fallbackMessage: 'Cloud networks could not be loaded.',
      );
    }
  }

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async {
    try {
      final client = _requireClient();
      final row = await client
          .from('networks')
          .select()
          .eq('normalized_name', normalizeName(networkName))
          .maybeSingle();

      if (row == null) return null;
      final networkRow = Map<String, dynamic>.from(row);
      final members = await _loadMemberRows(networkRow['id'] as String);
      return networkFromRows(networkRow, members);
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_network_load_failed',
        fallbackMessage: 'Cloud network could not be loaded.',
      );
    }
  }

  @override
  Future<Member?> findMember({
    required String networkName,
    required String memberId,
  }) async {
    final network = await findNetwork(networkName);
    return network?.findMemberById(memberId);
  }

  @override
  Future<Member?> getMemberHistory({
    required String networkName,
    required String memberId,
  }) {
    return findMember(networkName: networkName, memberId: memberId);
  }

  @override
  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    required String currencyCode,
  }) async {
    final trimmedNetworkName = networkName.trim();
    final normalizedNetworkName = normalizeName(trimmedNetworkName);
    final trimmedMemberName = displayName.trim();
    final currency = CurrencyCatalog.findByCode(currencyCode);
    final networkSalt = PasswordHashUtils.createSalt(trimmedNetworkName);
    final memberSalt = PasswordHashUtils.createSalt(trimmedMemberName);

    try {
      final client = _requireClient();
      final networkRow = await client
          .from('networks')
          .insert({
            'name': trimmedNetworkName,
            'normalized_name': normalizedNetworkName,
            'network_password_hash': PasswordHashUtils.createHash(
              password,
              networkSalt,
            ),
            'network_password_salt': networkSalt,
            'currency_code': currency.code,
            'currency_symbol': currency.symbol,
          })
          .select()
          .single();

      final networkId = networkRow['id'] as String;
      final memberRow = await client
          .from('network_members')
          .insert({
            'network_id': networkId,
            'name': trimmedMemberName,
            'normalized_name': normalizeName(trimmedMemberName),
            'password_hash': PasswordHashUtils.createHash(
              memberPassword,
              memberSalt,
            ),
            'password_salt': memberSalt,
          })
          .select()
          .single();

      final updatedNetworkRow = await client
          .from('networks')
          .update({'created_by_member_id': memberRow['id']})
          .eq('id', networkId)
          .select()
          .single();

      return networkFromRows(
        Map<String, dynamic>.from(updatedNetworkRow),
        [Map<String, dynamic>.from(memberRow)],
      );
    } catch (error) {
      throw mapSupabaseError(
        error,
        duplicateCode: 'duplicate_network',
        duplicateMessage: 'A network with this name already exists.',
        fallbackCode: 'supabase_create_network_failed',
        fallbackMessage: 'Cloud network could not be created.',
      );
    }
  }

  @override
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
  }) async {
    final networkRow = await _loadNetworkRowByName(networkName);
    if (networkRow == null) {
      throw const RepositoryException(
        'Network name or password is incorrect.',
        code: 'network_invalid_credentials',
      );
    }

    _verifyNetworkPassword(networkRow, password);

    final networkId = networkRow['id'] as String;
    final trimmedMemberName = displayName.trim();
    final memberSalt = PasswordHashUtils.createSalt(trimmedMemberName);

    try {
      final client = _requireClient();
      await client.from('network_members').insert({
        'network_id': networkId,
        'name': trimmedMemberName,
        'normalized_name': normalizeName(trimmedMemberName),
        'password_hash': PasswordHashUtils.createHash(
          memberPassword,
          memberSalt,
        ),
        'password_salt': memberSalt,
      });

      final members = await _loadMemberRows(networkId);
      return networkFromRows(networkRow, members);
    } catch (error) {
      throw mapSupabaseError(
        error,
        duplicateCode: 'duplicate_member',
        duplicateMessage: 'This member name is already used in the network.',
        fallbackCode: 'supabase_join_network_failed',
        fallbackMessage: 'Cloud network could not be joined.',
      );
    }
  }

  @override
  Future<ExpenseNetwork> authenticateMember({
    required String networkName,
    required String memberName,
    required String memberPassword,
  }) async {
    final networkRow = await _loadNetworkRowByName(networkName);
    if (networkRow == null) {
      throw const RepositoryException(
        'Network not found.',
        code: 'network_not_found',
      );
    }

    final members = await _loadMemberRows(networkRow['id'] as String);
    final normalizedMemberName = normalizeName(memberName);
    final memberRow = members.where(
      (member) => member['normalized_name'] == normalizedMemberName,
    );
    if (memberRow.isEmpty) {
      throw const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      );
    }

    final member = memberFromRow(memberRow.first);
    if (!member.hasPassword) {
      throw const RepositoryException(
        'This member has no cloud password yet.',
        code: 'member_password_missing',
      );
    }

    final isValid = PasswordHashUtils.matches(
      password: memberPassword,
      salt: member.passwordSalt!,
      passwordHash: member.passwordHash!,
    );
    if (!isValid) {
      throw const RepositoryException(
        'Member password is incorrect.',
        code: 'member_invalid_password',
      );
    }

    return networkFromRows(networkRow, members);
  }

  @override
  Future<void> saveNetwork(ExpenseNetwork network) {
    return _phaseNotImplemented();
  }

  @override
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    String? note,
  }) {
    return _phaseNotImplemented();
  }

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) {
    return _phaseNotImplemented();
  }

  @override
  Future<void> markNotificationRead(String notificationId) {
    return _phaseNotImplemented();
  }

  @override
  Future<void> markAllNotificationsRead({
    required String networkId,
    required String memberId,
  }) {
    return _phaseNotImplemented();
  }

  Future<T> _phaseNotImplemented<T>() async {
    throw const RepositoryException(
      'This Supabase feature is planned for a later phase.',
      code: phaseNotImplementedCode,
    );
  }

  Future<Map<String, dynamic>?> _loadNetworkRowByName(String networkName) async {
    try {
      final client = _requireClient();
      final row = await client
          .from('networks')
          .select()
          .eq('normalized_name', normalizeName(networkName))
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_network_load_failed',
        fallbackMessage: 'Cloud network could not be loaded.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadMemberRows(String networkId) async {
    try {
      final client = _requireClient();
      final rows = await client
          .from('network_members')
          .select()
          .eq('network_id', networkId)
          .order('created_at');
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_members_load_failed',
        fallbackMessage: 'Cloud members could not be loaded.',
      );
    }
  }

  void _verifyNetworkPassword(
    Map<String, dynamic> networkRow,
    String password,
  ) {
    final passwordHash = networkRow['network_password_hash'] as String?;
    final passwordSalt = networkRow['network_password_salt'] as String?;
    final isValid = passwordHash != null &&
        passwordSalt != null &&
        PasswordHashUtils.matches(
          password: password,
          salt: passwordSalt,
          passwordHash: passwordHash,
        );

    if (!isValid) {
      throw const RepositoryException(
        'Network name or password is incorrect.',
        code: 'network_invalid_credentials',
      );
    }
  }

  static String normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const RepositoryException(
        'Supabase client is not initialized.',
        code: 'supabase_not_initialized',
      );
    }
    return client;
  }

  static ExpenseNetwork networkFromRows(
    Map<String, dynamic> networkRow,
    List<Map<String, dynamic>> memberRows,
  ) {
    final currency = CurrencyCatalog.findByCode(
      networkRow['currency_code'] as String?,
    );
    final currencySymbol = networkRow['currency_symbol'] as String?;

    return ExpenseNetwork(
      id: networkRow['id'] as String,
      name: networkRow['name'] as String,
      password: networkRow['network_password_hash'] as String? ?? '',
      members: memberRows.map(memberFromRow).toList(),
      createdAt: _parseTimestamp(networkRow['created_at']),
      currencyCode: currency.code,
      currencySymbol: currencySymbol?.trim().isNotEmpty == true
          ? currencySymbol!.trim()
          : currency.symbol,
    );
  }

  static Member memberFromRow(Map<String, dynamic> row) {
    return Member(
      id: row['id'] as String,
      name: row['name'] as String,
      passwordHash: row['password_hash'] as String?,
      passwordSalt: row['password_salt'] as String?,
      createdAt: _parseTimestamp(row['created_at']),
    );
  }

  static RepositoryException mapSupabaseError(
    Object error, {
    String? duplicateCode,
    String? duplicateMessage,
    required String fallbackCode,
    required String fallbackMessage,
  }) {
    final message = error.toString().toLowerCase();
    final isDuplicate = message.contains('23505') ||
        message.contains('duplicate key') ||
        message.contains('unique constraint');
    if (isDuplicate && duplicateCode != null && duplicateMessage != null) {
      return RepositoryException(duplicateMessage, code: duplicateCode);
    }

    if (error is RepositoryException) return error;
    return RepositoryException(fallbackMessage, code: fallbackCode);
  }

  static DateTime _parseTimestamp(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
