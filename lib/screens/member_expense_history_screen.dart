import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense.dart';
import '../models/expense_network.dart';
import '../models/member.dart';
import '../services/expense_network_repository.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/member_avatar.dart';

class MemberExpenseHistoryScreen extends StatefulWidget {
  const MemberExpenseHistoryScreen({
    required this.repository,
    required this.network,
    required this.member,
    required this.currentMemberId,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final ExpenseNetwork network;
  final Member member;
  final String currentMemberId;

  @override
  State<MemberExpenseHistoryScreen> createState() =>
      _MemberExpenseHistoryScreenState();
}

class _MemberExpenseHistoryScreenState
    extends State<MemberExpenseHistoryScreen> {
  late ExpenseNetwork _network = widget.network;
  late Member _member = widget.member;

  Future<void> _editExpense(Expense expense) async {
    if (expense.addedByMemberId != widget.currentMemberId) return;

    final result = await showModalBottomSheet<_ExpenseEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditExpenseSheet(
        expense: expense,
        currencySymbol: _network.currencySymbol,
      ),
    );
    if (result == null || !mounted) return;

    try {
      final network = switch (result) {
        _ExpenseEditSave(:final expense) =>
          await widget.repository.updateExpense(
            networkName: _network.name,
            expenseId: expense.id,
            editedByMemberId: widget.currentMemberId,
            amountCents: expense.amountCents,
            note: expense.note,
            createdAt: expense.createdAt,
          ),
        _ExpenseEditDelete() => await widget.repository.deleteExpense(
            networkName: _network.name,
            networkId: _network.id,
            expenseId: expense.id,
            deletedByMemberId: widget.currentMemberId,
          ),
      };
      final refreshedMember = await widget.repository.getMemberHistory(
            networkName: network.name,
            memberId: _member.id,
          ) ??
          network.findMemberById(_member.id);
      if (!mounted) return;
      setState(() {
        _network = network;
        if (refreshedMember != null) _member = refreshedMember;
      });
      if (result is _ExpenseEditDelete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.expenseDeleted)),
        );
      }
    } on RepositoryException catch (error) {
      if (!mounted) return;
      final message = result is _ExpenseEditDelete
          ? context.l10n.expenseDeleteFailed
          : error.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AppScaffold(
      title: l10n.expenseHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemberAvatar(member: _member, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _member.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.totalPaid}: '
            '${MoneyUtils.formatCents(
              _member.totalPaidCents,
              currencySymbol: _network.currencySymbol,
            )}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 18),
          if (_member.expenses.isEmpty)
            _EmptyHistory(
              title: l10n.noExpensesYet,
              subtitle: l10n.noExpensesSubtitle,
            )
          else
            ..._member.expenses.reversed.map(
              (expense) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              MoneyUtils.formatCents(
                                expense.amountCents,
                                currencySymbol: _network.currencySymbol,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (expense.addedByMemberId == widget.currentMemberId)
                            IconButton(
                              tooltip: l10n.editExpense,
                              onPressed: () => _editExpense(expense),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${MaterialLocalizations.of(context).formatFullDate(
                          expense.createdAt,
                        )} ${MaterialLocalizations.of(context).formatTimeOfDay(
                          TimeOfDay.fromDateTime(expense.createdAt),
                        )}',
                      ),
                      if (expense.addedByMemberName.isNotEmpty)
                        Text('${l10n.addedBy}: ${expense.addedByMemberName}'),
                      if (expense.note != null) ...[
                        const SizedBox(height: 8),
                        Text('${l10n.note}: ${expense.note}'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

sealed class _ExpenseEditResult {
  const _ExpenseEditResult();
}

class _ExpenseEditSave extends _ExpenseEditResult {
  const _ExpenseEditSave(this.expense);

  final Expense expense;
}

class _ExpenseEditDelete extends _ExpenseEditResult {
  const _ExpenseEditDelete();
}

class _EditExpenseSheet extends StatefulWidget {
  const _EditExpenseSheet({
    required this.expense,
    required this.currencySymbol,
  });

  final Expense expense;
  final String currencySymbol;

  @override
  State<_EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<_EditExpenseSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: (widget.expense.amountCents / 100).toStringAsFixed(2),
  );
  late final TextEditingController _noteController = TextEditingController(
    text: widget.expense.note ?? '',
  );
  late DateTime _createdAt = widget.expense.createdAt;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _createdAt = DateTime(
        date.year,
        date.month,
        date.day,
        _createdAt.hour,
        _createdAt.minute,
      );
    });
  }

  void _save() {
    final l10n = context.l10n;
    final amount = MoneyUtils.parseToCents(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = l10n.invalidAmount);
      return;
    }
    final note = _noteController.text.trim();
    if (note.length > 200) {
      setState(() => _error = l10n.noteTooLong);
      return;
    }
    Navigator.of(context).pop(
      _ExpenseEditSave(
        widget.expense.copyWith(
          amountCents: amount,
          note: note.isEmpty ? null : note,
          clearNote: note.isEmpty,
          createdAt: _createdAt,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteExpense),
        content: Text(l10n.deleteExpenseConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop(const _ExpenseEditDelete());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.editExpense,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.amount,
              prefixText: '${widget.currencySymbol} ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLength: 200,
            decoration: InputDecoration(labelText: l10n.noteOptional),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded),
            label: Text(
              MaterialLocalizations.of(context).formatFullDate(_createdAt),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_rounded),
                  label: Text(l10n.delete),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(l10n.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 42,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
