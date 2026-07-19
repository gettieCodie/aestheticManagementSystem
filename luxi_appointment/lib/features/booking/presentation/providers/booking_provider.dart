import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/branch_model.dart';
import '../../models/client_info.dart';
import '../../models/service_model.dart';
import '../../services/booking_data_service.dart';

/// Single source of truth for the multi-step booking flow.
///
/// Holds every selection the user makes across the four steps plus the current
/// step index. Persists in memory only — there is deliberately no database or
/// API here. When a backend is added, [confirmBooking] is the natural place to
/// call a repository/use-case.
class BookingProvider extends ChangeNotifier {
  final BookingDataService _data = BookingDataService();

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
    if (branch.id != _selectedBranch?.id) {
      // A time slot's availability is specific to one branch/date — clear it
      // so a stale, possibly-now-full slot can't be silently carried over.
      _selectedTime = null;
    }
    _selectedBranch = branch;
    notifyListeners();
  }

  void selectDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day != _selectedDate) {
      _selectedTime = null;
    }
    _selectedDate = day;
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

  /// Uploads a picked profile photo to Cloud Storage and returns its
  /// download URL. Does not itself call [setPhoto] — the caller decides when
  /// the upload has finished (e.g. to show a loading state meanwhile).
  Future<String> uploadPhoto(Uint8List bytes, String fileName) =>
      _data.uploadClientPhoto(bytes, fileName);

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

  /// Sends the booking to the backend (POST /bookings).
  ///
  /// Throws if anything is unselected or the server rejects it; the UI catches
  /// that and shows an error message.
  Future<void> confirmBooking() async {
    final service = _selectedService;
    final branch = _selectedBranch;
    final date = _selectedDate;
    final time = _selectedTime;
    if (service == null || branch == null || date == null || time == null) {
      throw Exception('Please complete every step before confirming.');
    }

    await _data.createBooking(
      service: service,
      branch: branch,
      date: date,
      time: time,
      client: _clientInfo,
    );
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
