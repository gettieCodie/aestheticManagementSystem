import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/firestore/store_errors.dart';
import '../models/appointment.dart';
import '../models/customer.dart';
import '../services/appointments_repository.dart';
import '../services/customers_repository.dart';

/// A client with an incomplete package (drives the Follow-Up Required list).
class FollowUpItem {
  FollowUpItem({
    required this.customer,
    required this.package,
    this.nextDate,
    this.appointmentId,
  });
  final Customer customer;
  final TreatmentPackage package;
  final DateTime? nextDate;

  /// The next open appointment for this package, if any — what "Log Call"
  /// records contact against. Null when no appointment is scheduled yet.
  final String? appointmentId;
}

/// Data carried from a completed appointment into the POS ("Proceed to
/// Payment"), so the client and service don't have to be re-entered.
class PendingCheckout {
  const PendingCheckout({
    required this.customerId,
    required this.customerName,
    required this.serviceName,
    this.appointmentDate,
    this.appointmentTime,
  });
  final String customerId;
  final String customerName;
  final String serviceName;

  /// The completed appointment's original date/time, so the sale it settles
  /// carries that alongside it.
  final DateTime? appointmentDate;
  final String? appointmentTime;
}

/// Store for staff data (clients, packages, sessions, appointments) — all
/// backed live by Firestore.
///
/// `customers`, `packages`, and `bookings` (-> appointments) are three
/// separate collections/streams; this store merges them client-side into
/// [Customer.packages] and [Customer.sessions] (sessions are derived from
/// completed bookings — see [_rebuildCustomers] — since the schema has no
/// separate sessions collection).
class StaffStore extends ChangeNotifier with FirestoreErrorTracker {
  StaffStore({
    AppointmentsRepository? appointmentsRepository,
    CustomersRepository? customersRepository,
  })  : _appointmentsRepo = appointmentsRepository ?? AppointmentsRepository(),
        _customersRepo = customersRepository ?? CustomersRepository() {
    _appointmentsSub = _appointmentsRepo.watchAppointments().listen((list) {
      clearStreamError('appointments');
      _appointments = list;
      _rebuildCustomers();
      notifyListeners();
    }, onError: (Object e) => reportStreamError('appointments', e));
    _customersSub = _customersRepo.watchCustomers().listen((list) {
      clearStreamError('customers');
      _customerBases = list;
      _rebuildCustomers();
      notifyListeners();
    }, onError: (Object e) => reportStreamError('customers', e));
    _packagesSub = _customersRepo.watchPackages().listen((list) {
      clearStreamError('packages');
      _packageRows = list;
      _rebuildCustomers();
      notifyListeners();
    }, onError: (Object e) => reportStreamError('packages', e));
  }

  final AppointmentsRepository _appointmentsRepo;
  final CustomersRepository _customersRepo;

  late final StreamSubscription<List<Appointment>> _appointmentsSub;
  late final StreamSubscription<List<Customer>> _customersSub;
  late final StreamSubscription<List<PackageRow>> _packagesSub;

  @override
  void dispose() {
    _appointmentsSub.cancel();
    _customersSub.cancel();
    _packagesSub.cancel();
    super.dispose();
  }

  // --- Customers -------------------------------------------------------------
  List<Customer> _customerBases = [];
  List<PackageRow> _packageRows = [];
  List<Customer> _customers = [];

  List<Customer> get customers => List.unmodifiable(_customers);

  /// Rebuilds [_customers] by attaching each base customer's packages (from
  /// [_packageRows]) and session history (derived from completed bookings in
  /// [_appointments]) whenever any of the three source streams changes.
  void _rebuildCustomers() {
    _customers = [
      for (final base in _customerBases)
        Customer(
          id: base.id,
          clientId: base.clientId,
          fullName: base.fullName,
          email: base.email,
          phone: base.phone,
          facebook: base.facebook,
          memberSince: base.memberSince,
          notes: base.notes,
          isActive: base.isActive,
          homeBranch: base.homeBranch,
          visitBranches: {
            for (final a in _appointments)
              if (a.customerId == base.id) a.branch,
          }.toList(),
          packages: [
            for (final row in _packageRows)
              if (row.customerId == base.id) row.package,
          ],
          sessions: [
            for (final a in _appointments)
              if (a.customerId == base.id && a.status == AppointmentStatus.completed)
                SessionRecord(
                  sessionNumber: a.sessionNumber ?? 0,
                  serviceName: a.serviceName,
                  date: a.date,
                  staffName: a.staffName,
                  productsUsed: a.productsUsed,
                  notes: a.notes,
                  photoCount: a.photoCount,
                  progressPhotos: a.progressPhotos,
                ),
          ]..sort((x, y) => y.date.compareTo(x.date)),
        ),
    ];
  }

  // --- POS hand-off -------------------------------------------------------
  PendingCheckout? _pendingCheckout;
  PendingCheckout? get pendingCheckout => _pendingCheckout;

  void setPendingCheckout(PendingCheckout checkout) {
    _pendingCheckout = checkout;
    notifyListeners();
  }

  void clearPendingCheckout() {
    _pendingCheckout = null;
  }

  Customer? customerById(String? id) {
    if (id == null) return null;
    for (final c in _customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Create a new client record directly in Firestore (`customer_NN` id).
  /// Returns the created customer immediately; it also appears in
  /// [customers] once the live stream picks it up.
  Future<Customer> addCustomer({
    required String fullName,
    required String phone,
    String email = '',
    String facebook = '',
    String notes = '',
    String? branch,
  }) {
    return _customersRepo.addCustomer(
      fullName: fullName,
      phone: phone,
      email: email,
      facebook: facebook,
      notes: notes,
      branchShortName: branch,
    );
  }

  /// Resolves the customer for [appt], creating one and backfilling the
  /// booking's `customerId` if it's a walk-in with none yet — otherwise the
  /// completed session would never show up on that customer's record (their
  /// "Last visit" would read empty even after they've paid for it).
  Future<String> resolveCustomerId(Appointment appt) async {
    final existing = appt.customerId;
    if (existing != null && existing.isNotEmpty) return existing;

    final created = await addCustomer(
      fullName: appt.customerName,
      phone: appt.phone ?? '',
      branch: appt.branch,
    );
    await _appointmentsRepo.setCustomerId(appt.id, created.id);
    return created.id;
  }

  /// Edit an existing client's contact details / notes.
  Future<void> updateCustomer(
    String id, {
    String? fullName,
    String? email,
    String? phone,
    String? facebook,
    String? notes,
  }) {
    return _customersRepo.updateCustomer(
      id,
      fullName: fullName,
      email: email,
      phone: phone,
      facebook: facebook,
      notes: notes,
    );
  }

  // --- Appointments ---------------------------------------------------------
  // Backed by Firestore's `bookings` collection — see [_appointmentsSub]
  // above, which keeps this in sync live with both apps.
  List<Appointment> _appointments = [];

  List<Appointment> get appointments => List.unmodifiable(_appointments);

  Appointment? _byId(String id) {
    for (final a in _appointments) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Count of active appointments in one branch/date/time (conflict detection).
  int concurrentCount(String branch, DateTime date, String time, {String? excludeId}) {
    final day = DateTime(date.year, date.month, date.day);
    return _appointments
        .where((a) =>
            a.id != excludeId &&
            a.branch == branch &&
            a.date == day &&
            a.time == time &&
            a.isOpen)
        .length;
  }

  /// Books a new appointment (walk-in or staff-scheduled) directly into
  /// Firestore. The new entry appears in [appointments] once the live stream
  /// picks it up (near-instant — Firestore reflects local writes before the
  /// server round-trip completes).
  Future<void> createAppointment({
    required String customerName,
    String? customerId,
    String? phone,
    required String serviceName,
    required String branch,
    required DateTime date,
    required String time,
    AppointmentStatus status = AppointmentStatus.confirmed,
  }) {
    return _appointmentsRepo.createAppointment(
      customerName: customerName,
      customerId: customerId,
      phone: phone,
      serviceName: serviceName,
      branchShortName: branch,
      date: date,
      time12h: time,
      status: status,
    );
  }

  String newId(String prefix) => '$prefix${DateTime.now().millisecondsSinceEpoch}';

  // --- Lifecycle transitions -----------------------------------------------
  // Each of these writes straight to the `bookings` doc in Firestore; the
  // live stream in the constructor reflects the change back into
  // [_appointments] and calls notifyListeners.
  Future<void> checkIn(String id) => _appointmentsRepo.checkIn(id);

  Future<void> markNoShow(String id) => _appointmentsRepo.markNoShow(id);

  Future<void> logContact(String id) => _appointmentsRepo.logContact(id);

  Future<void> cancel(String id, String reason) =>
      _appointmentsRepo.cancel(id, reason);

  /// Returns false if the new slot is at branch capacity (conflict) — in
  /// that case nothing is written.
  Future<bool> reschedule(
    String id,
    DateTime newDate,
    String newTime, {
    required int capacity,
  }) async {
    final a = _byId(id);
    if (a == null) return false;
    if (concurrentCount(a.branch, newDate, newTime, excludeId: id) >= capacity) {
      return false;
    }
    await _appointmentsRepo.reschedule(id, newDate, newTime);
    return true;
  }

  Future<void> confirm(String id) => _appointmentsRepo.confirm(id);

  /// Uploads a treatment progress photo and returns its download URL, ready
  /// to include in [complete]'s `progressPhotos`.
  Future<String> uploadTreatmentPhoto(Uint8List bytes, String fileName) =>
      _appointmentsRepo.uploadTreatmentPhoto(bytes, fileName);

  /// Completes an appointment: saves the treatment record to Firestore
  /// (which also drives [Customer.sessions] once the stream updates),
  /// advances the package's completed-session count in Firestore, and
  /// auto-proposes the next session if any remain. Returns the auto-created
  /// next appointment, if any.
  Future<Appointment?> complete(
    String id, {
    required List<String> productsUsed,
    required String notes,
    required List<String> progressPhotos,
    required bool isSensitive,
    required String staffName,
  }) async {
    final a = _byId(id);
    if (a == null) return null;

    await _appointmentsRepo.complete(
      id,
      productsUsed: productsUsed,
      notes: notes,
      progressPhotos: progressPhotos,
      isSensitive: isSensitive,
      staffName: staffName,
    );

    final customer = customerById(a.customerId);
    Appointment? next;
    if (customer != null && a.packageId != null) {
      final pkg = _packageOf(customer, a.packageId!);
      if (pkg != null) {
        await _customersRepo.incrementPackageCompletedSessions(pkg.id);
        final completedNow =
            pkg.completedSessions < pkg.totalSessions ? pkg.completedSessions + 1 : pkg.completedSessions;
        final sessionsLeft = pkg.totalSessions - completedNow;

        if (sessionsLeft > 0) {
          final nextDate = a.date.add(Duration(days: pkg.sessionIntervalDays));
          final nextSessionNumber = completedNow + 1;
          final nextId = await _appointmentsRepo.createAppointment(
            customerName: customer.fullName,
            customerId: customer.id,
            phone: customer.phone,
            serviceName: a.serviceName,
            branchShortName: a.branch,
            date: nextDate,
            time12h: a.time,
            status: AppointmentStatus.pending,
            packageId: pkg.id,
            packageName: pkg.name,
            sessionNumber: nextSessionNumber,
          );
          next = Appointment(
            id: nextId,
            customerId: customer.id,
            customerName: customer.fullName,
            serviceName: a.serviceName,
            branch: a.branch,
            date: nextDate,
            time: a.time,
            status: AppointmentStatus.pending,
            packageId: pkg.id,
            packageName: pkg.name,
            sessionNumber: nextSessionNumber,
          );
        }
      }
    }

    notifyListeners();
    return next;
  }

  TreatmentPackage? _packageOf(Customer c, String packageId) {
    for (final p in c.packages) {
      if (p.id == packageId) return p;
    }
    return null;
  }

  // --- Follow-ups (incomplete packages) ----------------------------------
  /// [branch] scopes results to a single branch (staff); `null` (admin)
  /// returns every branch's follow-ups.
  List<FollowUpItem> followUps({String? branch}) {
    final items = <FollowUpItem>[];
    for (final c in _customers) {
      if (!c.visibleTo(branch)) continue;
      for (final p in c.packages) {
        if (p.sessionsLeft <= 0) continue;
        final open = _appointments
            .where((a) => a.customerId == c.id && a.packageId == p.id && a.isOpen)
            .toList()
          ..sort((x, y) => x.date.compareTo(y.date));
        items.add(FollowUpItem(
          customer: c,
          package: p,
          nextDate: open.isNotEmpty ? open.first.date : null,
          appointmentId: open.isNotEmpty ? open.first.id : null,
        ));
      }
    }
    return items;
  }

  // --- Create a package (from POS) ---------------------------------------
  Future<void> createPackage({
    required String customerId,
    required String packageName,
    required int totalSessions,
    required double totalPrice,
    required double paidAmount,
    required String branch,
    required List<DateTime> sessionDates,
    required String defaultTime,
    required int sessionIntervalDays,
    String? invoiceId,
  }) async {
    final customer = customerById(customerId);
    if (customer == null) return;

    final pkg = await _customersRepo.createPackage(
      customerId: customer.id,
      name: packageName,
      totalSessions: totalSessions,
      totalPrice: totalPrice,
      paidAmount: paidAmount,
      sessionIntervalDays: sessionIntervalDays,
      invoiceId: invoiceId,
      branchShortName: branch,
    );

    for (int i = 0; i < sessionDates.length; i++) {
      await _appointmentsRepo.createAppointment(
        customerName: customer.fullName,
        customerId: customer.id,
        phone: customer.phone,
        serviceName: packageName,
        branchShortName: branch,
        date: sessionDates[i],
        time12h: defaultTime,
        status: AppointmentStatus.confirmed,
        packageId: pkg.id,
        packageName: packageName,
        sessionNumber: i + 1,
      );
    }
  }
}
