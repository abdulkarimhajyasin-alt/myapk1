import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/expense_network_repository.dart';
import '../services/session_repository.dart';
import '../services/session_restoration_service.dart';
import '../widgets/app_footer.dart';
import 'create_network_screen.dart';
import 'join_network_screen.dart';
import 'my_account_screen.dart';
import 'network_dashboard_screen.dart';
import 'scan_invite_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    required this.sessionRepository,
    required this.onChangeLanguage,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;
  final ValueChanged<BuildContext> onChangeLanguage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasTriedRestore = false;
  bool _isRestoringSession = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasTriedRestore) return;
    _hasTriedRestore = true;
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final result = await SessionRestorationService(
      repository: widget.repository,
      sessionRepository: widget.sessionRepository,
    ).restoreWithStatus();
    if (!mounted) return;
    if (result.status == SessionRestorationStatus.staleSessionCleared) {
      setState(() => _isRestoringSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorCloudRecordUnavailable)),
      );
      return;
    }
    if (result.status == SessionRestorationStatus.unavailable) {
      setState(() => _isRestoringSession = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.secureSessionReauthRequired)),
      );
      return;
    }
    final restored = result.restoredSession;
    if (restored == null) {
      setState(() => _isRestoringSession = false);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NetworkDashboardScreen(
          repository: widget.repository,
          sessionRepository: widget.sessionRepository,
          network: restored.network,
          currentMemberId: restored.memberId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_isRestoringSession) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 24),
                          Text(
                            l10n.restoringSessionTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.restoringSessionMessage,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const AppFooter(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        tooltip: l10n.changeLanguage,
                        onPressed: () => widget.onChangeLanguage(context),
                        icon: const Icon(Icons.language_rounded),
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 72,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              l10n.appTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.homeSubtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 36),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CreateNetworkScreen(
                                      repository: widget.repository,
                                      sessionRepository:
                                          widget.sessionRepository,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l10n.createNetwork),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => JoinNetworkScreen(
                                      repository: widget.repository,
                                      sessionRepository:
                                          widget.sessionRepository,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.login_rounded),
                              label: Text(l10n.joinNetwork),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ScanInviteScreen(
                                      repository: widget.repository,
                                      sessionRepository:
                                          widget.sessionRepository,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: Text(l10n.scanInvite),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MyAccountScreen(
                                      repository: widget.repository,
                                      sessionRepository:
                                          widget.sessionRepository,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_rounded),
                              label: Text(l10n.myAccount),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
