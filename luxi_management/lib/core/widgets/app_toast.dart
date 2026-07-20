import 'package:flutter/material.dart';

/// Tone of a toast — drives its icon and accent colour.
enum ToastKind { success, error, info }

/// Consistent action feedback across the app.
///
/// Two entry points on purpose:
/// * [show] when a [BuildContext] is safely mounted (before any `await`).
/// * [showOn] when the work is asynchronous — capture the messenger with
///   `ScaffoldMessenger.of(context)` *before* awaiting, then call this. Using
///   a context after an await risks touching an unmounted widget.
///
/// Colours are fixed rather than pulled from the theme so [showOn] works
/// without a context.
abstract final class AppToast {
  static const _success = Color(0xFF3E9E6E);
  static const _error = Color(0xFFE05252);
  static const _info = Color(0xFF3B3B3B);

  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.info,
    SnackBarAction? action,
  }) =>
      showOn(ScaffoldMessenger.of(context), message, kind: kind, action: action);

  static void showOn(
    ScaffoldMessengerState messenger,
    String message, {
    ToastKind kind = ToastKind.info,
    SnackBarAction? action,
  }) {
    final (color, icon) = switch (kind) {
      ToastKind.success => (_success, Icons.check_circle_rounded),
      ToastKind.error => (_error, Icons.error_rounded),
      ToastKind.info => (_info, Icons.info_rounded),
    };

    // Replace rather than queue — stacked toasts from rapid actions are noise.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 6,
        duration: Duration(seconds: kind == ToastKind.error ? 5 : 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5)),
            ),
          ],
        ),
        action: action,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, kind: ToastKind.success);

  static void error(BuildContext context, String message) =>
      show(context, message, kind: ToastKind.error);

  static void successOn(ScaffoldMessengerState m, String message) =>
      showOn(m, message, kind: ToastKind.success);

  static void errorOn(ScaffoldMessengerState m, String message) =>
      showOn(m, message, kind: ToastKind.error);
}
