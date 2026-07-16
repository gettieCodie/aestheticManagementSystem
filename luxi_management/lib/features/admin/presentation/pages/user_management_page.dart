import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/models/app_user.dart';
import '../../../auth/state/auth_controller.dart';
import '../../models/product.dart' show kBranches;
import '../widgets/section_card.dart';
import 'page_scaffold.dart';

/// Admin-only: manage individual staff/admin accounts (no shared accounts).
class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return AdminPageScaffold(
      title: 'User Management',
      subtitle: 'Individual staff and admin accounts',
      children: [
        SectionCard(
          title: 'Accounts (${auth.users.length})',
          icon: Icons.manage_accounts_rounded,
          action: FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _AddUserDialog(),
            ),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Add User'),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              headingTextStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Username')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Branch')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: [
                for (final u in auth.users) _row(context, u),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _row(BuildContext context, AppUser u) {
    final scheme = Theme.of(context).colorScheme;
    final roleColor = u.isAdmin ? scheme.primary : scheme.secondary;
    return DataRow(cells: [
      DataCell(Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(u.username)),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: roleColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(u.role.label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: roleColor)),
      )),
      DataCell(Text(u.branch ?? 'All')),
      DataCell(Text(u.isActive ? 'Active' : 'Disabled',
          style: TextStyle(
              color: u.isActive ? const Color(0xFF3E9E6E) : scheme.error,
              fontWeight: FontWeight.w600))),
      DataCell(u.isAdmin
          ? const SizedBox.shrink()
          : TextButton(
              onPressed: () => context.read<AuthController>().toggleActive(u.id),
              child: Text(u.isActive ? 'Deactivate' : 'Activate'),
            )),
    ]);
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.staff;
  String _branch = kBranches.first;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    auth.addUser(AppUser(
      id: auth.newUserId(),
      fullName: _name.text.trim(),
      username: _username.text.trim(),
      email: '${_username.text.trim()}@luxuriskin.com',
      password: _password.text,
      role: _role,
      branch: _role == UserRole.staff ? _branch : null,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Add User'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Full name', required: true),
              _field(_username, 'Username', required: true),
              _field(_password, 'Temporary password', required: true),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Role', isDense: true),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UserRole>(
                    value: _role,
                    isExpanded: true,
                    items: [
                      for (final r in UserRole.values)
                        DropdownMenuItem(value: r, child: Text(r.label)),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? _role),
                  ),
                ),
              ),
              if (_role == UserRole.staff) ...[
                const SizedBox(height: 12),
                InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Branch', isDense: true),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _branch,
                      isExpanded: true,
                      items: [
                        for (final b in kBranches)
                          DropdownMenuItem(value: b, child: Text(b)),
                      ],
                      onChanged: (v) => setState(() => _branch = v ?? _branch),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Create')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}
