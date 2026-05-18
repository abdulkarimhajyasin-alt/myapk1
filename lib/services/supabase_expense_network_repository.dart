import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense.dart';
import '../models/expense_cycle.dart';
import '../models/expense_network.dart';
import '../models/expense_reset_request.dart';
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
  static const maxExpenseNoteLength = 200;
  static const maxNotificationNoteSnippetLength = 80;

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
        networks.add(await _networkFromHydratedRow(networkRow));
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
      final updatedNetworkRow = await _loadNetworkRowById(networkId);
      return _networkFromHydratedRow(updatedNetworkRow ?? networkRow);
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
  }) async {
    try {
      final networkRow = await _loadNetworkRowByName(networkName);
      if (networkRow == null) return null;

      final members = await _loadMemberRows(networkRow['id'] as String);
      final matches = members.where((member) => member['id'] == memberId);
      if (matches.isEmpty) return null;

      final expenses = await _loadMemberExpenseRows(memberId);
      return memberFromRow(matches.first).copyWith(
        expenses: expenses.map(expenseFromRow).toList(),
      );
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_member_history_load_failed',
        fallbackMessage: 'Cloud member history could not be loaded.',
      );
    }
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

      await client.from('expense_cycles').insert({
        'network_id': networkId,
        'cycle_number': 1,
        'status': 'active',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });

      return _networkFromHydratedRow(
        Map<String, dynamic>.from(updatedNetworkRow),
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
    String? networkId,
  }) async {
    final networkRow = networkId?.trim().isNotEmpty == true
        ? await _loadNetworkRowById(networkId!.trim())
        : await _loadNetworkRowByName(networkName);
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

      return _networkFromHydratedRow(networkRow);
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

    return _networkFromHydratedRow(networkRow);
  }

  @override
  Future<void> saveNetwork(ExpenseNetwork network) async {
    try {
      final client = _requireClient();
      await client
          .from('networks')
          .update({
            'name': network.name.trim(),
            'normalized_name': normalizeName(network.name),
            'currency_code': network.currencyCode,
            'currency_symbol': network.currencySymbol,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', network.id);
    } catch (error) {
      throw mapSupabaseError(
        error,
        duplicateCode: 'duplicate_network',
        duplicateMessage: 'A network with this name already exists.',
        fallbackCode: 'supabase_save_network_failed',
        fallbackMessage: 'Cloud network could not be saved.',
      );
    }
  }

  @override
  Future<Member> updateMemberProfile({
    required String networkName,
    required String memberId,
    String? avatarColor,
    String? avatarInitials,
    String? avatarImagePath,
    String? avatarImageUrl,
  }) async {
    try {
      final client = _requireClient();
      final payload = <String, dynamic>{
        if (avatarColor != null) 'avatar_color': avatarColor,
        if (avatarInitials != null) 'avatar_initials': avatarInitials,
        if (avatarImagePath != null) 'avatar_image_path': avatarImagePath,
        if (avatarImageUrl != null) 'avatar_image_url': avatarImageUrl,
      };
      if (payload.isEmpty) {
        final member = await findMember(
          networkName: networkName,
          memberId: memberId,
        );
        if (member == null) {
          throw const RepositoryException('Member not found.');
        }
        return member;
      }
      final row = await client
          .from('network_members')
          .update(payload)
          .eq('id', memberId)
          .select()
          .single();
      return memberFromRow(Map<String, dynamic>.from(row));
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_member_profile_update_failed',
        fallbackMessage: 'Cloud member profile could not be updated.',
      );
    }
  }

  @override
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    String? note,
    String? clientGeneratedId,
  }) async {
    if (amountCents <= 0) {
      throw const RepositoryException(
        'Expense amount must be greater than zero.',
        code: 'invalid_amount',
      );
    }

    final networkRow = await _loadNetworkRowByName(networkName);
    if (networkRow == null) {
      throw const RepositoryException(
        'Network not found.',
        code: 'network_not_found',
      );
    }

    final networkId = networkRow['id'] as String;
    final members = await _loadMemberRows(networkId);
    final actorRows = members.where((member) => member['id'] == addedByMemberId);
    if (actorRows.isEmpty) {
      throw const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      );
    }

    final normalizedPayerName = normalizeName(memberName);
    final payerRows = members.where(
      (member) => member['normalized_name'] == normalizedPayerName,
    );
    if (payerRows.isEmpty) {
      throw const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      );
    }

    final actor = memberFromRow(actorRows.first);
    final payer = memberFromRow(payerRows.first);
    final cleanedNote = sanitizeExpenseNote(note);
    final cycle = await _ensureActiveCycle(networkId);

    try {
      final client = _requireClient();
      final expenseRow = await client
          .from('expenses')
          .insert(
            buildExpenseInsertPayload(
              networkId: networkId,
              paidByMemberId: payer.id,
              paidByMemberName: payer.name,
              addedByMemberId: actor.id,
              addedByMemberName: actor.name,
              amountCents: amountCents,
              note: cleanedNote,
              cycleId: cycle.id,
              clientGeneratedId: clientGeneratedId,
            ),
          )
          .select()
          .single();

      await _createExpenseNotificationsSafely(
        networkId: networkId,
        members: members.map(memberFromRow).toList(),
        actor: actor,
        expenseId: expenseRow['id'] as String,
        amountCents: amountCents,
        currencySymbol: networkRow['currency_symbol'] as String? ?? r'$',
        note: cleanedNote,
      );

      return _networkFromHydratedRow(networkRow);
    } catch (error) {
      throw mapSupabaseError(
        error,
        duplicateCode: 'duplicate_expense_operation',
        duplicateMessage: 'This expense was already synced.',
        fallbackCode: 'supabase_add_expense_failed',
        fallbackMessage: 'Cloud expense could not be added.',
      );
    }
  }

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async {
    try {
      final client = _requireClient();
      final rows = await client
          .from('network_notifications')
          .select()
          .eq('network_id', networkId)
          .eq('recipient_member_id', memberId)
          .order('created_at', ascending: false);
      return rows
          .map(
            (row) => notificationFromRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_notifications_load_failed',
        fallbackMessage: 'Cloud notifications could not be loaded.',
      );
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      final client = _requireClient();
      await client
          .from('network_notifications')
          .delete()
          .eq('id', notificationId);
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_notification_delete_failed',
        fallbackMessage: 'Cloud notification could not be removed.',
      );
    }
  }

  @override
  Future<void> clearNotificationsForMember({
    required String networkId,
    required String memberId,
  }) async {
    try {
      final client = _requireClient();
      await client
          .from('network_notifications')
          .delete()
          .eq('network_id', networkId)
          .eq('recipient_member_id', memberId);
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_notifications_clear_failed',
        fallbackMessage: 'Cloud notifications could not be removed.',
      );
    }
  }

  @override
  Future<ExpenseResetRequest?> getActiveResetRequest({
    required String networkId,
  }) async {
    try {
      final requests = await _loadResetRequests(networkId);
      final pending = requests.where((request) => request.isPending);
      return pending.isEmpty ? null : pending.last;
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_reset_request_load_failed',
        fallbackMessage: 'Cloud reset request could not be loaded.',
      );
    }
  }

  @override
  Future<ExpenseNetwork> createResetRequest({
    required String networkName,
    required String requestedByMemberId,
  }) async {
    final networkRow = await _loadNetworkRowByName(networkName);
    if (networkRow == null) {
      throw const RepositoryException(
        'Network not found.',
        code: 'network_not_found',
      );
    }
    final networkId = networkRow['id'] as String;
    final members = await _loadMemberRows(networkId);
    final requesterRows = members.where(
      (member) => member['id'] == requestedByMemberId,
    );
    if (requesterRows.isEmpty) {
      throw const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      );
    }
    final existing = await getActiveResetRequest(networkId: networkId);
    if (existing != null) {
      throw const RepositoryException(
        'A reset request is already pending.',
        code: 'reset_request_already_pending',
      );
    }

    final requester = memberFromRow(requesterRows.first);
    final cycle = await _ensureActiveCycle(networkId);
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      final client = _requireClient();
      final requestRow = await client
          .from('expense_reset_requests')
          .insert({
            'network_id': networkId,
            'cycle_id': cycle.id,
            'requested_by_member_id': requester.id,
            'requested_by_member_name': requester.name,
            'status': 'pending',
            'required_member_ids':
                members.map((member) => member['id'] as String).toList(),
            'required_member_names':
                members.map((member) => member['name'] as String).toList(),
            'created_at': now,
          })
          .select()
          .single();
      final resetRequestId = requestRow['id'] as String;
      await client.from('expense_reset_approvals').insert({
        'reset_request_id': resetRequestId,
        'network_id': networkId,
        'member_id': requester.id,
        'member_name': requester.name,
        'approved_at': now,
      });
      await client
          .from('expense_cycles')
          .update({
            'status': 'pending_reset',
            'requested_by_member_id': requester.id,
            'requested_by_member_name': requester.name,
          })
          .eq('id', cycle.id);
      await _createResetNotificationsSafely(
        networkId: networkId,
        members: members.map(memberFromRow).toList(),
        requester: requester,
        resetRequestId: resetRequestId,
        currencySymbol: networkRow['currency_symbol'] as String? ?? r'$',
      );
      final completed = await _completeResetIfReady(
        networkId: networkId,
        resetRequestId: resetRequestId,
      );
      if (completed) {
        await _createCycleStartedNotificationsSafely(
          networkId: networkId,
          members: members.map(memberFromRow).toList(),
          resetRequestId: resetRequestId,
          currencySymbol: networkRow['currency_symbol'] as String? ?? r'$',
          actorMemberName: networkRow['name'] as String,
        );
      }
      return _networkFromHydratedRow(networkRow);
    } catch (error) {
      throw mapSupabaseError(
        error,
        duplicateCode: 'reset_request_already_pending',
        duplicateMessage: 'A reset request is already pending.',
        fallbackCode: 'supabase_reset_request_create_failed',
        fallbackMessage: 'Cloud reset request could not be created.',
      );
    }
  }

  @override
  Future<ExpenseNetwork> approveResetRequest({
    required String networkName,
    required String resetRequestId,
    required String memberId,
  }) async {
    final networkRow = await _loadNetworkRowByName(networkName);
    if (networkRow == null) {
      throw const RepositoryException(
        'Network not found.',
        code: 'network_not_found',
      );
    }
    final networkId = networkRow['id'] as String;
    final members = await _loadMemberRows(networkId);
    final memberRows = members.where((member) => member['id'] == memberId);
    if (memberRows.isEmpty) {
      throw const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      );
    }

    final member = memberFromRow(memberRows.first);
    try {
      final client = _requireClient();
      final requests = await _loadResetRequests(networkId);
      final requestRows = requests.where(
        (request) => request.id == resetRequestId,
      );
      if (requestRows.isEmpty || !requestRows.first.isPending) {
        throw const RepositoryException(
          'Reset request is not pending.',
          code: 'reset_request_not_pending',
        );
      }
      if (!requestRows.first.requiredMemberIds.contains(member.id)) {
        throw const RepositoryException(
          'This member is not required for this reset request.',
          code: 'reset_approval_not_required',
        );
      }
      await client.from('expense_reset_approvals').upsert(
        {
          'reset_request_id': resetRequestId,
          'network_id': networkId,
          'member_id': member.id,
          'member_name': member.name,
          'approved_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'reset_request_id,member_id',
      );
      final completed = await _completeResetIfReady(
        networkId: networkId,
        resetRequestId: resetRequestId,
      );
      if (completed) {
        await _createCycleStartedNotificationsSafely(
          networkId: networkId,
          members: members.map(memberFromRow).toList(),
          resetRequestId: resetRequestId,
          currencySymbol: networkRow['currency_symbol'] as String? ?? r'$',
          actorMemberName: networkRow['name'] as String,
        );
      }
      return _networkFromHydratedRow(networkRow);
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_reset_approval_failed',
        fallbackMessage: 'Cloud reset approval could not be saved.',
      );
    }
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

  Future<Map<String, dynamic>?> _loadNetworkRowById(String networkId) async {
    try {
      final client = _requireClient();
      final row = await client
          .from('networks')
          .select()
          .eq('id', networkId)
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

  Future<List<Map<String, dynamic>>> _loadExpenseRows(String networkId) async {
    try {
      final client = _requireClient();
      final rows = await client
          .from('expenses')
          .select()
          .eq('network_id', networkId)
          .order('created_at');
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_expenses_load_failed',
        fallbackMessage: 'Cloud expenses could not be loaded.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadMemberExpenseRows(
    String memberId,
  ) async {
    try {
      final client = _requireClient();
      final rows = await client
          .from('expenses')
          .select()
          .eq('paid_by_member_id', memberId)
          .order('created_at');
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_member_expenses_load_failed',
        fallbackMessage: 'Cloud member expenses could not be loaded.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadCycleRows(String networkId) async {
    try {
      final client = _requireClient();
      final rows = await client
          .from('expense_cycles')
          .select()
          .eq('network_id', networkId)
          .order('cycle_number');
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (error) {
      throw mapSupabaseError(
        error,
        fallbackCode: 'supabase_cycles_load_failed',
        fallbackMessage: 'Cloud expense cycles could not be loaded.',
      );
    }
  }

  Future<List<ExpenseResetRequest>> _loadResetRequests(String networkId) async {
    final client = _requireClient();
    final rows = await client
        .from('expense_reset_requests')
        .select()
        .eq('network_id', networkId)
        .order('created_at');
    final approvalRows = await client
        .from('expense_reset_approvals')
        .select()
        .eq('network_id', networkId)
        .order('approved_at');
    final approvals = approvalRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    return rows.map((row) {
      final requestRow = Map<String, dynamic>.from(row as Map);
      return resetRequestFromRows(
        requestRow,
        approvals
            .where(
              (approval) => approval['reset_request_id'] == requestRow['id'],
            )
            .toList(),
      );
    }).toList();
  }

  Future<ExpenseNetwork> _networkFromHydratedRow(
    Map<String, dynamic> networkRow,
  ) async {
    final networkId = networkRow['id'] as String;
    final members = await _loadMemberRows(networkId);
    final expenses = await _loadExpenseRows(networkId);
    final cycles = await _loadCycleRows(networkId);
    final resetRequests = await _loadResetRequests(networkId);
    return networkFromRows(
      networkRow,
      members,
      expenseRows: expenses,
      cycleRows: cycles,
      resetRequests: resetRequests,
    );
  }

  Future<void> _createExpenseNotificationsSafely({
    required String networkId,
    required List<Member> members,
    required Member actor,
    required String expenseId,
    required int amountCents,
    required String currencySymbol,
    String? note,
  }) async {
    final payloads = buildNotificationInsertPayloads(
      networkId: networkId,
      members: members,
      actor: actor,
      expenseId: expenseId,
      amountCents: amountCents,
      currencySymbol: currencySymbol,
      note: note,
    );
    if (payloads.isEmpty) return;

    try {
      final client = _requireClient();
      await client.from('network_notifications').insert(payloads);
    } catch (_) {
      // Notification delivery is best-effort. The expense row is the source of
      // truth and must remain saved even if notification fan-out is incomplete.
    }
  }

  Future<void> _createResetNotificationsSafely({
    required String networkId,
    required List<Member> members,
    required Member requester,
    required String resetRequestId,
    required String currencySymbol,
  }) async {
    final payloads = buildResetNotificationInsertPayloads(
      networkId: networkId,
      members: members,
      requester: requester,
      resetRequestId: resetRequestId,
      currencySymbol: currencySymbol,
    );
    if (payloads.isEmpty) return;

    try {
      final client = _requireClient();
      await client.from('network_notifications').insert(payloads);
    } catch (_) {}
  }

  Future<void> _createCycleStartedNotificationsSafely({
    required String networkId,
    required List<Member> members,
    required String resetRequestId,
    required String currencySymbol,
    required String actorMemberName,
  }) async {
    final payloads = buildCycleStartedNotificationInsertPayloads(
      networkId: networkId,
      members: members,
      resetRequestId: resetRequestId,
      currencySymbol: currencySymbol,
      actorMemberName: actorMemberName,
    );
    if (payloads.isEmpty) return;

    try {
      final client = _requireClient();
      await client.from('network_notifications').insert(payloads);
    } catch (_) {}
  }

  Future<ExpenseCycle> _ensureActiveCycle(String networkId) async {
    final cycles = await _loadCycleRows(networkId);
    final activeRows = cycles.where(
      (row) => row['status'] == 'active' || row['status'] == 'pending_reset',
    );
    if (activeRows.isNotEmpty) return cycleFromRow(activeRows.last);

    final client = _requireClient();
    final row = await client
        .from('expense_cycles')
        .insert({
          'network_id': networkId,
          'cycle_number': cycles.length + 1,
          'status': 'active',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return cycleFromRow(Map<String, dynamic>.from(row));
  }

  Future<bool> _completeResetIfReady({
    required String networkId,
    required String resetRequestId,
  }) async {
    final requests = await _loadResetRequests(networkId);
    final matches = requests.where((request) => request.id == resetRequestId);
    if (matches.isEmpty) return false;
    final request = matches.first;
    if (!request.isPending || !request.hasUnanimousApproval) return false;

    final client = _requireClient();
    final now = DateTime.now().toUtc().toIso8601String();
    await client
        .from('expenses')
        .update({
          'cycle_id': request.cycleId,
          'archived_at': now,
        })
        .eq('network_id', networkId)
        .or('cycle_id.eq.${request.cycleId},cycle_id.is.null')
        .filter('archived_at', 'is', null);
    await client
        .from('expense_cycles')
        .update({'status': 'closed', 'closed_at': now})
        .eq('id', request.cycleId);
    await client.from('expense_cycles').insert({
      'network_id': networkId,
      'cycle_number': (await _loadCycleRows(networkId)).length + 1,
      'status': 'active',
      'started_at': now,
    });
    await client
        .from('expense_reset_requests')
        .update({'status': 'completed', 'completed_at': now})
        .eq('id', resetRequestId);
    return true;
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
    {
    List<Map<String, dynamic>> expenseRows = const [],
    List<Map<String, dynamic>> cycleRows = const [],
    List<ExpenseResetRequest> resetRequests = const [],
  }) {
    final currency = CurrencyCatalog.findByCode(
      networkRow['currency_code'] as String?,
    );
    final currencySymbol = networkRow['currency_symbol'] as String?;
    final expensesByMemberId = <String, List<Expense>>{};
    for (final expenseRow in expenseRows) {
      final memberId = expenseRow['paid_by_member_id'] as String?;
      if (memberId == null) continue;
      expensesByMemberId
          .putIfAbsent(memberId, () => <Expense>[])
          .add(expenseFromRow(expenseRow));
    }

    return ExpenseNetwork(
      id: networkRow['id'] as String,
      name: networkRow['name'] as String,
      password: networkRow['network_password_hash'] as String? ?? '',
      members: memberRows.map((row) {
        final member = memberFromRow(row);
        return member.copyWith(expenses: expensesByMemberId[member.id] ?? []);
      }).toList(),
      createdAt: _parseTimestamp(networkRow['created_at']),
      currencyCode: currency.code,
      currencySymbol: currencySymbol?.trim().isNotEmpty == true
          ? currencySymbol!.trim()
          : currency.symbol,
      cycles: cycleRows.map(cycleFromRow).toList(),
      resetRequests: resetRequests,
    );
  }

  static Member memberFromRow(Map<String, dynamic> row) {
    return Member(
      id: row['id'] as String,
      name: row['name'] as String,
      passwordHash: row['password_hash'] as String?,
      passwordSalt: row['password_salt'] as String?,
      createdAt: _parseTimestamp(row['created_at']),
      avatarColor: row['avatar_color'] as String?,
      avatarInitials: row['avatar_initials'] as String?,
      avatarImagePath: row['avatar_image_path'] as String?,
      avatarImageUrl: row['avatar_image_url'] as String?,
    );
  }

  static Expense expenseFromRow(Map<String, dynamic> row) {
    return Expense(
      id: row['id'] as String?,
      amountCents: _parseInt(row['amount_cents']),
      note: _emptyToNull(row['note'] as String?),
      createdAt: _parseTimestamp(row['created_at']),
      addedByMemberId: row['added_by_member_id'] as String? ?? '',
      addedByMemberName: row['added_by_member_name'] as String? ?? '',
      cycleId: row['cycle_id'] as String?,
      archivedAt: _parseNullableTimestamp(row['archived_at']),
      clientGeneratedId: row['client_generated_id'] as String?,
    );
  }

  static ExpenseCycle cycleFromRow(Map<String, dynamic> row) {
    return ExpenseCycle(
      id: row['id'] as String?,
      networkId: row['network_id'] as String,
      cycleNumber: _parseInt(row['cycle_number']),
      startedAt: _parseTimestamp(row['started_at']),
      closedAt: _parseNullableTimestamp(row['closed_at']),
      status: _cycleStatusFromDb(row['status'] as String?),
      requestedByMemberId: row['requested_by_member_id'] as String?,
      requestedByMemberName: row['requested_by_member_name'] as String?,
    );
  }

  static ExpenseResetRequest resetRequestFromRows(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> approvalRows,
  ) {
    return ExpenseResetRequest(
      id: row['id'] as String?,
      networkId: row['network_id'] as String,
      cycleId: row['cycle_id'] as String,
      requestedByMemberId: row['requested_by_member_id'] as String,
      requestedByMemberName: row['requested_by_member_name'] as String,
      createdAt: _parseTimestamp(row['created_at']),
      requiredMemberIds: _stringList(row['required_member_ids']),
      requiredMemberNames: _stringList(row['required_member_names']),
      status: _resetStatusFromDb(row['status'] as String?),
      completedAt: _parseNullableTimestamp(row['completed_at']),
      approvals: approvalRows.map((approval) {
        return ExpenseResetApproval(
          memberId: approval['member_id'] as String,
          memberName: approval['member_name'] as String,
          approvedAt: _parseTimestamp(approval['approved_at']),
        );
      }).toList(),
    );
  }

  static NetworkNotification notificationFromRow(Map<String, dynamic> row) {
    return NetworkNotification(
      id: row['id'] as String?,
      networkId: row['network_id'] as String,
      recipientMemberId: row['recipient_member_id'] as String,
      actorMemberName: row['actor_member_name'] as String,
      expenseAmountCents: _parseInt(row['amount_cents']),
      currencySymbol: row['currency_symbol'] as String? ?? r'$',
      noteSnippet: _emptyToNull(row['note_snippet'] as String?),
      kind: NetworkNotificationKind.fromName(row['kind'] as String?),
      resetRequestId: row['reset_request_id'] as String?,
      createdAt: _parseTimestamp(row['created_at']),
      isRead: row['is_read'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> buildExpenseInsertPayload({
    required String networkId,
    required String paidByMemberId,
    required String paidByMemberName,
    required String addedByMemberId,
    required String addedByMemberName,
    required int amountCents,
    String? note,
    String? cycleId,
    String? clientGeneratedId,
  }) {
    return {
      'network_id': networkId,
      'paid_by_member_id': paidByMemberId,
      'paid_by_member_name': paidByMemberName,
      'added_by_member_id': addedByMemberId,
      'added_by_member_name': addedByMemberName,
      'amount_cents': amountCents,
      'note': sanitizeExpenseNote(note),
      'cycle_id': cycleId,
      'client_generated_id': clientGeneratedId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static List<Map<String, dynamic>> buildNotificationInsertPayloads({
    required String networkId,
    required List<Member> members,
    required Member actor,
    required String expenseId,
    required int amountCents,
    required String currencySymbol,
    String? note,
  }) {
    final snippet = _noteSnippet(note);
    return members
        .where((member) => member.id != actor.id)
        .map(
          (member) => {
            'network_id': networkId,
            'recipient_member_id': member.id,
            'actor_member_id': actor.id,
            'actor_member_name': actor.name,
            'expense_id': expenseId,
            'amount_cents': amountCents,
            'currency_symbol': currencySymbol,
            'note_snippet': snippet,
            'kind': NetworkNotificationKind.expense.name,
            'reset_request_id': null,
            'is_read': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> buildResetNotificationInsertPayloads({
    required String networkId,
    required List<Member> members,
    required Member requester,
    required String resetRequestId,
    required String currencySymbol,
  }) {
    return members
        .where((member) => member.id != requester.id)
        .map(
          (member) => {
            'network_id': networkId,
            'recipient_member_id': member.id,
            'actor_member_id': requester.id,
            'actor_member_name': requester.name,
            'expense_id': null,
            'amount_cents': 0,
            'currency_symbol': currencySymbol,
            'note_snippet': null,
            'kind': NetworkNotificationKind.resetRequest.name,
            'reset_request_id': resetRequestId,
            'is_read': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();
  }

  static List<Map<String, dynamic>> buildCycleStartedNotificationInsertPayloads({
    required String networkId,
    required List<Member> members,
    required String resetRequestId,
    required String currencySymbol,
    required String actorMemberName,
  }) {
    return members
        .map(
          (member) => {
            'network_id': networkId,
            'recipient_member_id': member.id,
            'actor_member_id': null,
            'actor_member_name': actorMemberName,
            'expense_id': null,
            'amount_cents': 0,
            'currency_symbol': currencySymbol,
            'note_snippet': null,
            'kind': NetworkNotificationKind.cycleStarted.name,
            'reset_request_id': resetRequestId,
            'is_read': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();
  }

  static String? sanitizeExpenseNote(String? note) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length <= maxExpenseNoteLength) return trimmed;
    return trimmed.substring(0, maxExpenseNoteLength);
  }

  static RepositoryException mapSupabaseError(
    Object error, {
    String? duplicateCode,
    String? duplicateMessage,
    required String fallbackCode,
    required String fallbackMessage,
  }) {
    final message = error.toString().toLowerCase();
    if (error is RepositoryException) return error;

    final isNetworkUnavailable = message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('network request failed') ||
        message.contains('connection refused') ||
        message.contains('connection failed') ||
        message.contains('timed out') ||
        message.contains('os error') ||
        message.contains('clientexception') ||
        message.contains('xmlhttprequest error');
    if (isNetworkUnavailable) {
      return const RepositoryException(
        'Cloud mode needs an internet connection.',
        code: 'supabase_network_unavailable',
      );
    }

    final isDuplicate = message.contains('23505') ||
        message.contains('duplicate key') ||
        message.contains('unique constraint');
    if (isDuplicate && duplicateCode != null && duplicateMessage != null) {
      return RepositoryException(duplicateMessage, code: duplicateCode);
    }

    final isPermission = message.contains('42501') ||
        message.contains('permission denied') ||
        message.contains('row-level security') ||
        message.contains('rls');
    if (isPermission) {
      return const RepositoryException(
        'Cloud permission denied.',
        code: 'supabase_permission_denied',
      );
    }

    final isNotFound = message.contains('pgrst116') ||
        message.contains('not found') ||
        message.contains('0 rows');
    if (isNotFound) {
      return const RepositoryException(
        'Cloud record was not found.',
        code: 'supabase_not_found',
      );
    }

    return RepositoryException(fallbackMessage, code: fallbackCode);
  }

  static DateTime _parseTimestamp(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _parseNullableTimestamp(Object? value) {
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return null;
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _noteSnippet(String? note) {
    final cleaned = sanitizeExpenseNote(note);
    if (cleaned == null) return null;
    if (cleaned.length <= maxNotificationNoteSnippetLength) return cleaned;
    return cleaned.substring(0, maxNotificationNoteSnippetLength);
  }

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((item) => item as String).toList();
    return [];
  }

  static ExpenseCycleStatus _cycleStatusFromDb(String? value) {
    switch (value) {
      case 'pending_reset':
        return ExpenseCycleStatus.pendingReset;
      case 'closed':
        return ExpenseCycleStatus.closed;
      case 'active':
      default:
        return ExpenseCycleStatus.active;
    }
  }

  static ExpenseResetStatus _resetStatusFromDb(String? value) {
    switch (value) {
      case 'completed':
        return ExpenseResetStatus.completed;
      case 'cancelled':
        return ExpenseResetStatus.cancelled;
      case 'pending':
      default:
        return ExpenseResetStatus.pending;
    }
  }
}
