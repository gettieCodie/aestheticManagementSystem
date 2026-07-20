import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/models/app_user.dart';
import '../../../auth/state/auth_controller.dart';
import '../../models/product.dart' show kBranches;
import '../widgets/section_card.dart';
import 'page_scaffold.dart';
import '../../../../core/widgets/app_toast.dart';

/// Admin-only: manage individual staff/admin accounts (no shared accounts).
///
/// This list is live from Firestore, and the password set here is what the
/// account signs in with — see [AuthController]'s class doc.
class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return AdminPageScaffold(
      title: 'User Management',
      subtitle: 'Individual staff and admin accounts',
      children: [
        FirestoreErrorBanner(errors: auth.firestoreErrors),
        SectionCard(
          title: 'Accounts (${auth.users.length})',
          icon: Icons.manage_accounts_rounded,
          action: FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _AddUserDialog(),
            ),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(Responsive.isMobile(context) ? 'Add' : 'Add User'),
          ),
          child: Responsive.isMobile(context)
              // Six columns don't fit a phone — a tappable row per account,
              // with the full record and actions behind the tap.
              ? Column(
                  children: [for (final u in auth.users) _UserRow(user: u)],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    showCheckboxColumn: false,
                    headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
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
    return DataRow(
      onSelectChanged: (_) => _showUserSheet(context, u),
      cells: [
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
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await context.read<AuthController>().toggleActive(u.id);
                } catch (e) {
                  AppToast.errorOn(messenger, 'Could not update account: $e');
                }
              },
              child: Text(u.isActive ? 'Deactivate' : 'Activate'),
            )),
    ]);
  }
}

/// Minimal phone row: who they are, their role, and where they work.
/// Everything else is one tap away.
class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = user;
    final roleColor = u.isAdmin ? scheme.primary : scheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showUserSheet(context, u),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  child: Text(
                    u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: roleColor, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(u.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5)),
                          ),
                          if (!u.isActive) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.block_rounded,
                                size: 13, color: scheme.error),
                          ],
                        ],
                      ),
                      Text('${u.role.label} · ${u.branch ?? 'All branches'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full account record plus the activate/deactivate action.
void _showUserSheet(BuildContext context, AppUser u) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final scheme = Theme.of(sheet).colorScheme;
      final roleColor = u.isAdmin ? scheme.primary : scheme.secondary;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: roleColor.withValues(alpha: 0.15),
                    child: Text(
                      u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17)),
                        Text(u.isActive ? 'Active' : 'Deactivated',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: u.isActive
                                  ? const Color(0xFF3E9E6E)
                                  : scheme.error,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 26),
              _sheetRow(sheet, 'Username', u.username),
              _sheetRow(sheet, 'Email', u.email),
              _sheetRow(sheet, 'Role', u.role.label),
              _sheetRow(sheet, 'Branch', u.branch ?? 'All branches'),
              const SizedBox(height: 18),
              if (u.isAdmin)
                Text(
                  'Administrator accounts cannot be deactivated.',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          u.isActive ? scheme.error : const Color(0xFF3E9E6E),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(sheet);
                      final messenger = ScaffoldMessenger.of(context);
                      final controller = context.read<AuthController>();
                      try {
                        await controller.toggleActive(u.id);
                        navigator.pop();
                        AppToast.successOn(
                            messenger,
                            u.isActive
                                ? '${u.fullName} can no longer sign in.'
                                : '${u.fullName} can sign in again.');
                      } catch (e) {
                        AppToast.errorOn(
                            messenger, 'Could not update account: $e');
                      }
                    },
                    icon: Icon(
                        u.isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18),
                    label: Text(u.isActive ? 'Deactivate' : 'Activate'),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _sheetRow(BuildContext context, String label, String value) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
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

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppToast.errorOn(messenger, 'Please fix the highlighted fields.');
      return;
    }
    final auth = context.read<AuthController>();
    // Usernames must be unique — the login lookup matches on this field.
    if (auth.users.any((u) =>
        u.username.toLowerCase() == _username.text.trim().toLowerCase())) {
      AppToast.errorOn(messenger, 'That username is already taken.');
      return;
    }
    final navigator = Navigator.of(context);
    try {
      await auth.addUser(AppUser(
        id: auth.newUserId(),
        fullName: _name.text.trim(),
        username: _username.text.trim(),
        email: '${_username.text.trim()}@luxuriskin.com',
        password: _password.text,
        role: _role,
        branch: _role == UserRole.staff ? _branch : null,
      ));
      navigator.pop();
      AppToast.successOn(
          messenger, '${_name.text.trim()} can now sign in.');
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not create user: $e');
    }
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
              _field(_name, 'Full name',
                  validator: Validate.all(
                      [Validate.required, Validate.minLength(2)])),
              _field(_username, 'Username',
                  validator: Validate.all(
                      [Validate.required, Validate.minLength(4)])),
              _field(_password, 'Temporary password',
                  validator: Validate.all(
                      [Validate.required, Validate.minLength(6)])),
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

  Widget _field(TextEditingController c, String label,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: validator,
      ),
    );
  }
}
