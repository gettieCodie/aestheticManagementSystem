import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-backed source of truth for `settings/global` — the same doc
/// `luxi_appointment` reads for payment methods / promo rate.
class SettingsRepository {
  SettingsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('settings').doc('global');

  static const _allMethodLabels = ['Cash', 'GCash', 'Credit/Debit Card'];

  /// Emits `(promoDiscountRate, paymentMethods)` whenever the doc changes.
  /// Firestore only stores which methods are *enabled* as a flat list, so
  /// [paymentMethods] here always has all three known labels — true if
  /// present in that list, false otherwise (never dropped from the map).
  Stream<({double promoDiscountRate, Map<String, bool> paymentMethods})>
      watchSettings() {
    return _doc.snapshots().map((snap) {
      final data = snap.data() ?? const {};
      final enabled = ((data['paymentMethods'] as List?)?.cast<String>() ??
              const ['cash', 'gcash', 'card'])
          .map(_label)
          .toSet();
      return (
        promoDiscountRate: (data['promoDiscountRate'] as num?)?.toDouble() ?? 10,
        paymentMethods: {
          for (final label in _allMethodLabels) label: enabled.contains(label),
        },
      );
    });
  }

  static String _label(String raw) {
    switch (raw.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'gcash':
        return 'GCash';
      case 'card':
        return 'Credit/Debit Card';
      default:
        return raw;
    }
  }

  static String _key(String label) {
    switch (label) {
      case 'Cash':
        return 'cash';
      case 'GCash':
        return 'gcash';
      case 'Credit/Debit Card':
        return 'card';
      default:
        return label.toLowerCase();
    }
  }

  Future<void> setPromoDiscountRate(double value) {
    return _doc.set({
      'promoDiscountRate': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persists the full enabled/disabled map — Firestore only stores which
  /// methods are *enabled* as a flat list, so a disabled entry is dropped.
  Future<void> setPaymentMethods(Map<String, bool> methods) {
    final enabled = [
      for (final entry in methods.entries)
        if (entry.value) _key(entry.key),
    ];
    return _doc.set({
      'paymentMethods': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
