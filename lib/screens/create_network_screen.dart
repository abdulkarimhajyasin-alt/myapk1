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

class CreateNetworkScreen extends StatefulWidget {
  const CreateNetworkScreen({required this.repository, super.key});

  final ExpenseNetworkRepository repository;

  @override
  State<CreateNetworkScreen> createState() => _CreateNetworkScreenState();
}

class _CreateNetworkScreenState extends State<CreateNetworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _networkNameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _networkNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createNetwork() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final network = await widget.repository.createNetwork(
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
      if (mounted) setState(() => _isSaving = false);
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
      title: l10n.createNetwork,
=======
    return AppScaffold(
      title: AppStrings.createNetwork,
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
              onFieldSubmitted: (_) => _createNetwork(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSaving ? null : _createNetwork,
<<<<<<< HEAD
              child: Text(_isSaving ? l10n.creating : l10n.create),
=======
              child: Text(_isSaving ? AppStrings.creating : AppStrings.create),
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
