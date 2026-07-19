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
    List<TreatmentPackage>? packages,
    List<SessionRecord>? sessions,
  })  : packages = packages ?? [],
        sessions = sessions ?? [];

  final String id;
  final String clientId;

  // Editable contact details.
  String fullName;
  String email;
  String phone;
  String facebook;
  String notes;
  bool isActive;

  final DateTime memberSince;
  final List<TreatmentPackage> packages;
  final List<SessionRecord> sessions;

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
