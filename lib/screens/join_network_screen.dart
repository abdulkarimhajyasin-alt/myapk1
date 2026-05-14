import 'package:flutter/material.dart';

<<<<<<< HEAD
import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
=======
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../utils/app_strings.dart';
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
import '../widgets/app_scaffold.dart';
import '../widgets/form_error_text.dart';
import 'network_dashboard_screen.dart';

class JoinNetworkScreen extends StatefulWidget {
  const JoinNetworkScreen({required this.repository, super.key});

  final ExpenseNetworkRepository repository;

  @override
  State<JoinNetworkScreen> createState() => _JoinNetworkScreenState();
}

class _JoinNetworkScreenState extends State<JoinNetworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _networkNameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isJoining = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _networkNameController.dispose();
    _passwordController.dispose();
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
      );
<<<<<<< HEAD
      if (!mounted) return;
      _openDashboard(network);
    } on RepositoryException catch (error) {
      if (!mounted) return;
=======
      _openDashboard(network);
    } on RepositoryException catch (error) {
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _openDashboard(ExpenseNetwork network) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NetworkDashboardScreen(
          repository: widget.repository,
          network: network,
          currentMemberName: _displayNameController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.joinNetwork,
=======
    return AppScaffold(
      title: AppStrings.joinNetwork,
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormErrorText(_error),
            TextFormField(
              controller: _displayNameController,
<<<<<<< HEAD
              decoration: InputDecoration(labelText: l10n.displayName),
=======
              decoration: const InputDecoration(labelText: AppStrings.displayName),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _networkNameController,
<<<<<<< HEAD
              decoration: InputDecoration(labelText: l10n.networkName),
=======
              decoration: const InputDecoration(labelText: AppStrings.networkName),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
<<<<<<< HEAD
              decoration: InputDecoration(labelText: l10n.networkPassword),
=======
              decoration:
                  const InputDecoration(labelText: AppStrings.networkPassword),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
              obscureText: true,
              validator: _required,
              onFieldSubmitted: (_) => _joinNetwork(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isJoining ? null : _joinNetwork,
<<<<<<< HEAD
              child: Text(_isJoining ? l10n.joining : l10n.join),
=======
              child: Text(_isJoining ? AppStrings.joining : AppStrings.join),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
<<<<<<< HEAD
        ? context.l10n.fieldRequired
=======
        ? AppStrings.fieldRequired
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
        : null;
  }
}
