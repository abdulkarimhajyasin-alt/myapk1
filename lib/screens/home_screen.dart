import 'package:flutter/material.dart';

<<<<<<< HEAD
import '../l10n/app_localizations.dart';
import '../services/expense_network_repository.dart';
=======
import '../services/expense_network_repository.dart';
import '../utils/app_strings.dart';
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
import 'create_network_screen.dart';
import 'join_network_screen.dart';

class HomeScreen extends StatelessWidget {
<<<<<<< HEAD
  const HomeScreen({
    required this.repository,
    required this.onChangeLanguage,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final ValueChanged<BuildContext> onChangeLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: l10n.changeLanguage,
                  onPressed: () => onChangeLanguage(context),
                  icon: const Icon(Icons.language_rounded),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 36),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreateNetworkScreen(repository: repository),
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
                              builder: (_) =>
                                  JoinNetworkScreen(repository: repository),
                            ),
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: Text(l10n.joinNetwork),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
=======
  const HomeScreen({required this.repository, super.key});

  final ExpenseNetworkRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
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
                    AppStrings.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Create or join a private group and settle shared costs clearly.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 36),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateNetworkScreen(repository: repository),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(AppStrings.createNetwork),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              JoinNetworkScreen(repository: repository),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text(AppStrings.joinNetwork),
                  ),
                ],
              ),
            ),
          ),
>>>>>>> 4adbe7e14d3361fe062125d087de21cd412ba8bb
        ),
      ),
    );
  }
}
