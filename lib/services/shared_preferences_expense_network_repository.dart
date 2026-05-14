import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_network.dart';
import '../models/member.dart';
import '../models/network_notification.dart';
import '../utils/currency_utils.dart';
import '../utils/id_utils.dart';
import '../utils/password_hash_utils.dart';
import 'expense_network_repository.dart';

class SharedPreferencesExpenseNetworkRepository
    implements ExpenseNetworkRepository {
  static const _storageKey = 'expense_networks_v1';
  static const _notificationsKey = 'expense_network_notifications_v1';
  static const _activeNetworkNameKey = 'active_network_name';
  static const _activeMemberIdKey = 'active_member_id';

  late final SharedPreferences _preferences;

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  @override
  Future<List<ExpenseNetwork>> getNetworks() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((network) => ExpenseNetwork.fromJson(network as Map<String, dynamic>))
        .toList();
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
  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
    required String memberPassword,
    required String currencyCode,
  }) async {
    final networks = await getNetworks();
    if (_findByName(networks, networkName) != null) {
      throw const RepositoryException('A network with this name already exists.');
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
    await saveActiveSession(networkName: network.name, memberId: member.id);
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
      throw const RepositoryException('Network name or password is incorrect.');
    }

    final memberExists = network.members.any(
      (member) => member.name.toLowerCase() == displayName.trim().toLowerCase(),
    );
    if (memberExists) {
      throw const RepositoryException(
        'This member name is already used in the network.',
      );
    }

    final member = _createMember(
      displayName: displayName,
      memberPassword: memberPassword,
    );
    final updatedNetwork = network.addMember(member);
    await _replaceNetwork(networks, updatedNetwork);
    await saveActiveSession(
      networkName: updatedNetwork.name,
      memberId: member.id,
    );
    return updatedNetwork;
  }

  @override
  Future<AccountSession?> getActiveSession() async {
    final networkName = _preferences.getString(_activeNetworkNameKey);
    final memberId = _preferences.getString(_activeMemberIdKey);
    if (networkName == null ||
        networkName.trim().isEmpty ||
        memberId == null ||
        memberId.trim().isEmpty) {
      return null;
    }
    return AccountSession(networkName: networkName, memberId: memberId);
  }

  @override
  Future<void> saveActiveSession({
    required String networkName,
    required String memberId,
  }) async {
    await _preferences.setString(_activeNetworkNameKey, networkName);
    await _preferences.setString(_activeMemberIdKey, memberId);
  }

  @override
  Future<void> clearActiveSession() async {
    await _preferences.remove(_activeNetworkNameKey);
    await _preferences.remove(_activeMemberIdKey);
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
      throw const RepositoryException('Member password is incorrect.');
    }
    await saveActiveSession(networkName: network.name, memberId: member.id);
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
  Future<void> markNotificationRead(String notificationId) async {
    final notifications = await _getAllNotifications();
    final updated = notifications.map((notification) {
      return notification.id == notificationId
          ? notification.copyWith(isRead: true)
          : notification;
    }).toList();
    await _saveNotifications(updated);
  }

  @override
  Future<void> markAllNotificationsRead({
    required String networkId,
    required String memberId,
  }) async {
    final notifications = await _getAllNotifications();
    final updated = notifications.map((notification) {
      final isTarget = notification.networkId == networkId &&
          notification.recipientMemberId == memberId;
      return isTarget ? notification.copyWith(isRead: true) : notification;
    }).toList();
    await _saveNotifications(updated);
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
      return network.name.toLowerCase() == updatedNetwork.name.toLowerCase()
          ? updatedNetwork
          : network;
    }).toList();
    await _saveNetworks(updatedNetworks);
  }

  Future<void> _saveNetworks(List<ExpenseNetwork> networks) async {
    final encoded = jsonEncode(
      networks.map((network) => network.toJson()).toList(),
    );
    await _preferences.setString(_storageKey, encoded);
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

  Future<List<NetworkNotification>> _getAllNotifications() async {
    final raw = _preferences.getString(_notificationsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (notification) =>
              NetworkNotification.fromJson(notification as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _saveNotifications(
    List<NetworkNotification> notifications,
  ) async {
    final encoded = jsonEncode(
      notifications.map((notification) => notification.toJson()).toList(),
    );
    await _preferences.setString(_notificationsKey, encoded);
  }
}
