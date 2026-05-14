import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/expense_network_repository.dart';
import 'services/shared_preferences_expense_network_repository.dart';
import 'utils/app_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SharedPreferencesExpenseNetworkRepository();
  await repository.init();
  runApp(ExpenseNetworkApp(repository: repository));
}

class ExpenseNetworkApp extends StatelessWidget {
  const ExpenseNetworkApp({required this.repository, super.key});

  final ExpenseNetworkRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
