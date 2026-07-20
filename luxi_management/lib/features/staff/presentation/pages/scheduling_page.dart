import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../app/nav_controller.dart';
import '../../../admin/models/product.dart' show kBranches;
import '../../../admin/models/service_config.dart';
import '../../../admin/presentation/pages/page_scaffold.dart';
import '../../../admin/presentation/widgets/section_card.dart';
import '../../../admin/state/admin_store.dart';
import '../../../auth/state/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/customer.dart';
import '../../state/staff_store.dart';

/// Clinic time slots (9:00 AM – 4:00 PM, every 30 min).
const List<String> kTimeSlots = [
  '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
  '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
  '3:00 PM', '3:30 PM', '4:00 PM',
];

const int kBranchCapacity = 2; // 2 staff per branch

enum _View { daily, followUp }

class SchedulingPage extends StatefulWidget {
  const SchedulingPage({super.key});

  @override
  State<SchedulingPage> createState() => _SchedulingPageState();
}

class _SchedulingPageState extends State<SchedulingPage> {
  _View _view = _View.daily;
  DateTime _selected = _today;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String? _branchScope(BuildContext context) =>
      context.watch<AuthController>().currentUser?.branch;

  @override
  Widget build(BuildContext context) {
    // Phones get a purpose-built layout; desktop keeps the table-style view.
    if (Responsive.isMobile(context)) return const MobileSchedulePage();

    final store = context.watch<StaffStore>();
    final branch = _branchScope(context);
    final followUps = store.followUps();

    return AdminPageScaffold(
      title: 'Appointment & Scheduling',
      subtitle: 'Manage client appointments and treatments',
      children: [
        SegmentedButton<_View>(
          segments: [
            const ButtonSegment(value: _View.daily, label: Text('Daily View')),
            ButtonSegment(
                value: _View.followUp,
                label: Text('Follow-Up (${followUps.length})')),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
        const SizedBox(height: 16),
        if (_view == _View.daily)
          _dailyView(context, store, branch)
        else
          _followUpView(context, store, followUps),
      ],
    );
  }

  // --- Daily view ---------------------------------------------------------
  Widget _dailyView(BuildContext context, StaffStore store, String? branch) {
    final scheme = Theme.of(context).colorScheme;
    final visible = store.appointments
        .where((a) =>
            a.date == _selected && (branch == null || a.branch == branch))
        .toList()
      ..sort((x, y) =>
          kTimeSlots.indexOf(x.time).compareTo(kTimeSlots.indexOf(y.time)));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateHeading(_selected),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${visible.length} appointment(s) scheduled',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton.outlined(
                onPressed: () => setState(
                    () => _selected = _selected.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () =>
                    setState(() => _selected = _selected.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _NewAppointmentDialog(),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Appointment'),
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No appointments for this day.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        for (final a in visible) _AppointmentCard(appointment: a),
      ],
    );
  }

  String _dateHeading(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${Formatters.date(d)}';
  }

  // --- Follow-up view -----------------------------------------------------
  Widget _followUpView(
      BuildContext context, StaffStore store, List<FollowUpItem> items) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Follow-Up Required',
      icon: Icons.notifications_active_rounded,
      child: items.isEmpty
          ? Text('No incomplete packages. ',
              style: TextStyle(color: scheme.onSurfaceVariant))
          : Column(
              children: [
                for (final item in items) _FollowUpRow(item: item),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});
  final Appointment appointment;

  int? _totalSessions(StaffStore store) {
    if (appointment.packageId == null) return null;
    final c = store.customerById(appointment.customerId);
    if (c == null) return null;
    for (final p in c.packages) {
      if (p.id == appointment.packageId) return p.totalSessions;
    }
    return null;
  }

  String? _phoneOf(StaffStore store, Appointment a) {
    if (a.phone != null && a.phone!.isNotEmpty) return a.phone;
    return store.customerById(a.customerId)?.phone;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.read<StaffStore>();
    final a = appointment;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Responsive.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _details(context, a, store, scheme),
                const SizedBox(height: 12),
                _actions(context, a, fullWidth: true),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _details(context, a, store, scheme)),
                _actions(context, a),
              ],
            ),
    );
  }

  /// The client / service / time block, shared by both layouts.
  Widget _details(
      BuildContext context, Appointment a, StaffStore store, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(a.customerName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            _StatusBadge(status: a.status),
          ],
        ),
        const SizedBox(height: 8),
        _line(context, Icons.medical_services_outlined,
            a.sessionLabel(_totalSessions(store))),
        if (_phoneOf(store, a) != null)
          _line(context, Icons.phone_outlined, _phoneOf(store, a)!),
        _line(context, Icons.schedule_rounded, a.time),
        _line(context, Icons.location_on_outlined, '${a.branch} Branch'),
        if (a.status == AppointmentStatus.cancelled && a.cancelReason != null)
          _line(context, Icons.info_outline, 'Cancelled: ${a.cancelReason}',
              color: scheme.error),
        if (a.lastContactedAt != null)
          _line(context, Icons.call_made_rounded,
              'Contacted ${Formatters.date(a.lastContactedAt!)}',
              color: scheme.primary),
      ],
    );
  }

  Widget _line(BuildContext context, IconData icon, String text, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: color ?? scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: color ?? scheme.onSurfaceVariant)),
        ),
      ]),
    );
  }

  Widget _actions(BuildContext context, Appointment a, {bool fullWidth = false}) {
    final store = context.read<StaffStore>();
    if (!a.isOpen) {
      return const SizedBox.shrink();
    }

    final primary = a.status == AppointmentStatus.pending
        ? OutlinedButton(
            onPressed: () => store.confirm(a.id),
            child: const Text('Confirm'),
          )
        : FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _TreatmentRecordDialog(appointment: a),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Complete'),
          );

    final overflow = PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) => _onMenu(context, a, v),
      itemBuilder: (_) => [
        if (a.status == AppointmentStatus.confirmed)
          const PopupMenuItem(value: 'checkin', child: Text('Check in (Arrived)')),
        const PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
        const PopupMenuItem(value: 'call', child: Text('Log call')),
        if (a.status != AppointmentStatus.pending)
          const PopupMenuItem(value: 'noshow', child: Text('Mark no-show')),
        const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
      ],
    );

    // On phones the primary action spans the card with the ⋯ menu beside it.
    if (fullWidth) {
      return Row(
        children: [
          Expanded(child: primary),
          overflow,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [primary, overflow],
    );
  }

  void _onMenu(BuildContext context, Appointment a, String action) {
    final store = context.read<StaffStore>();
    switch (action) {
      case 'checkin':
        store.checkIn(a.id);
      case 'call':
        store.logContact(a.id);
        AppToast.success(context, 'Call logged.');
      case 'noshow':
        store.markNoShow(a.id);
      case 'reschedule':
        showDialog<void>(
            context: context, builder: (_) => _RescheduleDialog(appointment: a));
      case 'cancel':
        showDialog<void>(
            context: context, builder: (_) => _CancelDialog(appointment: a));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: status.color)),
    );
  }
}

// ---------------------------------------------------------------------------
class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({required this.item});
  final FollowUpItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = item.package;
    final nextSession = p.completedSessions + 1;
    final chip = _dueChip(item.nextDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Responsive.isMobile(context)
          ? _mobileLayout(context, scheme, p, nextSession, chip)
          : Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.customer.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(item.customer.phone,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${p.name} (Session $nextSession of ${p.totalSessions})',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.nextDate != null ? Formatters.date(item.nextDate!) : 'Not scheduled',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chip.$2.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(chip.$1,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: chip.$2)),
          ),
          const SizedBox(width: 8),
          _logCallButton(context),
        ],
      ),
    );
  }

  /// Stacked card for phones — nothing competes for horizontal space.
  Widget _mobileLayout(BuildContext context, ColorScheme scheme,
      TreatmentPackage p, int nextSession, (String, Color) chip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(item.customer.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chip.$2.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(chip.$1,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: chip.$2)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(item.customer.phone,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text('${p.name} (Session $nextSession of ${p.totalSessions})',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          item.nextDate != null
              ? 'Next: ${Formatters.date(item.nextDate!)}'
              : 'Not scheduled',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerLeft, child: _logCallButton(context)),
      ],
    );
  }

  Widget _logCallButton(BuildContext context) {
    return TextButton.icon(
      onPressed: item.appointmentId == null
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context.read<StaffStore>().logContact(item.appointmentId!);
                AppToast.successOn(messenger, 'Logged a call to ${item.customer.fullName}.');
              } catch (e) {
                AppToast.errorOn(messenger, 'Could not log call: $e');
              }
            },
      icon: const Icon(Icons.call_outlined, size: 16),
      label: const Text('Log Call'),
    );
  }

  (String, Color) _dueChip(DateTime? date) {
    const today = Color(0xFFE0A800);
    const due = Color(0xFFC5A037);
    const pending = Color(0xFF6B7280);
    if (date == null) return ('Pending', pending);
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    final diff = date.difference(t).inDays;
    if (diff <= 0) return ('Today', today);
    if (diff == 1) return ('Tomorrow', today);
    if (diff <= 7) return ('Due Soon', due);
    return ('Pending', pending);
  }
}

// ===========================================================================
// MOBILE
// ===========================================================================

enum _MobileTab { day, week, month, followUp }

extension on _MobileTab {
  String get label => switch (this) {
        _MobileTab.day => 'Day',
        _MobileTab.week => 'Week',
        _MobileTab.month => 'Month',
        _MobileTab.followUp => 'Follow-Up',
      };
}

/// Phone layout for Appointments — Day / Week / Month / Follow-Up.
///
/// Shares all state and dialogs with the desktop view; only the presentation
/// differs, so behaviour (capacity checks, completion, cancellation) is
/// identical on both.
class MobileSchedulePage extends StatefulWidget {
  const MobileSchedulePage({super.key});

  @override
  State<MobileSchedulePage> createState() => _MobileSchedulePageState();
}

class _MobileSchedulePageState extends State<MobileSchedulePage> {
  _MobileTab _tab = _MobileTab.day;
  DateTime _selected = _todayOnly;

  static DateTime get _todayOnly {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<StaffStore>();
    final branch = context.watch<AuthController>().currentUser?.branch;
    final followUps = store.followUps();

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Lifted clear of the floating navigation bar.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 78),
        child: FloatingActionButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const _NewAppointmentDialog(),
          ),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: const Icon(Icons.add_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
        children: [
          Text('Schedule',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _tabBar(scheme, followUps.isNotEmpty),
          const SizedBox(height: 16),
          ..._tabBody(store, branch, followUps, scheme),
        ],
      ),
    );
  }

  List<Widget> _tabBody(StaffStore store, String? branch,
      List<FollowUpItem> followUps, ColorScheme scheme) {
    switch (_tab) {
      case _MobileTab.day:
        return [
          _dateStrip(scheme),
          const SizedBox(height: 16),
          ..._cardsFor(_appointmentsOn(store, branch, _selected), scheme),
        ];

      case _MobileTab.week:
        final start = _selected.subtract(Duration(days: _selected.weekday - 1));
        return [
          _rangeHeader(
              scheme,
              '${Formatters.date(start)} – '
              '${Formatters.date(start.add(const Duration(days: 6)))}',
              onPrev: () => setState(
                  () => _selected = _selected.subtract(const Duration(days: 7))),
              onNext: () => setState(
                  () => _selected = _selected.add(const Duration(days: 7)))),
          const SizedBox(height: 16),
          for (int i = 0; i < 7; i++)
            ..._daySection(store, branch, start.add(Duration(days: i)), scheme),
        ];

      case _MobileTab.month:
        return [
          _rangeHeader(scheme, _monthLabel(_selected),
              onPrev: () => setState(() =>
                  _selected = DateTime(_selected.year, _selected.month - 1, 1)),
              onNext: () => setState(() =>
                  _selected = DateTime(_selected.year, _selected.month + 1, 1))),
          const SizedBox(height: 12),
          _monthGrid(store, branch, scheme),
          const SizedBox(height: 16),
          ..._cardsFor(_appointmentsOn(store, branch, _selected), scheme),
        ];

      case _MobileTab.followUp:
        if (followUps.isEmpty) return [_empty('No follow-ups pending.', scheme)];
        return [for (final f in followUps) _FollowUpRow(item: f)];
    }
  }

  // --- Chrome -------------------------------------------------------------
  Widget _tabBar(ColorScheme scheme, bool hasFollowUps) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final t in _MobileTab.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = t),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _tab == t ? scheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: _tab == t
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          t.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                _tab == t ? FontWeight.w700 : FontWeight.w500,
                            color: _tab == t
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (t == _MobileTab.followUp && hasFollowUps) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE05252),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Horizontal Mon 27 / Tue 28 / … strip, centred on the selected day.
  Widget _dateStrip(ColorScheme scheme) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final start = _selected.subtract(const Duration(days: 2));
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = start.add(Duration(days: i));
          final isSelected = _dayOnly(d) == _dayOnly(_selected);
          return GestureDetector(
            onTap: () => setState(() => _selected = _dayOnly(d)),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isSelected
                    ? null
                    : Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.7)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(names[d.weekday - 1],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? scheme.onPrimary.withValues(alpha: 0.85)
                            : scheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 3),
                  Text('${d.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color:
                            isSelected ? scheme.onPrimary : scheme.onSurface,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _rangeHeader(ColorScheme scheme, String label,
      {required VoidCallback onPrev, required VoidCallback onNext}) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        IconButton(
            onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(
            onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }

  Widget _monthGrid(StaffStore store, String? branch, ColorScheme scheme) {
    final first = DateTime(_selected.year, _selected.month, 1);
    final daysInMonth = DateTime(_selected.year, _selected.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-first
    final cells = leading + daysInMonth;
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: [
            for (final n in names)
              Expanded(
                child: Center(
                  child: Text(n,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) {
            if (i < leading) return const SizedBox.shrink();
            final d = DateTime(_selected.year, _selected.month, i - leading + 1);
            final isSelected = _dayOnly(d) == _dayOnly(_selected);
            final count = _appointmentsOn(store, branch, d).length;
            return GestureDetector(
              onTap: () => setState(() => _selected = d),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${d.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        )),
                    const SizedBox(height: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: count == 0
                            ? Colors.transparent
                            : isSelected
                                ? scheme.onPrimary
                                : scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- Content ------------------------------------------------------------
  List<Appointment> _appointmentsOn(
      StaffStore store, String? branch, DateTime day) {
    final d = _dayOnly(day);
    return store.appointments
        .where((a) => _dayOnly(a.date) == d && (branch == null || a.branch == branch))
        .toList()
      ..sort((x, y) =>
          kTimeSlots.indexOf(x.time).compareTo(kTimeSlots.indexOf(y.time)));
  }

  List<Widget> _daySection(
      StaffStore store, String? branch, DateTime day, ColorScheme scheme) {
    final items = _appointmentsOn(store, branch, day);
    if (items.isEmpty) return const [];
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('${names[day.weekday - 1]}, ${Formatters.date(day)}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant)),
      ),
      ..._cardsFor(items, scheme),
      const SizedBox(height: 4),
    ];
  }

  List<Widget> _cardsFor(List<Appointment> items, ColorScheme scheme) {
    if (items.isEmpty) {
      return [_empty('No appointments for this day.', scheme)];
    }
    return [for (final a in items) _MobileAppointmentCard(appointment: a)];
  }

  Widget _empty(String text, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(text,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ),
      );

  String _monthLabel(DateTime d) {
    const m = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${m[d.month - 1]} ${d.year}';
  }
}

/// Appointment card for phones: name + status, one meta line, three actions.
class _MobileAppointmentCard extends StatelessWidget {
  const _MobileAppointmentCard({required this.appointment});
  final Appointment appointment;

  int? _totalSessions(StaffStore store) {
    if (appointment.packageId == null) return null;
    final c = store.customerById(appointment.customerId);
    if (c == null) return null;
    for (final p in c.packages) {
      if (p.id == appointment.packageId) return p.totalSessions;
    }
    return null;
  }

  /// Design uses a single "Scheduled" pill for anything not yet handled.
  (String, Color, Color) _badge(AppointmentStatus s, ColorScheme scheme) {
    switch (s) {
      case AppointmentStatus.pending:
      case AppointmentStatus.confirmed:
        return ('Scheduled', const Color(0xFFEAF1FD), const Color(0xFF3B6FD4));
      case AppointmentStatus.completed:
        return ('Completed', const Color(0xFFE6F4EA), const Color(0xFF2E7D46));
      case AppointmentStatus.cancelled:
        return ('Cancelled', scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
      default:
        return (
          s.label,
          s.color.withValues(alpha: 0.14),
          s.color,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.read<StaffStore>();
    final a = appointment;
    final (label, bg, fg) = _badge(a.status, scheme);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${a.time} · ${a.sessionLabel(_totalSessions(store))}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary)),
          if (a.status == AppointmentStatus.cancelled && a.cancelReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Cancelled: ${a.cancelReason}',
                  style: TextStyle(fontSize: 12, color: scheme.error)),
            ),
          if (a.isOpen) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 40,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _primaryAction(context, a, store),
                      child: Text(
                        a.status == AppointmentStatus.pending
                            ? 'Confirm'
                            : 'Complete',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _RescheduleDialog(appointment: a),
                      ),
                      child: const Text('Reschedule',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: scheme.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _moreActions(context, a, store),
                    child: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _primaryAction(BuildContext context, Appointment a, StaffStore store) {
    if (a.status == AppointmentStatus.pending) {
      store.confirm(a.id);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => _TreatmentRecordDialog(appointment: a),
    );
  }

  /// The ✕ opens Cancel plus the less-common actions that have no room on a
  /// phone card (check-in, log call, no-show).
  void _moreActions(BuildContext context, Appointment a, StaffStore store) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a.status == AppointmentStatus.confirmed)
              ListTile(
                leading: const Icon(Icons.how_to_reg_rounded),
                title: const Text('Check in (Arrived)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  store.checkIn(a.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Log call'),
              onTap: () {
                Navigator.pop(sheetContext);
                store.logContact(a.id);
              },
            ),
            if (a.status != AppointmentStatus.pending)
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Mark no-show'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  store.markNoShow(a.id);
                },
              ),
            ListTile(
              leading: Icon(Icons.close_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Cancel appointment',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                showDialog<void>(
                  context: context,
                  builder: (_) => _CancelDialog(appointment: a),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// --- Dialogs ---------------------------------------------------------------
class _TreatmentRecordDialog extends StatefulWidget {
  const _TreatmentRecordDialog({required this.appointment});
  final Appointment appointment;

  @override
  State<_TreatmentRecordDialog> createState() => _TreatmentRecordDialogState();
}

class _TreatmentRecordDialogState extends State<_TreatmentRecordDialog> {
  final _notes = TextEditingController();
  final Set<String> _products = {};
  final List<String> _photoUrls = [];
  bool _uploadingPhoto = false;
  bool _sensitive = false;
  bool _consent = false;

  // Standalone (non-package) appointments proceed to payment in the POS.
  ServiceConfig? _chargeService;

  bool get _isPackage => widget.appointment.packageId != null;

  @override
  void initState() {
    super.initState();
    if (!_isPackage) {
      // Prefill the charge with the booked service, if it matches the menu.
      final services = context.read<AdminStore>().services;
      for (final s in services) {
        if (s.name.toLowerCase() == widget.appointment.serviceName.toLowerCase()) {
          _chargeService = s;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await context
          .read<StaffStore>()
          .uploadTreatmentPhoto(bytes, picked.name);
      if (mounted) setState(() => _photoUrls.add(url));
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not upload photo: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    // Consent gates the PHOTOS, not the clinical note.
    if (_photoUrls.isNotEmpty && !_consent) {
      AppToast.error(context, 'Client consent is required to save photos.');
      return;
    }
    // Standalone appointments must confirm the service before payment.
    if (!_isPackage && _chargeService == null) {
      AppToast.error(context, 'Select the service performed to proceed.');
      return;
    }

    // Capture everything that needs `context` BEFORE any await, so nothing
    // touches a possibly-unmounted context afterwards.
    final staffName =
        context.read<AuthController>().currentUser?.fullName ?? 'Staff';
    final store = context.read<StaffStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navController = context.read<NavController>();
    final appt = widget.appointment;

    // 1. Record the treatment (marks the appointment completed).
    final next = await store.complete(
      appt.id,
      productsUsed: _products.toList(),
      notes: _notes.text.trim(),
      progressPhotos: _consent ? _photoUrls : [],
      isSensitive: _sensitive,
      staffName: staffName,
    );

    if (_isPackage) {
      // Already paid via the package — no checkout.
      navigator.pop();
      AppToast.successOn(
          messenger,
          next == null
              ? 'Treatment record saved.'
              : 'Saved. Next session proposed for '
                  '${Formatters.date(next.date)}.');
      return;
    }

    // 2. Standalone → hand off to POS with client + service prefilled.
    var customerId = appt.customerId ?? '';
    if (customerId.isEmpty) {
      // Walk-in: turn them into a client record so POS has a customer.
      final created = await store.addCustomer(
        fullName: appt.customerName,
        phone: appt.phone ?? '',
      );
      customerId = created.id;
    }
    store.setPendingCheckout(PendingCheckout(
      customerId: customerId,
      customerName: appt.customerName,
      serviceName: _chargeService!.name,
    ));

    // 3. Close the dialog, then jump to the POS tab (index 0 for staff).
    navigator.pop();
    navController.select(0);
    AppToast.successOn(messenger, 'Record saved — finalize payment in POS.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final products = context.read<AdminStore>().products;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Complete Treatment Record'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Service Performed'),
              if (_isPackage)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(widget.appointment.serviceName)),
                    Text('Package — already paid',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ]),
                )
              else ...[
                InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Confirm service to bill', isDense: true),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ServiceConfig>(
                      value: _chargeService,
                      isExpanded: true,
                      hint: const Text('Select service'),
                      items: [
                        for (final s in context.read<AdminStore>().services)
                          DropdownMenuItem(
                              value: s,
                              child: Text('${s.name} · ${Formatters.peso(s.price)}')),
                      ],
                      onChanged: (v) => setState(() => _chargeService = v),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Saving opens the POS with this client and service ready '
                    'for pricing and payment.',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 14),
              _label('Products Used'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final p in products)
                    FilterChip(
                      label: Text(p.name),
                      selected: _products.contains(p.name),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _products.add(p.name);
                        } else {
                          _products.remove(p.name);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _label('Treatment Notes'),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Client response, recommendations…'),
              ),
              const SizedBox(height: 14),
              _label('Progress Photos'),
              OutlinedButton.icon(
                onPressed: _uploadingPhoto ? null : _addPhoto,
                icon: _uploadingPhoto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(_uploadingPhoto
                    ? 'Uploading…'
                    : _photoUrls.isEmpty
                        ? 'Add photo (watermarked)'
                        : '${_photoUrls.length} photo(s) added'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _sensitive,
                onChanged: (v) => setState(() => _sensitive = v),
                title: const Text('Mark as sensitive'),
                subtitle: const Text('Blurred by default; explicit access required'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                title: const Text('Client consent obtained for photos'),
                subtitle: const Text('Required only to save photos'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(_isPackage ? Icons.check_rounded : Icons.arrow_forward_rounded),
          label: Text(_isPackage ? 'Save Record' : 'Proceed to Payment'),
        ),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.appointment});
  final Appointment appointment;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  late DateTime _date = widget.appointment.date;
  late String _time = widget.appointment.time;

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Reschedule Appointment'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${a.customerName}'),
            Text('Service: ${a.serviceName}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'New date'),
                child: Text(Formatters.date(_date)),
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'New time', isDense: true),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _time,
                  isExpanded: true,
                  items: [
                    for (final t in kTimeSlots)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _time = v ?? _time),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final store = context.read<StaffStore>();
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final ok = await store.reschedule(
                a.id, _date, _time, capacity: kBranchCapacity);
            if (!ok) {
              AppToast.errorOn(messenger,
                  '$_time is full at ${a.branch}. Pick another slot.');
              return;
            }
            navigator.pop();
            AppToast.successOn(
                messenger,
                'Moved ${a.customerName} to $_time, '
                '${Formatters.date(_date)}.');
          },
          child: const Text('Confirm Reschedule'),
        ),
      ],
    );
  }
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.appointment});
  final Appointment appointment;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Cancel Appointment'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _reason,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Client request, illness, conflict…',
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await context.read<StaffStore>().cancel(
                  widget.appointment.id,
                  _reason.text.trim().isEmpty ? 'No reason given' : _reason.text.trim());
              navigator.pop();
              AppToast.successOn(messenger,
                  '${widget.appointment.customerName}\'s appointment cancelled.');
            } catch (e) {
              AppToast.errorOn(messenger, 'Could not cancel: $e');
            }
          },
          child: const Text('Cancel Appointment'),
        ),
      ],
    );
  }
}

class _NewAppointmentDialog extends StatefulWidget {
  const _NewAppointmentDialog();

  @override
  State<_NewAppointmentDialog> createState() => _NewAppointmentDialogState();
}

class _NewAppointmentDialogState extends State<_NewAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _service = TextEditingController();
  String _branch = kBranches.first;
  bool _lockedBranch = false;
  String _time = kTimeSlots.first;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final b = context.read<AuthController>().currentUser?.branch;
    if (b != null) {
      _branch = b;
      _lockedBranch = true;
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    _phone.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppToast.error(context, 'Please fix the highlighted fields.');
      return;
    }
    final store = context.read<StaffStore>();
    final day = DateTime(_date.year, _date.month, _date.day);

    if (store.concurrentCount(_branch, day, _time) >= kBranchCapacity) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Slot unavailable'),
          content: Text('$_branch is fully booked at $_time on '
              '${Formatters.date(day)}. Pick another time.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.createAppointment(
        customerName: _customer.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        serviceName: _service.text.trim(),
        branch: _branch,
        date: day,
        time: _time,
        status: AppointmentStatus.confirmed,
      );
      navigator.pop();
      AppToast.successOn(
          messenger,
          'Booked ${_customer.text.trim()} — $_time, '
          '${Formatters.date(day)}.');
    } catch (e) {
      AppToast.errorOn(messenger, 'Could not book appointment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('New Appointment'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _customer,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Client name', prefixIcon: Icon(Icons.person_outline)),
                validator:
                    Validate.all([Validate.required, Validate.minLength(2)]),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Contact number', prefixIcon: Icon(Icons.phone_outlined)),
                validator: Validate.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _service,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Service', prefixIcon: Icon(Icons.medical_services_outlined)),
                validator:
                    Validate.all([Validate.required, Validate.minLength(2)]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _lockedBranch
                      ? InputDecorator(
                          decoration: const InputDecoration(
                              labelText: 'Branch', isDense: true),
                          child: Text(_branch),
                        )
                      : _dropdown('Branch', _branch, kBranches,
                          (v) => setState(() => _branch = v)),
                ),
                const SizedBox(width: 12),
                Expanded(child: _dropdown('Time', _time, kTimeSlots,
                    (v) => setState(() => _time = v))),
              ]),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 120)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(Formatters.date(_date)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Book')),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
          ],
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }
}
