import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/expense_network.dart';
import '../models/expense_reset_request.dart';
import '../services/expense_network_repository.dart';
import '../services/repository_error_messages.dart';
import '../services/settlement_pdf_service.dart';
import '../services/settlement_service.dart';
import '../utils/money_utils.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/member_avatar.dart';

class ExpenseSettlementScreen extends StatefulWidget {
  const ExpenseSettlementScreen({
    required this.repository,
    required this.network,
    required this.currentMemberId,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final ExpenseNetwork network;
  final String currentMemberId;

  @override
  State<ExpenseSettlementScreen> createState() =>
      _ExpenseSettlementScreenState();
}

class _ExpenseSettlementScreenState extends State<ExpenseSettlementScreen> {
  late ExpenseNetwork _network = widget.network;
  bool _isExporting = false;
  bool _isResetBusy = false;

  Future<void> _downloadPdf() async {
    final l10n = context.l10n;
    setState(() => _isExporting = true);
    try {
      final settlement = const SettlementService().calculate(_network);
      await const SettlementPdfService().sharePdf(
        network: _network,
        settlement: settlement,
        l10n: l10n,
      );
      _showMessage(l10n.pdfSharedSuccessfully);
    } catch (_) {
      _showMessage(l10n.failedToGeneratePdf);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _requestNewCycle() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.startNewCycle),
        content: Text(l10n.startNewCycleConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResetBusy = true);
    try {
      final updated = await widget.repository.createResetRequest(
        networkName: _network.name,
        requestedByMemberId: widget.currentMemberId,
      );
      if (!mounted) return;
      setState(() => _network = updated);
      if (updated.activeResetRequest == null) {
        _showMessage(l10n.newCycleStarted);
      }
    } on RepositoryException catch (error) {
      _showRepositoryError(error, l10n);
    } catch (_) {
      _showMessage(l10n.cycleCompletionFailed);
    } finally {
      if (mounted) setState(() => _isResetBusy = false);
    }
  }

  Future<void> _approveReset(ExpenseResetRequest request) async {
    final l10n = context.l10n;
    setState(() => _isResetBusy = true);
    try {
      final updated = await widget.repository.approveResetRequest(
        networkName: _network.name,
        resetRequestId: request.id,
        memberId: widget.currentMemberId,
      );
      if (!mounted) return;
      setState(() => _network = updated);
      final completed = updated.resetRequests
          .where((candidate) => candidate.id == request.id)
          .any((candidate) => candidate.isCompleted);
      if (completed) _showMessage(l10n.newCycleStarted);
    } on RepositoryException catch (error) {
      _showRepositoryError(error, l10n);
    } catch (_) {
      _showMessage(l10n.resetApprovalFailed);
    } finally {
      if (mounted) setState(() => _isResetBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlement = const SettlementService().calculate(_network);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final resetRequest = _network.activeResetRequest;

    return AppScaffold(
      title: l10n.expenseSettlement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isExporting ? null : _downloadPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(l10n.downloadPdf),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isResetBusy || resetRequest != null
                      ? null
                      : _requestNewCycle,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(l10n.startNewCycle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (resetRequest != null) ...[
            _ResetRequestCard(
              request: resetRequest,
              currentMemberId: widget.currentMemberId,
              isBusy: _isResetBusy,
              onApprove: () => _approveReset(resetRequest),
            ),
            const SizedBox(height: 14),
          ],
          _SummaryTile(
            label: l10n.totalExpenses,
            value: MoneyUtils.formatCents(
              settlement.totalCents,
              currencySymbol: _network.currencySymbol,
            ),
          ),
          _SummaryTile(
            label: l10n.sharePerMember,
            value: MoneyUtils.formatCents(
              settlement.sharePerMemberCents,
              currencySymbol: _network.currencySymbol,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.memberStatus,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...settlement.members.map(
            (member) {
              final profile = _network.findMemberByName(member.memberName);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (profile != null) ...[
                            MemberAvatar(member: profile),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              member.memberName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.paid}: '
                        '${MoneyUtils.formatCents(
                          member.paidCents,
                          currencySymbol: _network.currencySymbol,
                        )}',
                      ),
                      Text(
                        '${l10n.shouldPay}: '
                        '${MoneyUtils.formatCents(
                          member.shouldPayCents,
                          currencySymbol: _network.currencySymbol,
                        )}',
                      ),
                      Text(
                        _memberBalanceStatus(l10n, member.balanceCents),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            l10n.finalSettlement,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (settlement.payments.isEmpty)
            Text(l10n.noSettlementNeeded)
          else
            ...settlement.payments.map(
              (payment) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(
                    l10n.settlementPayment(
                      fromMember: payment.fromMember,
                      amount: MoneyUtils.formatCents(
                        payment.amountCents,
                        currencySymbol: _network.currencySymbol,
                      ),
                      toMember: payment.toMember,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRepositoryError(RepositoryException error, AppLocalizations l10n) {
    if (error.code == 'reset_request_already_pending') {
      _showMessage(l10n.resetRequestAlreadyPending);
    } else if (error.code == 'supabase_permission_denied') {
      _showMessage(l10n.errorSupabasePermission);
    } else if (error.code == 'supabase_network_unavailable') {
      _showMessage(l10n.errorNoInternet);
    } else if (error.code == 'reset_request_not_pending' ||
        error.code == 'reset_approval_not_required') {
      _showMessage(l10n.resetApprovalFailed);
    } else {
      _showMessage(RepositoryErrorMessages.fromException(context, error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _memberBalanceStatus(AppLocalizations l10n, double balanceCents) {
    if (balanceCents < -0.5) {
      return l10n.memberOwes(
        MoneyUtils.formatCents(
          -balanceCents,
          currencySymbol: _network.currencySymbol,
        ),
      );
    }
    if (balanceCents > 0.5) {
      return l10n.memberShouldReceive(
        MoneyUtils.formatCents(
          balanceCents,
          currencySymbol: _network.currencySymbol,
        ),
      );
    }
    return l10n.memberSettled;
  }
}

class _ResetRequestCard extends StatelessWidget {
  const _ResetRequestCard({
    required this.request,
    required this.currentMemberId,
    required this.isBusy,
    required this.onApprove,
  });

  final ExpenseResetRequest request;
  final String currentMemberId;
  final bool isBusy;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final approvedNames =
        request.approvals.map((approval) => approval.memberName).toList();
    final canApprove =
        request.isPending && !request.isApprovedBy(currentMemberId);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.resetRequestPending,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(l10n.resetRequestedBy(request.requestedByMemberName)),
            Text(
              '${approvedNames.length}/${request.requiredMemberIds.length} '
              '${l10n.approvedMembers}',
            ),
            const SizedBox(height: 8),
            Text('${l10n.approvedMembers}: ${_names(approvedNames)}'),
            Text(
              '${l10n.pendingMembers}: ${_names(request.pendingMemberNames)}',
            ),
            if (canApprove) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: isBusy ? null : onApprove,
                icon: const Icon(Icons.verified_rounded),
                label: Text(l10n.approveReset),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _names(List<String> names) {
    return names.isEmpty ? '-' : names.join(', ');
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
