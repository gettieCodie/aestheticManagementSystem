import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/customer.dart';

/// A client with an incomplete package (drives the Follow-Up Required list).
class FollowUpItem {
  FollowUpItem({required this.customer, required this.package, this.nextDate});
  final Customer customer;
  final TreatmentPackage package;
  final DateTime? nextDate;
}

/// Data carried from a completed appointment into the POS ("Proceed to
/// Payment"), so the client and service don't have to be re-entered.
class PendingCheckout {
  const PendingCheckout({
    required this.customerId,
    required this.customerName,
    required this.serviceName,
  });
  final String customerId;
  final String customerName;
  final String serviceName;
}

/// In-memory store for staff data (clients, packages, sessions, appointments).
///
/// Firebase seam: swap the seeded lists and mutations for Firestore. The
/// lifecycle methods below mirror the atomic operations in the schema doc.
class StaffStore extends ChangeNotifier {
  final List<Customer> _customers = [
    Customer(
      id: 'c1', clientId: 'LUX-2024-001', fullName: 'Maria Santos',
      email: 'maria.santos@gmail.com', phone: '0917-123-4567',
      facebook: 'facebook.com/maria.santos', memberSince: DateTime(2024, 1, 15),
      packages: [
        TreatmentPackage(id: 'pk1', name: 'Skin Rejuvenation Package',
            totalSessions: 6, completedSessions: 4, totalPrice: 17500,
            paidAmount: 8750, sessionIntervalDays: 7),
      ],
      sessions: [
        SessionRecord(sessionNumber: 4, serviceName: 'Skin Rejuvenation',
            date: DateTime(2026, 4, 21), staffName: 'Angela Cruz',
            productsUsed: ['Vitamin C Serum', 'Retinol Night Cream'],
            notes: 'Excellent progress, skin tone improved significantly', photoCount: 2),
        SessionRecord(sessionNumber: 3, serviceName: 'Skin Rejuvenation',
            date: DateTime(2026, 4, 14), staffName: 'Angela Cruz',
            productsUsed: ['Vitamin C Serum'], notes: 'Client very satisfied'),
      ],
    ),
    Customer(
      id: 'c2', clientId: 'LUX-2024-014', fullName: 'Carlos Ramos',
      email: 'carlos.ramos@gmail.com', phone: '0918-234-5678',
      facebook: 'facebook.com/carlos.ramos', memberSince: DateTime(2024, 6, 3),
      packages: [
        TreatmentPackage(id: 'pk2', name: 'Diamond Peel Package',
            totalSessions: 5, completedSessions: 5, totalPrice: 15000, paidAmount: 15000),
      ],
    ),
    Customer(
      id: 'c3', clientId: 'LUX-2025-088', fullName: 'Ana Reyes',
      email: 'ana.reyes@gmail.com', phone: '0920-555-7788',
      facebook: 'facebook.com/ana.reyes', memberSince: DateTime(2025, 2, 20),
      packages: [
        TreatmentPackage(id: 'pk3', name: 'Acne Treatment Package',
            totalSessions: 6, completedSessions: 2, totalPrice: 9000,
            paidAmount: 4500, sessionIntervalDays: 7),
      ],
    ),
  ];

  List<Customer> get customers => List.unmodifiable(_customers);

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

  int _clientSeq = 100;

  String _nextClientId() {
    _clientSeq++;
    return 'LUX-${DateTime.now().year}-${_clientSeq.toString().padLeft(3, '0')}';
  }

  /// Create a new client record. Returns the created customer.
  Customer addCustomer({
    required String fullName,
    required String phone,
    String email = '',
    String facebook = '',
    String notes = '',
  }) {
    final customer = Customer(
      id: newId('c'),
      clientId: _nextClientId(),
      fullName: fullName,
      email: email,
      phone: phone,
      facebook: facebook,
      notes: notes,
      memberSince: DateTime.now(),
    );
    _customers.add(customer);
    notifyListeners();
    return customer;
  }

  /// Edit an existing client's contact details / notes in place.
  void updateCustomer(
    String id, {
    String? fullName,
    String? email,
    String? phone,
    String? facebook,
    String? notes,
  }) {
    final c = customerById(id);
    if (c == null) return;
    if (fullName != null) c.fullName = fullName;
    if (email != null) c.email = email;
    if (phone != null) c.phone = phone;
    if (facebook != null) c.facebook = facebook;
    if (notes != null) c.notes = notes;
    notifyListeners();
  }

  // --- Appointments -------------------------------------------------------
  final List<Appointment> _appointments = [
    Appointment(id: 'a1', customerId: 'c1', customerName: 'Maria Santos',
        serviceName: 'Skin Rejuvenation', branch: 'Laguna', date: _today,
        time: '9:00 AM', status: AppointmentStatus.confirmed,
        packageId: 'pk1', packageName: 'Skin Rejuvenation Package', sessionNumber: 5),
    Appointment(id: 'a2', customerName: 'Elena Martinez', phone: '0917-555-2210',
        serviceName: 'HydraFacial',
        branch: 'Laguna', date: _today, time: '11:30 AM', status: AppointmentStatus.pending),
    Appointment(id: 'a3', customerId: 'c2', customerName: 'Carlos Ramos',
        serviceName: 'Diamond Peel', branch: 'Laguna', date: _today, time: '2:00 PM',
        status: AppointmentStatus.confirmed),
    Appointment(id: 'a6', customerName: 'Diego Lopez', phone: '0918-777-3040',
        serviceName: 'Whitening Facial',
        branch: 'Laguna', date: _today, time: '1:00 PM', status: AppointmentStatus.completed),
    Appointment(id: 'a4', customerId: 'c3', customerName: 'Ana Reyes',
        serviceName: 'Acne Treatment', branch: 'Laguna', date: _tomorrow, time: '9:00 AM',
        status: AppointmentStatus.confirmed, packageId: 'pk3',
        packageName: 'Acne Treatment Package', sessionNumber: 3),
    Appointment(id: 'a5', customerName: 'Isabella Morales', phone: '0927-123-4567',
        serviceName: 'Whitening Facial',
        branch: 'Laguna', date: _tomorrow, time: '1:00 PM', status: AppointmentStatus.pending),
  ];

  List<Appointment> get appointments => List.unmodifiable(_appointments);

  Appointment? _byId(String id) {
    for (final a in _appointments) {
      if (a.id == id) return a;
    }
    return null;
  }

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime get _tomorrow => _today.add(const Duration(days: 1));

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

  void addAppointment(Appointment appointment) {
    _appointments.add(appointment);
    notifyListeners();
  }

  String newId(String prefix) => '$prefix${DateTime.now().millisecondsSinceEpoch}';

  // --- Lifecycle transitions ---------------------------------------------
  void checkIn(String id) {
    _byId(id)?.status = AppointmentStatus.arrived;
    notifyListeners();
  }

  void markNoShow(String id) {
    _byId(id)?.status = AppointmentStatus.noShow;
    notifyListeners();
  }

  void logContact(String id) {
    _byId(id)?.lastContactedAt = DateTime.now();
    notifyListeners();
  }

  void cancel(String id, String reason) {
    final a = _byId(id);
    if (a == null) return;
    a.status = AppointmentStatus.cancelled;
    a.cancelReason = reason;
    notifyListeners();
  }

  /// Returns false if the new slot is at branch capacity (conflict).
  bool reschedule(String id, DateTime newDate, String newTime, {required int capacity}) {
    final a = _byId(id);
    if (a == null) return false;
    if (concurrentCount(a.branch, newDate, newTime, excludeId: id) >= capacity) {
      return false;
    }
    a.date = DateTime(newDate.year, newDate.month, newDate.day);
    a.time = newTime;
    if (a.status == AppointmentStatus.pending) {
      a.status = AppointmentStatus.confirmed;
    }
    notifyListeners();
    return true;
  }

  void confirm(String id) {
    final a = _byId(id);
    if (a != null && a.status == AppointmentStatus.pending) {
      a.status = AppointmentStatus.confirmed;
      notifyListeners();
    }
  }

  /// Completes an appointment: saves the treatment record, logs it on the
  /// client's timeline, advances the package, and auto-proposes the next
  /// session if any remain. Returns the auto-created next appointment, if any.
  Appointment? complete(
    String id, {
    required List<String> productsUsed,
    required String notes,
    required int photoCount,
    required bool isSensitive,
    required String staffName,
  }) {
    final a = _byId(id);
    if (a == null) return null;

    a.status = AppointmentStatus.completed;
    a.productsUsed = productsUsed;
    a.notes = notes;
    a.photoCount = photoCount;
    a.isSensitive = isSensitive;

    final customer = customerById(a.customerId);
    if (customer != null) {
      customer.sessions.insert(
        0,
        SessionRecord(
          sessionNumber: a.sessionNumber ?? customer.sessions.length + 1,
          serviceName: a.serviceName,
          date: DateTime.now(),
          staffName: staffName,
          productsUsed: productsUsed,
          notes: notes,
          photoCount: photoCount,
        ),
      );
    }

    Appointment? next;
    if (customer != null && a.packageId != null) {
      final pkg = _packageOf(customer, a.packageId!);
      if (pkg != null) {
        if (pkg.completedSessions < pkg.totalSessions) {
          pkg.completedSessions += 1;
        }
        if (pkg.sessionsLeft > 0) {
          next = Appointment(
            id: newId('a'),
            customerId: customer.id,
            customerName: customer.fullName,
            serviceName: a.serviceName,
            branch: a.branch,
            date: a.date.add(Duration(days: pkg.sessionIntervalDays)),
            time: a.time,
            status: AppointmentStatus.pending,
            packageId: pkg.id,
            packageName: pkg.name,
            sessionNumber: pkg.completedSessions + 1,
          );
          _appointments.add(next);
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
  List<FollowUpItem> followUps() {
    final items = <FollowUpItem>[];
    for (final c in _customers) {
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
        ));
      }
    }
    return items;
  }

  // --- Create a package (from POS) ---------------------------------------
  void createPackage({
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
  }) {
    final customer = customerById(customerId);
    if (customer == null) return;

    final packageId = newId('pk');
    customer.packages.add(TreatmentPackage(
      id: packageId,
      name: packageName,
      totalSessions: totalSessions,
      completedSessions: 0,
      totalPrice: totalPrice,
      paidAmount: paidAmount,
      sessionIntervalDays: sessionIntervalDays,
      invoiceId: invoiceId,
    ));

    for (int i = 0; i < sessionDates.length; i++) {
      _appointments.add(Appointment(
        id: newId('a$i'),
        customerId: customer.id,
        phone: customer.phone,
        customerName: customer.fullName,
        serviceName: packageName,
        branch: branch,
        date: sessionDates[i],
        time: defaultTime,
        status: AppointmentStatus.confirmed,
        packageId: packageId,
        packageName: packageName,
        sessionNumber: i + 1,
      ));
    }
    notifyListeners();
  }
}
