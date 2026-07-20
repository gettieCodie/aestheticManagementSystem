import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/admin/presentation/pages/dashboard_page.dart';
import '../features/admin/presentation/pages/inventory_page.dart';
import '../features/admin/presentation/pages/pos_config_page.dart';
import '../features/admin/presentation/pages/sales_history_page.dart';
import '../features/admin/presentation/pages/settings_page.dart';
import '../features/admin/presentation/pages/user_management_page.dart';
import '../features/auth/models/app_user.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/staff/presentation/pages/client_records_page.dart';
import '../features/staff/presentation/pages/pos_page.dart';
import '../features/staff/presentation/pages/scheduling_page.dart';
import 'dashboard_shell.dart';

/// Admin-only navigation — system management features.
///
/// The first five appear in the phone's bottom bar (with [shortLabel]); the
/// rest are reached from the drawer, so the most-used items come first.
const List<NavItem> _adminNav = [
  NavItem('Dashboard', Icons.dashboard_rounded, DashboardPage(),
      shortLabel: 'Home'),
  NavItem('Inventory', Icons.inventory_2_rounded, InventoryPage(),
      shortLabel: 'Stock'),
  NavItem('Sales & Reports', Icons.receipt_long_rounded, SalesHistoryPage(),
      shortLabel: 'Sales'),
  NavItem('POS Config', Icons.tune_rounded, PosConfigPage(),
      shortLabel: 'Config'),
  NavItem('User Management', Icons.manage_accounts_rounded,
      UserManagementPage(),
      shortLabel: 'Users'),
  NavItem('Settings', Icons.settings_rounded, SettingsPage()),
];

/// Staff-only navigation — no administrative features exposed.
const List<NavItem> _staffNav = [
  NavItem('POS', Icons.point_of_sale_rounded, PosPage()),
  NavItem('Appointments', Icons.calendar_month_rounded, SchedulingPage(),
      shortLabel: 'Schedule'),
  NavItem('Client Records', Icons.people_alt_rounded, ClientRecordsPage(),
      shortLabel: 'Clients'),
];

/// Routes the user to the correct experience based on auth + role (RBAC):
/// not signed in → login; admin → admin dashboard; staff → staff dashboard.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (!auth.isSignedIn) {
      return const LoginScreen();
    }

    final isAdmin = auth.currentUser!.role == UserRole.admin;
    return DashboardShell(
      roleLabel: isAdmin ? 'Admin' : 'Staff',
      navItems: isAdmin ? _adminNav : _staffNav,
    );
  }
}
