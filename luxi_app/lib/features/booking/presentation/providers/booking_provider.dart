import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/branch_model.dart';
import '../../models/client_info.dart';
import '../../models/service_model.dart';

/// Single source of truth for the multi-step booking flow.
///
/// Holds every selection the user makes across the four steps plus the current
/// step index. Persists in memory only — there is deliberately no database or
/// API here. When a backend is added, [confirmBooking] is the natural place to
/// call a repository/use-case.
class BookingProvider extends ChangeNotifier {
  // --- Step navigation ----------------------------------------------------
  int _currentStep = 0;
  int get currentStep => _currentStep;
  int get totalSteps => AppConstants.totalSteps;

  bool get isFirstStep => _currentStep == 0;
  bool get isLastStep => _currentStep == totalSteps - 1;

  // --- Selections ---------------------------------------------------------
  ServiceModel? _selectedService;
  BranchModel? _selectedBranch;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  ClientInfo _clientInfo = const ClientInfo();

  ServiceModel? get selectedService => _selectedService;
  BranchModel? get selectedBranch => _selectedBranch;
  DateTime? get selectedDate => _selectedDate;
  TimeOfDay? get selectedTime => _selectedTime;
  ClientInfo get clientInfo => _clientInfo;

  // --- Per-step completion gates -----------------------------------------
  bool get isServiceStepComplete => _selectedService != null;

  bool get isAppointmentStepComplete =>
      _selectedBranch != null &&
      _selectedDate != null &&
      _selectedTime != null;

  bool get isClientStepComplete => _clientInfo.isComplete;

  /// Whether the user may advance from [_currentStep] to the next one.
  bool get canContinue {
    switch (_currentStep) {
      case 0:
        return isServiceStepComplete;
      case 1:
        return isAppointmentStepComplete;
      case 2:
        return isClientStepComplete;
      default:
        return true;
    }
  }

  // --- Mutations ----------------------------------------------------------
  void selectService(ServiceModel service) {
    _selectedService = service;
    notifyListeners();
  }

  void selectBranch(BranchModel branch) {
    _selectedBranch = branch;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void selectTime(TimeOfDay time) {
    _selectedTime = time;
    notifyListeners();
  }

  void updateClientInfo({
    String? fullName,
    String? email,
    String? phone,
    String? facebook,
  }) {
    _clientInfo = _clientInfo.copyWith(
      fullName: fullName,
      email: email,
      phone: phone,
      facebook: facebook,
    );
    notifyListeners();
  }

  void setPhoto(String? path) {
    _clientInfo = path == null
        ? _clientInfo.copyWith(clearPhoto: true)
        : _clientInfo.copyWith(photoPath: path);
    notifyListeners();
  }

  // --- Navigation ---------------------------------------------------------
  void goToStep(int step) {
    if (step < 0 || step >= totalSteps) return;
    _currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    if (!isLastStep && canContinue) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (!isFirstStep) {
      _currentStep--;
      notifyListeners();
    }
  }

  /// Placeholder for the confirm action.
  ///
  /// No backend yet — this simply simulates a request so the UI can show a
  /// loading state and success feedback. Replace the delay with a real call.
  Future<void> confirmBooking() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
  }

  /// Clears every selection and returns to step one (used after a successful
  /// booking or when the user restarts the flow).
  void reset() {
    _currentStep = 0;
    _selectedService = null;
    _selectedBranch = null;
    _selectedDate = null;
    _selectedTime = null;
    _clientInfo = const ClientInfo();
    notifyListeners();
  }
}
