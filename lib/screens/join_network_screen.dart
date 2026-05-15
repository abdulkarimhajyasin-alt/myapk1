import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../services/repository_error_messages.dart';
import '../services/session_repository.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/form_error_text.dart';
import 'network_dashboard_screen.dart';

class JoinNetworkScreen extends StatefulWidget {
  const JoinNetworkScreen({
    required this.repository,
    required this.sessionRepository,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;

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
      );
      if (!mounted) return;
      await widget.sessionRepository.saveActiveSession(
        networkName: network.name,
        memberId: network.members.last.id,
      );
      if (!mounted) return;
      _openDashboard(network);
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

  void _openDashboard(ExpenseNetwork network) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NetworkDashboardScreen(
          repository: widget.repository,
          sessionRepository: widget.sessionRepository,
          network: network,
          currentMemberId: network.members.last.id,
        ),
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
              validator: _required,
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
