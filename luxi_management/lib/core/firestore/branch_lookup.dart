/// Shared mapping between the short branch names used throughout
/// luxi_management (`kBranches` — "Laguna", "Batangas", "Lipa", "Pampanga")
/// and the Firestore `branches` collection's doc ids / full names, which
/// `luxi_appointment` (the client-facing app) uses.
///
/// Every repository that reads/writes a collection with a `branchId` field
/// goes through this so the two apps agree on what a branch is called.
abstract final class BranchLookup {
  static const Map<String, String> idByShortName = {
    'Laguna': 'branch_01',
    'Lipa': 'branch_02',
    'Batangas': 'branch_03',
    'Pampanga': 'branch_04',
  };

  static const Map<String, String> shortNameById = {
    'branch_01': 'Laguna',
    'branch_02': 'Lipa',
    'branch_03': 'Batangas',
    'branch_04': 'Pampanga',
  };

  static const Map<String, String> fullNameById = {
    'branch_01': 'Sta. Rosa, Laguna',
    'branch_02': 'Lipa City, Batangas',
    'branch_03': 'Batangas City, Batangas',
    'branch_04': 'Angeles City, Pampanga',
  };

  static String? fullNameByShortName(String shortName) {
    final id = idByShortName[shortName];
    return id == null ? null : fullNameById[id];
  }
}
