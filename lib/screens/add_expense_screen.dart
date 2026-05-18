import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../services/expense_network_repository.dart';
import '../services/offline_sync_queue.dart';
import '../services/repository_error_messages.dart';
import '../utils/id_utils.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/form_error_text.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({
    required this.repository,
    required this.network,
    required this.currentMemberId,
    this.dataMode = 'local',
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final ExpenseNetwork network;
  final String currentMemberId;
  final String dataMode;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = MoneyUtils.parseToCents(_amountController.text);
    if (cents == null) return;
    final clientGeneratedId = IdUtils.createId('client_expense');

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final network = await widget.repository.addExpense(
        networkName: widget.network.name,
        memberName: _currentMemberName,
        addedByMemberId: widget.currentMemberId,
        amountCents: cents,
        note: _noteController.text,
        clientGeneratedId: clientGeneratedId,
      );
      if (mounted) Navigator.of(context).pop(network);
    } on RepositoryException catch (error) {
      if (widget.dataMode == 'supabase' &&
          error.code == 'supabase_network_unavailable') {
        final preferences = await SharedPreferences.getInstance();
        await OfflineSyncQueue(preferences).enqueueAddExpense(
          networkName: widget.network.name,
          memberName: _currentMemberName,
          addedByMemberId: widget.currentMemberId,
          amountCents: cents,
          note: _noteController.text,
          clientGeneratedId: clientGeneratedId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.savedOffline)),
        );
        Navigator.of(context).pop();
        return;
      }
      if (!mounted) return;
      setState(() => _error = RepositoryErrorMessages.fromException(
            context,
            error,
          ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      title: l10n.addExpense,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormErrorText(_error),
            Text(
              l10n.addingExpenseFor(_currentMemberName),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: l10n.amount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: (value) {
                return MoneyUtils.parseToCents(value ?? '') == null
                    ? l10n.invalidAmount
                    : null;
              },
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _amountController,
              builder: (context, value, _) {
                final cents = MoneyUtils.parseToCents(value.text);
                if (cents == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${l10n.amountPreview}: '
                    '${MoneyUtils.formatCents(
                      cents,
                      currencySymbol: widget.network.currencySymbol,
                    )}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(labelText: l10n.noteOptional),
              maxLines: 3,
              maxLength: 200,
              validator: (value) {
                return (value?.trim().length ?? 0) > 200
                    ? l10n.noteTooLong
                    : null;
              },
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _isSaving ? null : _saveExpense,
              child: _isSaving
                  ? _LoadingLabel(label: l10n.saving)
                  : Text(l10n.saveExpense),
            ),
          ],
        ),
      ),
    );
  }

  String get _currentMemberName {
    return widget.network.findMemberById(widget.currentMemberId)?.name ?? '';
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
