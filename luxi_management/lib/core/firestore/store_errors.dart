import 'package:flutter/foundation.dart';

/// Mixed into a `ChangeNotifier`-based store to surface Firestore stream
/// failures (permission-denied, missing index, etc.) instead of letting
/// them fail silently into an empty list — which otherwise looks identical
/// to "there's just no data yet" from the UI's point of view.
mixin FirestoreErrorTracker on ChangeNotifier {
  final Map<String, String> _streamErrors = {};

  /// One human-readable line per failing stream, e.g.
  /// `"services: [cloud_firestore/permission-denied] ..."`.
  List<String> get firestoreErrors =>
      _streamErrors.entries.map((e) => '${e.key}: ${e.value}').toList();

  bool get hasFirestoreErrors => _streamErrors.isNotEmpty;

  void reportStreamError(String source, Object error) {
    debugPrint('[$runtimeType] $source stream error: $error');
    _streamErrors[source] = error.toString();
    notifyListeners();
  }

  void clearStreamError(String source) {
    if (_streamErrors.remove(source) != null) notifyListeners();
  }
}
