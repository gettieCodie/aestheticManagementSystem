import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../models/branch_model.dart';
import '../models/service_category.dart';
import '../models/service_model.dart';

/// Supplies all mock/local data for the booking flow.
///
/// This is the single seam for backend integration: swap these synchronous
/// getters for async repository calls (REST, Firebase, etc.) and the rest of
/// the app — which already `await`s via [Future]s — keeps working unchanged.
class BookingDataService {
  const BookingDataService();

  /// Simulated network latency so loading placeholders are exercised.
  static const Duration _fakeDelay = Duration(milliseconds: 600);

  Future<List<ServiceCategory>> fetchServiceCategories() async {
    await Future<void>.delayed(_fakeDelay);
    return _categories;
  }

  Future<List<BranchModel>> fetchBranches() async {
    await Future<void>.delayed(_fakeDelay);
    return _branches;
  }

  /// Bookable time slots between clinic opening and closing hours.
  ///
  /// Generated from [AppConstants] so changing clinic hours updates the UI in
  /// one place.
  Future<List<TimeOfDay>> fetchTimeSlots() async {
    await Future<void>.delayed(_fakeDelay);
    final slots = <TimeOfDay>[];
    int minutes = AppConstants.openingHour * 60;
    final int end = AppConstants.closingHour * 60;
    while (minutes <= end) {
      slots.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
      minutes += AppConstants.slotMinutes;
    }
    return slots;
  }

  // --- Mock data ----------------------------------------------------------

  static const List<BranchModel> _branches = [
    BranchModel(
      id: 'laguna',
      name: 'Laguna',
      address: 'Santa Rosa City, Laguna',
      icon: Icons.location_city_rounded,
    ),
    BranchModel(
      id: 'batangas',
      name: 'Batangas',
      address: 'Batangas City, Batangas',
      icon: Icons.location_city_rounded,
    ),
    BranchModel(
      id: 'lipa',
      name: 'Lipa',
      address: 'Lipa City, Batangas',
      icon: Icons.location_city_rounded,
    ),
    BranchModel(
      id: 'pampanga',
      name: 'Pampanga',
      address: 'Angeles City, Pampanga',
      icon: Icons.location_city_rounded,
    ),
  ];

  static const List<ServiceCategory> _categories = [
    ServiceCategory(
      id: 'facials',
      title: 'Facials & Skincare',
      icon: Icons.spa_rounded,
      services: [
        ServiceModel(
          id: 'signature-facial',
          name: 'Signature Glow Facial',
          description: 'Deep cleanse, exfoliation and hydration boost.',
          durationMinutes: 60,
          price: 1800,
          icon: Icons.spa_rounded,
        ),
        ServiceModel(
          id: 'hydrafacial',
          name: 'HydraFacial',
          description: 'Vortex cleansing for instant radiance.',
          durationMinutes: 45,
          price: 2500,
          icon: Icons.water_drop_rounded,
        ),
        ServiceModel(
          id: 'acll-peel',
          name: 'Acne Clarifying Peel',
          description: 'Targeted peel to calm breakouts.',
          durationMinutes: 40,
          price: 2200,
          icon: Icons.healing_rounded,
        ),
      ],
    ),
    ServiceCategory(
      id: 'laser',
      title: 'Laser & Advanced',
      icon: Icons.auto_awesome_rounded,
      services: [
        ServiceModel(
          id: 'laser-hair',
          name: 'Laser Hair Removal',
          description: 'Smooth, long-lasting hair reduction.',
          durationMinutes: 30,
          price: 3000,
          icon: Icons.auto_awesome_rounded,
        ),
        ServiceModel(
          id: 'skin-resurfacing',
          name: 'Laser Skin Resurfacing',
          description: 'Refine texture and even out tone.',
          durationMinutes: 50,
          price: 4500,
          icon: Icons.grain_rounded,
        ),
        ServiceModel(
          id: 'pigment-removal',
          name: 'Pigmentation Removal',
          description: 'Fade dark spots and sun damage.',
          durationMinutes: 40,
          price: 3800,
          icon: Icons.brightness_5_rounded,
        ),
      ],
    ),
    ServiceCategory(
      id: 'injectables',
      title: 'Injectables & Body',
      icon: Icons.vaccines_rounded,
      services: [
        ServiceModel(
          id: 'botox',
          name: 'Anti-Wrinkle Injections',
          description: 'Soften fine lines for a refreshed look.',
          durationMinutes: 30,
          price: 6000,
          icon: Icons.vaccines_rounded,
        ),
        ServiceModel(
          id: 'filler',
          name: 'Dermal Fillers',
          description: 'Restore volume and contour.',
          durationMinutes: 45,
          price: 9000,
          icon: Icons.face_retouching_natural_rounded,
        ),
        ServiceModel(
          id: 'slimming',
          name: 'Body Slimming Session',
          description: 'Non-invasive contouring treatment.',
          durationMinutes: 60,
          price: 3500,
          icon: Icons.self_improvement_rounded,
        ),
      ],
    ),
  ];
}
