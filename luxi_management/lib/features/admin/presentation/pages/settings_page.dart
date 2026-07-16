import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/state/auth_controller.dart';
import '../widgets/section_card.dart';
import 'page_scaffold.dart';

/// Admin settings — clinic profile and the signed-in account.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final scheme = Theme.of(context).colorScheme;

    return AdminPageScaffold(
      title: 'Settings',
      subtitle: 'Clinic profile and account',
      children: [
        SectionCard(
          title: 'Clinic',
          icon: Icons.business_rounded,
          child: Column(
            children: const [
              _Row(label: 'Business name', value: 'Luxuriskin Aesthetic Clinic'),
              _Row(label: 'Branches', value: 'Laguna · Batangas · Lipa · Pampanga'),
              _Row(label: 'Clinic hours', value: '9:00 AM – 4:00 PM'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Signed-in Account',
          icon: Icons.account_circle_rounded,
          child: Column(
            children: [
              _Row(label: 'Name', value: user?.fullName ?? '—'),
              _Row(label: 'Username', value: user?.username ?? '—'),
              _Row(label: 'Role', value: user?.role.label ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthController>().logout(),
          icon: Icon(Icons.logout_rounded, color: scheme.error),
          label: Text('Sign out', style: TextStyle(color: scheme.error)),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
