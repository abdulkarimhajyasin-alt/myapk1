import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../models/member.dart';
import '../services/expense_network_repository.dart';
import '../services/repository_error_messages.dart';
import '../services/session_repository.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/form_error_text.dart';
import '../widgets/member_avatar.dart';
import 'network_dashboard_screen.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({
    required this.repository,
    required this.sessionRepository,
    this.dataMode = 'local',
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final String dataMode;

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  List<ExpenseNetwork> _networks = const [];
  ExpenseNetwork? _selectedNetwork;
  Member? _selectedMember;
  String? _error;
  bool _isLoading = true;
  bool _isEntering = false;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadNetworks() async {
    try {
      final networks = await widget.repository.getNetworks();
      final session = await widget.sessionRepository.getActiveSession();
      ExpenseNetwork? selectedNetwork;
      Member? selectedMember;

      if (session != null) {
        selectedNetwork = _firstNetworkWhere(
          networks,
          (network) => network.name == session.networkName,
        );
        selectedMember = selectedNetwork?.findMemberById(session.memberId);
      }
      selectedNetwork ??= networks.isEmpty ? null : networks.first;
      selectedMember ??= selectedNetwork?.members.isEmpty == true
          ? null
          : selectedNetwork?.members.first;

      if (!mounted) return;
      setState(() {
        _networks = networks;
        _selectedNetwork = selectedNetwork;
        _selectedMember = selectedMember;
        _isLoading = false;
      });
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = RepositoryErrorMessages.fromException(context, error);
        _isLoading = false;
      });
    }
  }

  Future<void> _enterAccount() async {
    if (!_formKey.currentState!.validate()) return;
    final network = _selectedNetwork;
    final member = _selectedMember;
    if (network == null || member == null) return;

    setState(() {
      _isEntering = true;
      _error = null;
    });

    try {
      final authenticatedNetwork = await widget.repository.authenticateMember(
        networkName: network.name,
        memberName: member.name,
        memberPassword: _passwordController.text,
      );
      if (!mounted) return;
      await widget.sessionRepository.saveActiveSession(
        networkName: authenticatedNetwork.name,
        memberId: member.id,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NetworkDashboardScreen(
            repository: widget.repository,
            sessionRepository: widget.sessionRepository,
            network: authenticatedNetwork,
            currentMemberId: member.id,
            dataMode: widget.dataMode,
          ),
        ),
      );
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = RepositoryErrorMessages.fromException(
            context,
            error,
          ));
    } finally {
      if (mounted) setState(() => _isEntering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget content;

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _networks.isEmpty) {
      content = FormErrorText(_error);
    } else if (_networks.isEmpty) {
      content = Text(l10n.noNetworksYet);
    } else {
      content = Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormErrorText(_error),
            DropdownButtonFormField<String>(
              initialValue: _selectedNetwork?.id,
              decoration: InputDecoration(labelText: l10n.selectNetwork),
              items: _networks.map((network) {
                return DropdownMenuItem<String>(
                  value: network.id,
                  child: Text(network.name),
                );
              }).toList(),
              onChanged: (value) {
                final network = _firstNetworkWhere(
                  _networks,
                  (network) => network.id == value,
                );
                setState(() {
                  _selectedNetwork = network;
                  _selectedMember = network?.members.isEmpty == true
                      ? null
                      : network?.members.first;
                });
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedNetwork?.id),
              initialValue: _selectedMember?.id,
              decoration: InputDecoration(labelText: l10n.selectMember),
              items: (_selectedNetwork?.members ?? const []).map((member) {
                return DropdownMenuItem<String>(
                  value: member.id,
                  child: Row(
                    children: [
                      MemberAvatar(member: member, radius: 14),
                      const SizedBox(width: 8),
                      Text(member.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMember =
                      _selectedNetwork?.findMemberById(value ?? '');
                });
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: l10n.accountPassword),
              obscureText: true,
              validator: _required,
              onFieldSubmitted: (_) => _enterAccount(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isEntering ? null : _enterAccount,
              child: Text(
                _isEntering ? l10n.joining : l10n.continueToAccount,
              ),
            ),
          ],
        ),
      );
    }

    return AppScaffold(
      title: l10n.myAccount,
      child: content,
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? context.l10n.fieldRequired
        : null;
  }

  ExpenseNetwork? _firstNetworkWhere(
    List<ExpenseNetwork> networks,
    bool Function(ExpenseNetwork network) test,
  ) {
    for (final network in networks) {
      if (test(network)) return network;
    }
    return null;
  }
}
