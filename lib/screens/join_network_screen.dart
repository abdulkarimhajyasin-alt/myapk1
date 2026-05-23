import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../services/repository_error_messages.dart';
import '../services/session_repository.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/form_error_text.dart';
import 'network_dashboard_screen.dart';

typedef JoinNetworkDashboardBuilder = Widget Function(
  ExpenseNetwork network,
  String currentMemberId,
);

class JoinNetworkScreen extends StatefulWidget {
  const JoinNetworkScreen({
    required this.repository,
    required this.sessionRepository,
    this.inviteNetworkId,
    this.inviteNetworkName,
    this.dashboardBuilder,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final String? inviteNetworkId;
  final String? inviteNetworkName;
  final JoinNetworkDashboardBuilder? dashboardBuilder;

  @override
  State<JoinNetworkScreen> createState() => _JoinNetworkScreenState();
}

class _JoinNetworkScreenState extends State<JoinNetworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _networkNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _memberPasswordController = TextEditingController();
  String? _error;
  bool _isJoining = false;
  bool get _hasInvite => widget.inviteNetworkId?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    final inviteName = widget.inviteNetworkName;
    if (inviteName != null && inviteName.trim().isNotEmpty) {
      _networkNameController.text = inviteName.trim();
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _networkNameController.dispose();
    _passwordController.dispose();
    _memberPasswordController.dispose();
    super.dispose();
  }

  Future<void> _joinNetwork() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final network = await widget.repository.joinNetwork(
        displayName: _displayNameController.text,
        networkName: _networkNameController.text,
        password: _passwordController.text,
        memberPassword: _memberPasswordController.text,
        networkId: widget.inviteNetworkId,
      );
      if (!mounted) return;
      final currentMemberId = network.members.last.id;
      final sessionSaved = await _saveJoinedSession(
        network.id,
        network.name,
        currentMemberId,
        _memberPasswordController.text,
      );
      if (!mounted) return;
      if (!sessionSaved) return;
      _openDashboard(network, currentMemberId);
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = RepositoryErrorMessages.fromException(
            context,
            error,
          ));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<bool> _saveJoinedSession(
    String networkId,
    String networkName,
    String memberId,
    String memberPassword,
  ) async {
    try {
      await widget.sessionRepository.saveActiveSession(
        networkName: networkName,
        memberId: memberId,
        memberPassword: memberPassword,
        networkId: networkId,
      );
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.secureSessionReauthRequired);
      }
      return false;
    }
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
      MaterialPageRoute(
        builder: (_) => dashboard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.joinNetwork,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormErrorText(_error),
            if (_hasInvite) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.inviteJoinPrefill,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            TextFormField(
              controller: _displayNameController,
              decoration: InputDecoration(labelText: l10n.displayName),
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _networkNameController,
              decoration: InputDecoration(labelText: l10n.networkName),
              textInputAction: TextInputAction.next,
              enabled: !_hasInvite || widget.inviteNetworkName != null,
              validator: _hasInvite ? null : _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: l10n.networkPassword),
              obscureText: true,
              validator: _required,
              onFieldSubmitted: (_) => _joinNetwork(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _memberPasswordController,
              decoration: InputDecoration(labelText: l10n.memberPassword),
              obscureText: true,
              validator: _passwordValidator,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isJoining ? null : _joinNetwork,
              child: _isJoining
                  ? _LoadingLabel(label: l10n.joining)
                  : Text(l10n.join),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? context.l10n.fieldRequired
        : null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.fieldRequired;
    }
    if (value.trim().length < 4) {
      return context.l10n.passwordTooShort;
    }
    return null;
  }
}

class _LoadingLabel extends StatelessWidget {
  const _LoadingLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
