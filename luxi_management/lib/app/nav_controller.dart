import 'package:flutter/foundation.dart';

/// Controls the selected navigation index of the dashboard shell, so pages can
/// programmatically switch tabs (e.g. Appointments → POS on "Proceed to
/// Payment").
class NavController extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void select(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }

  void reset() {
    _index = 0;
    notifyListeners();
  }
}
