import 'package:flutter/material.dart';

import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../utils/app_strings.dart';
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
      _openDashboard(network);
    } on RepositoryException catch (error) {
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
    return AppScaffold(
      title: AppStrings.joinNetwork,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormErrorText(_error),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: AppStrings.displayName),
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _networkNameController,
              decoration: const InputDecoration(labelText: AppStrings.networkName),
              textInputAction: TextInputAction.next,
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              decoration:
                  const InputDecoration(labelText: AppStrings.networkPassword),
              obscureText: true,
              validator: _required,
              onFieldSubmitted: (_) => _joinNetwork(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isJoining ? null : _joinNetwork,
              child: Text(_isJoining ? AppStrings.joining : AppStrings.join),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? AppStrings.fieldRequired
        : null;
  }
}
