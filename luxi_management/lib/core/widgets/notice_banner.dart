import 'package:flutter/material.dart';

/// An error banner listing live Firestore stream failures — surfaced so a
/// permission-denied or missing-index error doesn't just look like "no data
/// yet" (an empty list and an errored stream render identically otherwise).
class FirestoreErrorBanner extends StatelessWidget {
  const FirestoreErrorBanner({super.key, required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 20, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Some data failed to load from Firestore',
                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.error),
                ),
                const SizedBox(height: 4),
                for (final e in errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      e,
                      style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Usually a Firestore security-rules or missing-index issue — '
                  'check the rules for these collections in the Firebase console.',
                  style: TextStyle(fontSize: 11, color: scheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
