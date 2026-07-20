/// Static, app-wide copy and configuration values.
abstract final class AppConstants {
  static const String appName = 'Luxi';
  static const String clinicName = 'Luxuriskin Aesthetic Clinic';
  static const String tagline = 'Skin, sorted.';

  static const String landingHeading = 'Radiant skin,\nbooked in minutes.';
  static const String landingDescription =
      'Reserve your next treatment at Luxuriskin. Choose a service, pick a '
      'branch, and lock in a time that works for you — all in a few taps.';

  // Clinic operating window used to generate bookable time slots.
  static const int openingHour = 9; // 9:00 AM
  static const int closingHour = 16; // 4:00 PM
  static const int slotMinutes = 30;

  // Concurrent appointments a branch can hold in one time slot. One booking
  // fully occupies a slot — a slot is hidden from booking as soon as it has
  // one active (non-cancelled/no-show) booking. Keep in sync with
  // `kBranchCapacity` in luxi_management's scheduling_page.dart — same rule,
  // same branches.
  static const int branchCapacity = 1;

  // Number of booking steps in the multi-step flow.
  static const int totalSteps = 4;

  // Shown wherever a service/price is displayed, so clients know the final
  // service and price depend on the in-clinic aesthetician assessment.
  static const String priceDisclaimer =
      'Prices shown are indicative. Your final treatment and price may change '
      'based on your aesthetician\'s assessment during your visit.';
}
