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

typedef MyAccountDashboardBuilder = Widget Function(
  ExpenseNetwork network,
  String currentMemberId,
);

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({
    required this.repository,
    required this.sessionRepository,
    this.dashboardBuilder,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final MyAccountDashboardBuilder? dashboardBuilder;

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
      var clearedStaleSession = false;

      if (session != null) {
        selectedNetwork = _firstNetworkWhere(
          networks,
          (network) => network.name == session.networkName,
        );
        selectedMember = selectedNetwork?.findMemberById(session.memberId);
        if (selectedNetwork == null || selectedMember == null) {
          await widget.sessionRepository.clearActiveSession();
          clearedStaleSession = true;
        }
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
        _error = clearedStaleSession
            ? RepositoryErrorMessages.fromCode(
                context.l10n,
                'network_not_found',
              )
            : null;
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
      final authenticatedMember =
          authenticatedNetwork.findMemberByName(member.name) ?? member;
      final sessionSaved = await _saveAuthenticatedSession(
        authenticatedNetwork.id,
        authenticatedNetwork.name,
        authenticatedMember.id,
        _passwordController.text,
      );
      if (!mounted) return;
      if (!sessionSaved) return;
      _openDashboard(authenticatedNetwork, authenticatedMember.id);
    } on RepositoryException catch (error) {
      if (!mounted) return;
      if (_isStaleAccountError(error)) {
        await widget.sessionRepository.clearActiveSession();
        if (!mounted) return;
      }
      setState(() => _error = RepositoryErrorMessages.fromException(
            context,
            error,
          ));
    } finally {
      if (mounted) setState(() => _isEntering = false);
    }
  }

  Future<bool> _saveAuthenticatedSession(
    String networkId,
    String networkName,
    String memberId,
    String memberPassword,
  ) async {
    _logAccountAuthRestore(
      networkId: networkId,
      memberId: memberId,
      passwordProvided: memberPassword.trim().isNotEmpty,
      state: null,
      success: false,
      failureReason: 'starting',
    );
    try {
      await widget.sessionRepository.saveActiveSession(
        networkName: networkName,
        memberId: memberId,
        memberPassword: memberPassword,
        networkId: networkId,
      );
      final state =
          await widget.sessionRepository.restoreAuthenticatedSession();
      final success = state.authRestored &&
          state.supabaseSessionExists &&
          state.currentUserExists &&
          state.jwtMemberId == memberId;
      _logAccountAuthRestore(
        networkId: networkId,
        memberId: memberId,
        passwordProvided: memberPassword.trim().isNotEmpty,
        state: state,
        success: success,
        failureReason: success ? '<none>' : 'jwt_or_session_missing',
      );
      if (!success) {
        if (mounted) {
          setState(() => _error = context.l10n.secureSessionReauthRequired);
        }
        return false;
      }
      return true;
    } catch (error) {
      _logAccountAuthRestore(
        networkId: networkId,
        memberId: memberId,
        passwordProvided: memberPassword.trim().isNotEmpty,
        state: null,
        success: false,
        failureReason: error.runtimeType.toString(),
      );
      if (mounted) {
        setState(() => _error = context.l10n.secureSessionReauthRequired);
      }
      return false;
    }
  }

  void _logAccountAuthRestore({
    required String networkId,
    required String memberId,
    required bool passwordProvided,
    required AccountSessionAuthState? state,
    required bool success,
    required String failureReason,
  }) {
    debugPrint(
      'maskan.accountAuth.restore '
      'networkId=$networkId '
      'memberId=$memberId '
      'passwordProvided=$passwordProvided '
      'sessionExists=${state?.supabaseSessionExists ?? false} '
      'currentUserExists=${state?.currentUserExists ?? false} '
      'jwtMemberId=${state?.jwtMemberId ?? '<none>'} '
      'success=$success '
      'failureReason=$failureReason',
    );
  }

  void _openDashboard(ExpenseNetwork network, String currentMemberId) {
    final dashboard = widget.dashboardBuilder?.call(
          network,
          currentMemberId,
        ) ??
        NetworkDashboardScreen(
          repository: widget.repository,
          sessionRepository: widget.sessionRepository,
          network: network,
          currentMemberId: currentMemberId,
        );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => dashboard),
    );
  }

  bool _isStaleAccountError(RepositoryException error) {
    return switch (error.code) {
      'supabase_not_found' || 'network_not_found' || 'member_not_found' => true,
      _ => false,
    };
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
