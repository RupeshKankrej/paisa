import 'package:flutter/material.dart';

import '../../app/shell_widgets.dart';

/// Placeholder tab until multi-account exists (SPEC 5.12).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: tabAppBar(title: const Text('Accounts')),
    floatingActionButton: const AddFab(),
    body: const Center(child: Text('Only one account for now')),
  );
}
