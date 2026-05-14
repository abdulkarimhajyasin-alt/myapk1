import 'package:flutter/material.dart';

import 'app_footer.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: child,
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
}
