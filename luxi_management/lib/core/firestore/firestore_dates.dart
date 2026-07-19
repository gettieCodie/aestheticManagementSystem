/// Date-only (no time-of-day) string formatting shared by every repository
/// that writes fields like `appointmentDate`, `startDate`, or `dueDate` —
/// matching the plain `yyyy-MM-dd` strings `luxi_appointment` writes.
abstract final class FirestoreDates {
  static String dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseDateOnly(String? s) => s == null ? null : DateTime.parse(s);
}
