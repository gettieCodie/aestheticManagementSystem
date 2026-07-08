// Basic smoke tests for the Luxi booking app.

import 'package:flutter_test/flutter_test.dart';

import 'package:luxi_app/main.dart';

void main() {
  testWidgets('Landing page renders and can start booking',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuxiApp());
    await tester.pumpAndSettle();

    // Landing CTA is present.
    expect(find.text('Book an Appointment'), findsOneWidget);

    // Tapping it navigates into the booking flow (step 1 of 4).
    await tester.tap(find.text('Book an Appointment'));
    await tester.pumpAndSettle();

    expect(find.text('Select a service'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });
}
