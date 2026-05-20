import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../services/repository_error_messages.dart';
import '../services/session_repository.dart';
import '../utils/currency_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/form_error_text.dart';
import 'network_dashboard_screen.dart';

class CreateNetworkScreen extends StatefulWidget {
  const CreateNetworkScreen({
    required this.repository,
    required this.sessionRepository,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;

  @override
  State<CreateNetworkScreen> createState() => _CreateNetworkScreenState();
}

class _CreateNetworkScreenState extends State<CreateNetworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _networkNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _memberPasswordController = TextEditingController();
  NetworkCurrency _selectedCurrency = CurrencyCatalog.defaultCurrency;
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _networkNameController.dispose();
    _passwordController.dispose();
    _memberPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createNetwork() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _clearInvalidPersistedSession();
      final network = await widget.repository.createNetwork(
        displayName: _displayNameController.text,
        networkName: _networkNameController.text,
        password: _passwordController.text,
        memberPassword: _memberPasswordController.text,
        currencyCode: _selectedCurrency.code,
      );
      if (!mounted) return;
      await widget.sessionRepository.saveActiveSession(
        networkName: network.name,
        memberId: network.members.first.id,
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearInvalidPersistedSession() async {
    final session = await widget.sessionRepository.getActiveSession();
    if (session == null) return;

    try {
      final savedNetwork = await widget.repository.findNetwork(
        session.networkName,
      );
      final savedMember = savedNetwork?.findMemberById(session.memberId);
      if (savedNetwork == null || savedMember == null) {
        await widget.sessionRepository.clearActiveSession();
      }
    } on RepositoryException catch (error) {
      if (error.code == 'supabase_not_found' ||
          error.code == 'network_not_found' ||
          error.code == 'member_not_found') {
        await widget.sessionRepository.clearActiveSession();
      }
    }
  }

  void _openDashboard(ExpenseNetwork network) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NetworkDashboardScreen(
          repository: widget.repository,
          sessionRepository: widget.sessionRepository,
          network: network,
          currentMemberId: network.members.first.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return AppScaffold(
      title: l10n.createNetwork,
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
              onFieldSubmitted: (_) => _createNetwork(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _memberPasswordController,
              decoration: InputDecoration(labelText: l10n.memberPassword),
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: _passwordValidator,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedCurrency.code,
              decoration: InputDecoration(labelText: l10n.networkCurrency),
              items: CurrencyCatalog.supportedCurrencies.map((currency) {
                return DropdownMenuItem<String>(
                  value: currency.code,
                  child: Text(currency.labelFor(locale)),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedCurrency = CurrencyCatalog.findByCode(value);
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.currencyHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSaving ? null : _createNetwork,
              child: _isSaving
                  ? _LoadingLabel(label: l10n.creating)
                  : Text(l10n.create),
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
