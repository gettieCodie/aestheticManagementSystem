/// A purchased treatment package on a client's record.
class TreatmentPackage {
  TreatmentPackage({
    required this.id,
    required this.name,
    required this.totalSessions,
    required this.completedSessions,
    required this.totalPrice,
    required this.paidAmount,
    this.sessionIntervalDays = 7,
    this.invoiceId,
  });

  final String id;
  final String name;
  final int totalSessions;
  int completedSessions;
  final double totalPrice;
  double paidAmount;
  final int sessionIntervalDays;

  /// Links to the invoice that bills this package (money source of truth).
  final String? invoiceId;

  double get balance => totalPrice - paidAmount;
  int get sessionsLeft => totalSessions - completedSessions;
  double get progress =>
      totalSessions == 0 ? 0 : completedSessions / totalSessions;
}

/// One completed treatment visit in a client's timeline.
class SessionRecord {
  SessionRecord({
    required this.sessionNumber,
    required this.serviceName,
    required this.date,
    required this.staffName,
    this.productsUsed = const [],
    this.notes = '',
    this.photoCount = 0,
    this.progressPhotos = const [],
  });

  final int sessionNumber;
  final String serviceName;
  final DateTime date;
  final String staffName;
  final List<String> productsUsed;
  final String notes;
  final int photoCount;
  final List<String> progressPhotos;
}

/// A digital client record (staff-maintained; matched by phone).
class Customer {
  Customer({
    required this.id,
    required this.clientId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.facebook,
    required this.memberSince,
    this.notes = '',
    this.isActive = true,
    this.homeBranch,
    List<TreatmentPackage>? packages,
    List<SessionRecord>? sessions,
    List<String>? visitBranches,
  })  : packages = packages ?? [],
        sessions = sessions ?? [],
        visitBranches = visitBranches ?? [];

  final String id;
  final String clientId;

  // Editable contact details.
  String fullName;
  String email;
  String phone;
  String facebook;
  String notes;
  bool isActive;

  /// Branch the client was registered at (set when a staff member adds them
  /// directly, so they don't vanish from that branch's records before their
  /// first appointment/package exists). Null for clients who came in through
  /// a booking with no explicit registering branch.
  final String? homeBranch;

  final DateTime memberSince;
  final List<TreatmentPackage> packages;
  final List<SessionRecord> sessions;

  /// Every branch this client has an appointment at (any status), derived
  /// by [StaffStore] from the live bookings — a client can be treated at
  /// more than one branch over time.
  final List<String> visitBranches;

  /// Whether this client's record should be visible to staff scoped to
  /// [branch]. `null` (admin, or an unscoped view) always sees everyone.
  bool visibleTo(String? branch) =>
      branch == null || homeBranch == branch || visitBranches.contains(branch);

  int get activePackages => packages.where((p) => p.sessionsLeft > 0).length;
  int get visitCount => sessions.length;

  DateTime? get lastVisit => sessions.isEmpty
      ? null
      : sessions.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fullName.toLowerCase().contains(q) ||
        phone.toLowerCase().contains(q) ||
        clientId.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q);
  }
}
