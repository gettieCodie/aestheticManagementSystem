import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme_controller.dart';
import '../core/utils/responsive.dart';
import '../features/auth/state/auth_controller.dart';
import 'nav_controller.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.page, {this.shortLabel});

  /// Full name, used by the sidebar and the app bar title.
  final String label;

  /// One word for the bottom bar, where a fifth of the width isn't enough for
  /// something like "User Management" without wrapping to two lines.
  final String? shortLabel;

  final IconData icon;
  final Widget page;

  String get barLabel => shortLabel ?? label;
}

/// The post-login application shell. Rendered separately for Admin and Staff —
/// each is given only its own [navItems], so neither role sees the other's
/// features. There is no role-switching here.
class DashboardShell extends StatefulWidget {
  const DashboardShell({
    super.key,
    required this.roleLabel,
    required this.navItems,
  });

  final String roleLabel;
  final List<NavItem> navItems;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  /// Lets the bottom bar's "More" destination open the drawer.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _select(int i) => context.read<NavController>().select(i);

  @override
  Widget build(BuildContext context) {
    // Index lives in NavController so pages can switch tabs programmatically.
    final rawIndex = context.watch<NavController>().index;
    final index = rawIndex < widget.navItems.length ? rawIndex : 0;

    // Cross-fade with a small upward drift when switching destinations. Keyed
    // by index so the switcher knows the child actually changed.
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      // The outgoing page is removed immediately rather than cross-faded on
      // top of the new one, which otherwise doubles scrollbars mid-transition.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(index),
        child: widget.navItems[index].page,
      ),
    );

    if (Responsive.isMobile(context)) {
      // Bottom nav holds up to 5 destinations. Anything past that is reached
      // from the drawer (the app bar's menu button) rather than a "More" tab.
      const maxTabs = 5;
      final tabs = widget.navItems.length > maxTabs
          ? widget.navItems.take(maxTabs).toList()
          : widget.navItems;
      final selectedTab = index < tabs.length ? index : 0;

      return Scaffold(
        appBar: AppBar(
          title: Text(widget.navItems[index].label),
          actions: const [_ThemeToggle()],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: _SidebarContent(
              roleLabel: widget.roleLabel,
              items: widget.navItems,
              index: index,
              onSelect: (i) {
                Navigator.pop(context);
                _select(i);
              },
            ),
          ),
        ),
        // Content flows under the floating bar so it appears to hover.
        extendBody: true,
        body: body,
        bottomNavigationBar: _FloatingNavBar(
          selectedIndex: selectedTab,
          onSelected: _select,
          destinations: [
            for (final item in tabs)
              NavigationDestination(
                  icon: Icon(item.icon), label: item.barLabel),
          ],
        ),
        key: _scaffoldKey,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 248,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: _SidebarContent(
                roleLabel: widget.roleLabel,
                items: widget.navItems,
                index: index,
                onSelect: _select,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Bottom navigation rendered as a detached, rounded bar that hovers over the
/// content instead of sitting flush against the screen edge.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBarTheme(
              // Small, single-line labels. The default body-size label is too
              // large once five destinations share a phone's width.
              data: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: states.contains(WidgetState.selected)
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: 22,
                    color: states.contains(WidgetState.selected)
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                destinations: destinations,
                // The wrapper supplies the surface, shadow and shape.
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                height: 64,
                indicatorColor: scheme.primary.withValues(alpha: 0.15),
                // Always visible: with onlyShowSelected the bar's contents
                // shifted on every tap, which reads as unstable.
                labelBehavior:
                    NavigationDestinationLabelBehavior.alwaysShow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.roleLabel,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  final String roleLabel;
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthController>().currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.spa_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Luxi',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('$roleLabel Dashboard',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (user != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0] : '?',
                      style: TextStyle(
                          color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(user.branch ?? 'All branches',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (int i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: i == index
                        ? scheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(items[i].icon,
                                size: 20,
                                color: i == index
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Text(
                              items[i].label,
                              style: TextStyle(
                                fontWeight:
                                    i == index ? FontWeight.w700 : FontWeight.w500,
                                color: i == index ? scheme.primary : scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        const _ThemeToggle(labelled: true),
        ListTile(
          leading: Icon(Icons.logout_rounded, size: 20, color: scheme.error),
          title: Text('Sign out', style: TextStyle(color: scheme.error)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: () => context.read<AuthController>().logout(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({this.labelled = false});
  final bool labelled;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final icon = controller.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    if (!labelled) {
      return IconButton(onPressed: controller.toggle, icon: Icon(icon));
    }
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(controller.isDark ? 'Light mode' : 'Dark mode'),
      onTap: controller.toggle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
