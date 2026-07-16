import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../models/branch_model.dart';
import '../models/client_info.dart';
import '../models/service_category.dart';
import '../models/service_model.dart';

/// The single data seam for the booking flow.
///
/// Right now it returns local mock data and simulates saving. This is the ONE
/// place to swap in Firebase later: replace the bodies of these methods with
/// Firestore reads/writes (e.g. `cloud_firestore` queries) and nothing else in
/// the app needs to change. Keep the method signatures stable.
class BookingDataService {
  const BookingDataService();

  /// Simulated latency so loading placeholders are exercised.
  static const Duration _fakeDelay = Duration(milliseconds: 500);

  /// TODO(firebase): read the `services` collection and group by `category`.
  Future<List<ServiceCategory>> fetchServiceCategories() async {
    await Future<void>.delayed(_fakeDelay);
    return _categories;
  }

  /// TODO(firebase): read the `branches` collection.
  Future<List<BranchModel>> fetchBranches() async {
    await Future<void>.delayed(_fakeDelay);
    return _branches;
  }

  /// Bookable time slots generated from clinic hours (client-side).
  Future<List<TimeOfDay>> fetchTimeSlots() async {
    final slots = <TimeOfDay>[];
    int minutes = AppConstants.openingHour * 60;
    final int end = AppConstants.closingHour * 60;
    while (minutes <= end) {
      slots.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
      minutes += AppConstants.slotMinutes;
    }
    return slots;
  }

  /// Save a booking. Currently a no-op that just simulates success.
  ///
  /// TODO(firebase): create a `bookings` document (and match/create the
  /// `customers` record by phone) here.
  Future<void> createBooking({
    required int serviceId,
    required int branchId,
    required DateTime date,
    required TimeOfDay time,
    required ClientInfo client,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  // --- Mock data ----------------------------------------------------------

  static const List<BranchModel> _branches = [
    BranchModel(id: 1, name: 'Laguna', address: 'Santa Rosa City, Laguna'),
    BranchModel(id: 2, name: 'Batangas', address: 'Batangas City, Batangas'),
    BranchModel(id: 3, name: 'Lipa', address: 'Lipa City, Batangas'),
    BranchModel(id: 4, name: 'Pampanga', address: 'Angeles City, Pampanga'),
  ];

  static const List<ServiceCategory> _categories = [
    ServiceCategory(
      id: 'facials',
      title: 'Facials & Skincare',
      icon: Icons.spa_rounded,
      services: [
        ServiceModel(
          id: 1,
          name: 'Signature Glow Facial',
          category: 'Facials & Skincare',
          description: 'Deep cleanse, exfoliation and hydration boost.',
          durationMinutes: 60,
          price: 1800,
          icon: Icons.spa_rounded,
        ),
        ServiceModel(
          id: 2,
          name: 'HydraFacial',
          category: 'Facials & Skincare',
          description: 'Vortex cleansing for instant radiance.',
          durationMinutes: 45,
          price: 2500,
          icon: Icons.water_drop_rounded,
        ),
        ServiceModel(
          id: 3,
          name: 'Acne Clarifying Peel',
          category: 'Facials & Skincare',
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
          id: 4,
          name: 'Laser Hair Removal',
          category: 'Laser & Advanced',
          description: 'Smooth, long-lasting hair reduction.',
          durationMinutes: 30,
          price: 3000,
          icon: Icons.auto_awesome_rounded,
        ),
        ServiceModel(
          id: 5,
          name: 'Laser Skin Resurfacing',
          category: 'Laser & Advanced',
          description: 'Refine texture and even out tone.',
          durationMinutes: 50,
          price: 4500,
          icon: Icons.grain_rounded,
        ),
        ServiceModel(
          id: 6,
          name: 'Pigmentation Removal',
          category: 'Laser & Advanced',
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
          id: 7,
          name: 'Anti-Wrinkle Injections',
          category: 'Injectables & Body',
          description: 'Soften fine lines for a refreshed look.',
          durationMinutes: 30,
          price: 6000,
          icon: Icons.vaccines_rounded,
        ),
        ServiceModel(
          id: 8,
          name: 'Dermal Fillers',
          category: 'Injectables & Body',
          description: 'Restore volume and contour.',
          durationMinutes: 45,
          price: 9000,
          icon: Icons.face_retouching_natural_rounded,
        ),
        ServiceModel(
          id: 9,
          name: 'Body Slimming Session',
          category: 'Injectables & Body',
          description: 'Non-invasive contouring treatment.',
          durationMinutes: 60,
          price: 3500,
          icon: Icons.self_improvement_rounded,
        ),
      ],
    ),
  ];
}
