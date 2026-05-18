import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_network.dart';
import '../models/expense_cycle.dart';
import '../models/expense_reset_request.dart';
import '../models/member.dart';
import '../models/network_notification.dart';
import '../utils/currency_utils.dart';
import '../utils/id_utils.dart';
import '../utils/password_hash_utils.dart';
import 'expense_network_repository.dart';
import 'shared_preferences_storage_keys.dart';

class SharedPreferencesExpenseNetworkRepository
    implements ExpenseNetworkRepository {
  late final SharedPreferences _preferences;

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  @override
  Future<List<ExpenseNetwork>> getNetworks() async {
    final raw = _preferences.getString(SharedPreferencesStorageKeys.networks);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (network) => ExpenseNetwork.fromJson(
              network as Map<String, dynamic>,
            ),
          )
          .toList();
    } on FormatException catch (_) {
      throw const RepositoryException(
        'Stored network data could not be loaded.',
        code: 'network_data_parse_failed',
      );
    } on TypeError catch (_) {
      throw const RepositoryException(
        'Stored network data could not be loaded.',
        code: 'network_data_parse_failed',
      );
    }
  }

  @override
  Future<ExpenseNetwork?> findNetwork(String networkName) async {
    final networks = await getNetworks();
    return _findByName(networks, networkName);
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
    final networks = await getNetworks();
    if (_findByName(networks, networkName) != null) {
      throw const RepositoryException(
        'A network with this name already exists.',
        code: 'duplicate_network',
      );
    }

    final currency = CurrencyCatalog.findByCode(currencyCode);
    final member = _createMember(
      displayName: displayName,
      memberPassword: memberPassword,
    );
    final network = ExpenseNetwork(
      id: IdUtils.createId('network'),
      name: networkName.trim(),
      password: password.trim(),
      members: [member],
      createdAt: DateTime.now(),
      currencyCode: currency.code,
      currencySymbol: currency.symbol,
    );

    await _saveNetworks([...networks, network]);
    return network;
  }

  @override
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
  }) async {
    final networks = await getNetworks();
    final network = _findByName(networks, networkName);
    if (network == null || network.password != password.trim()) {
      throw const RepositoryException(
        'Network name or password is incorrect.',
        code: 'network_invalid_credentials',
      );
    }

    final memberExists = network.members.any(
      (member) => member.name.toLowerCase() == displayName.trim().toLowerCase(),
    );
    if (memberExists) {
      throw const RepositoryException(
        'This member name is already used in the network.',
        code: 'duplicate_member',
      );
    }

    final member = _createMember(
      displayName: displayName,
      memberPassword: memberPassword,
    );
    final updatedNetwork = network.addMember(member);
    await _replaceNetwork(networks, updatedNetwork);
    return updatedNetwork;
  }

  @override
  Future<void> saveNetwork(ExpenseNetwork network) async {
    final networks = await getNetworks();
    final hasNetwork = networks.any(
      (existingNetwork) => _isSameNetwork(existingNetwork, network),
    );
    if (hasNetwork) {
      await _replaceNetwork(networks, network);
      return;
    }
    await _saveNetworks([...networks, network]);
  }

  @override
  Future<ExpenseNetwork> authenticateMember({
    required String networkName,
    required String memberName,
    required String memberPassword,
  }) async {
    final network = await findNetwork(networkName);
    if (network == null) {
      throw const RepositoryException('Network not found.');
    }
    final member = network.findMemberByName(memberName);
    if (member == null) {
      throw const RepositoryException('Member not found.');
    }
    if (!member.hasPassword) {
      throw const RepositoryException('This member has no local password yet.');
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
    return network;
  }

  @override
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required String addedByMemberId,
    required int amountCents,
    String? note,
  }) async {
    final networks = await getNetworks();
    final network = _findByName(networks, networkName);
    if (network == null) {
      throw const RepositoryException('Network not found.');
    }
    final actor = network.findMemberById(addedByMemberId);
    if (actor == null) {
      throw const RepositoryException('Member not found.');
    }

    final trimmedNote = note?.trim();
    final updatedNetwork = network.addExpense(
      memberName: memberName,
      amountCents: amountCents,
      addedByMemberId: actor.id,
      addedByMemberName: actor.name,
      note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
    );
    await _replaceNetwork(networks, updatedNetwork);
    await _createExpenseNotifications(
      network: updatedNetwork,
      actor: actor,
      amountCents: amountCents,
      note: trimmedNote,
    );
    return updatedNetwork;
  }

  @override
  Future<List<NetworkNotification>> getNotifications({
    required String networkId,
    required String memberId,
  }) async {
    final notifications = await _getAllNotifications();
    return notifications
        .where(
          (notification) =>
              notification.networkId == networkId &&
              notification.recipientMemberId == memberId,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final notifications = await _getAllNotifications();
    final updated = notifications
        .where((notification) => notification.id != notificationId)
        .toList();
    await _saveNotifications(updated);
  }

  @override
  Future<void> clearNotificationsForMember({
    required String networkId,
    required String memberId,
  }) async {
    final notifications = await _getAllNotifications();
    final updated = notifications.where((notification) {
      final isTarget = notification.networkId == networkId &&
          notification.recipientMemberId == memberId;
      return !isTarget;
    }).toList();
    await _saveNotifications(updated);
  }

  @override
  Future<ExpenseResetRequest?> getActiveResetRequest({
    required String networkId,
  }) async {
    final networks = await getNetworks();
    final matches = networks.where((network) => network.id == networkId);
    if (matches.isEmpty) return null;
    return matches.first.activeResetRequest;
  }

  @override
  Future<ExpenseNetwork> createResetRequest({
    required String networkName,
    required String requestedByMemberId,
  }) async {
    final networks = await getNetworks();
    final network = _findByName(networks, networkName);
    if (network == null) {
      throw const RepositoryException(
        'Network not found.',
        code: 'network_not_found',
      );
    }
    if (network.activeResetRequest != null) {
      throw const RepositoryException(
        'A reset request is already pending.',
        code: 'reset_request_already_pending',
      );
    }

    final requester = network.findMemberById(requestedByMemberId);
    if (requester == null) {
      throw const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      );
    }

    final cycle = network.activeCycle;
    final now = DateTime.now();
    final request = ExpenseResetRequest(
      networkId: network.id,
      cycleId: cycle.id,
      requestedByMemberId: requester.id,
      requestedByMemberName: requester.name,
      createdAt: now,
      requiredMemberIds: network.members.map((member) => member.id).toList(),
      requiredMemberNames: network.members.map((member) => member.name).toList(),
      approvals: [
        ExpenseResetApproval(
          memberId: requester.id,
          memberName: requester.name,
          approvedAt: now,
        ),
      ],
    );

    var updatedNetwork = network.copyWith(
      cycles: _replaceCycle(
        network,
        cycle.copyWith(
          status: ExpenseCycleStatus.pendingReset,
          requestedByMemberId: requester.id,
          requestedByMemberName: requester.name,
        ),
      ),
      resetRequests: [...network.resetRequests, request],
    );
    updatedNetwork = _completeResetIfReady(updatedNetwork, request.id);
    await _replaceNetwork(networks, updatedNetwork);
    await _createResetRequestNotifications(
      network: updatedNetwork,
      requester: requester,
      resetRequestId: request.id,
    );
    final completedRequest = updatedNetwork.resetRequests.firstWhere(
      (candidate) => candidate.id == request.id,
    );
    if (completedRequest.isCompleted) {
      await _createCycleStartedNotifications(
        network: updatedNetwork,
        resetRequestId: completedRequest.id,
      );
    }
    return updatedNetwork;
  }

  @override
  Future<ExpenseNetwork> approveResetRequest({
    required String networkName,
    required String resetRequestId,
    required String memberId,
  }) async {
    final networks = await getNetworks();
    final network = _findByName(networks, networkName);
    if (network == null) {
      throw const RepositoryException(
        'Network not found.',
        code: 'network_not_found',
      );
    }
    final member = network.findMemberById(memberId);
    if (member == null) {
      throw const RepositoryException(
        'Member not found.',
        code: 'member_not_found',
      );
    }
    final request = network.resetRequests.where(
      (candidate) => candidate.id == resetRequestId,
    );
    if (request.isEmpty || !request.first.isPending) {
      throw const RepositoryException(
        'Reset request is not pending.',
        code: 'reset_request_not_pending',
      );
    }
    if (!request.first.requiredMemberIds.contains(member.id)) {
      throw const RepositoryException(
        'This member is not required for this reset request.',
        code: 'reset_approval_not_required',
      );
    }

    final approvedRequest = request.first.approve(
      memberId: member.id,
      memberName: member.name,
    );
    var updatedNetwork = network.copyWith(
      resetRequests: network.resetRequests.map((candidate) {
        return candidate.id == approvedRequest.id ? approvedRequest : candidate;
      }).toList(),
    );
    updatedNetwork = _completeResetIfReady(updatedNetwork, approvedRequest.id);
    await _replaceNetwork(networks, updatedNetwork);

    final completedRequest = updatedNetwork.resetRequests.firstWhere(
      (candidate) => candidate.id == approvedRequest.id,
    );
    if (completedRequest.isCompleted) {
      await _createCycleStartedNotifications(
        network: updatedNetwork,
        resetRequestId: completedRequest.id,
      );
    }
    return updatedNetwork;
  }

  Member _createMember({
    required String displayName,
    required String memberPassword,
  }) {
    final name = displayName.trim();
    final salt = PasswordHashUtils.createSalt(name);
    return Member(
      id: IdUtils.createId('member'),
      name: name,
      passwordSalt: salt,
      passwordHash: PasswordHashUtils.createHash(memberPassword, salt),
      createdAt: DateTime.now(),
    );
  }

  ExpenseNetwork? _findByName(List<ExpenseNetwork> networks, String name) {
    final normalizedName = name.trim().toLowerCase();
    for (final network in networks) {
      if (network.name.toLowerCase() == normalizedName) {
        return network;
      }
    }
    return null;
  }

  Future<void> _replaceNetwork(
    List<ExpenseNetwork> networks,
    ExpenseNetwork updatedNetwork,
  ) async {
    final updatedNetworks = networks.map((network) {
      return _isSameNetwork(network, updatedNetwork)
          ? updatedNetwork
          : network;
    }).toList();
    await _saveNetworks(updatedNetworks);
  }

  bool _isSameNetwork(
    ExpenseNetwork network,
    ExpenseNetwork updatedNetwork,
  ) {
    return network.id == updatedNetwork.id ||
        network.name.toLowerCase() == updatedNetwork.name.toLowerCase();
  }

  Future<void> _saveNetworks(List<ExpenseNetwork> networks) async {
    final encoded = jsonEncode(
      networks.map((network) => network.toJson()).toList(),
    );
    await _preferences.setString(SharedPreferencesStorageKeys.networks, encoded);
  }

  Future<void> _createExpenseNotifications({
    required ExpenseNetwork network,
    required Member actor,
    required int amountCents,
    String? note,
  }) async {
    final notifications = await _getAllNotifications();
    final trimmedNote = note?.trim();
    final snippet = trimmedNote == null || trimmedNote.isEmpty
        ? null
        : trimmedNote.substring(
            0,
            trimmedNote.length > 80 ? 80 : trimmedNote.length,
          );
    final newNotifications = network.members
        .where((member) => member.id != actor.id)
        .map(
          (member) => NetworkNotification(
            networkId: network.id,
            recipientMemberId: member.id,
            actorMemberName: actor.name,
            expenseAmountCents: amountCents,
            currencySymbol: network.currencySymbol,
            noteSnippet: snippet,
          ),
        )
        .toList();
    await _saveNotifications([...notifications, ...newNotifications]);
  }

  Future<void> _createResetRequestNotifications({
    required ExpenseNetwork network,
    required Member requester,
    required String resetRequestId,
  }) async {
    final notifications = await _getAllNotifications();
    final newNotifications = network.members
        .where((member) => member.id != requester.id)
        .map(
          (member) => NetworkNotification(
            networkId: network.id,
            recipientMemberId: member.id,
            actorMemberName: requester.name,
            expenseAmountCents: 0,
            currencySymbol: network.currencySymbol,
            kind: NetworkNotificationKind.resetRequest,
            resetRequestId: resetRequestId,
          ),
        )
        .toList();
    await _saveNotifications([...notifications, ...newNotifications]);
  }

  Future<void> _createCycleStartedNotifications({
    required ExpenseNetwork network,
    required String resetRequestId,
  }) async {
    final notifications = await _getAllNotifications();
    final newNotifications = network.members
        .map(
          (member) => NetworkNotification(
            networkId: network.id,
            recipientMemberId: member.id,
            actorMemberName: network.name,
            expenseAmountCents: 0,
            currencySymbol: network.currencySymbol,
            kind: NetworkNotificationKind.cycleStarted,
            resetRequestId: resetRequestId,
          ),
        )
        .toList();
    await _saveNotifications([...notifications, ...newNotifications]);
  }

  List<ExpenseCycle> _replaceCycle(
    ExpenseNetwork network,
    ExpenseCycle updatedCycle,
  ) {
    final cycles =
        network.cycles.isEmpty ? [network.activeCycle] : network.cycles;
    var found = false;
    final updated = cycles.map((cycle) {
      if (cycle.id != updatedCycle.id) return cycle;
      found = true;
      return updatedCycle;
    }).toList();
    return found ? updated : [...updated, updatedCycle];
  }

  ExpenseNetwork _completeResetIfReady(
    ExpenseNetwork network,
    String resetRequestId,
  ) {
    final request = network.resetRequests.firstWhere(
      (candidate) => candidate.id == resetRequestId,
    );
    if (!request.isPending || !request.hasUnanimousApproval) return network;

    final now = DateTime.now();
    final closedCycle = network.activeCycle.copyWith(
      status: ExpenseCycleStatus.closed,
      closedAt: now,
    );
    final nextCycle = ExpenseCycle(
      networkId: network.id,
      cycleNumber: closedCycle.cycleNumber + 1,
      startedAt: now,
    );
    final archivedMembers = network.members.map((member) {
      return member.copyWith(
        expenses: member.expenses.map((expense) {
          if (expense.isArchived) return expense;
          return expense.copyWith(
            cycleId: expense.cycleId ?? closedCycle.id,
            archivedAt: now,
          );
        }).toList(),
      );
    }).toList();

    return network.copyWith(
      members: archivedMembers,
      cycles: [
        ..._replaceCycle(network, closedCycle),
        nextCycle,
      ],
      resetRequests: network.resetRequests.map((candidate) {
        return candidate.id == resetRequestId
            ? candidate.copyWith(
                status: ExpenseResetStatus.completed,
                completedAt: now,
              )
            : candidate;
      }).toList(),
    );
  }

  Future<List<NetworkNotification>> _getAllNotifications() async {
    final raw = _preferences.getString(
      SharedPreferencesStorageKeys.notifications,
    );
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (notification) => NetworkNotification.fromJson(
              notification as Map<String, dynamic>,
            ),
          )
          .toList();
    } on FormatException catch (_) {
      throw const RepositoryException(
        'Stored notification data could not be loaded.',
        code: 'notification_data_parse_failed',
      );
    } on TypeError catch (_) {
      throw const RepositoryException(
        'Stored notification data could not be loaded.',
        code: 'notification_data_parse_failed',
      );
    }
  }

  Future<void> _saveNotifications(
    List<NetworkNotification> notifications,
  ) async {
    final encoded = jsonEncode(
      notifications.map((notification) => notification.toJson()).toList(),
    );
    await _preferences.setString(
      SharedPreferencesStorageKeys.notifications,
      encoded,
    );
  }
}
