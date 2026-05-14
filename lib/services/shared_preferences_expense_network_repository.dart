import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_network.dart';
import 'expense_network_repository.dart';

class SharedPreferencesExpenseNetworkRepository
    implements ExpenseNetworkRepository {
  static const _storageKey = 'expense_networks_v1';

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
  Future<ExpenseNetwork> createNetwork({
    required String displayName,
    required String networkName,
    required String password,
  }) async {
    final networks = await getNetworks();
    if (_findByName(networks, networkName) != null) {
      throw const RepositoryException('A network with this name already exists.');
    }

    final network = ExpenseNetwork(
      name: networkName.trim(),
      password: password.trim(),
      members: const [],
      createdAt: DateTime.now(),
    ).addMember(displayName.trim());

    await _saveNetworks([...networks, network]);
    return network;
  }

  @override
  Future<ExpenseNetwork> joinNetwork({
    required String displayName,
    required String networkName,
    required String password,
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

    final updatedNetwork = network.addMember(displayName.trim());
    await _replaceNetwork(networks, updatedNetwork);
    return updatedNetwork;
  }

  @override
  Future<ExpenseNetwork> addExpense({
    required String networkName,
    required String memberName,
    required int amountCents,
    String? note,
  }) async {
    final networks = await getNetworks();
    final network = _findByName(networks, networkName);
    if (network == null) {
      throw const RepositoryException('Network not found.');
    }

    final updatedNetwork = network.addExpense(
      memberName: memberName,
      amountCents: amountCents,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
    await _replaceNetwork(networks, updatedNetwork);
    return updatedNetwork;
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
}
