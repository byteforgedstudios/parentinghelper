import 'package:flutter_test/flutter_test.dart';

import 'package:parentinghelper/app.dart';

void main() {
  testWidgets('Splash screen moves on to the intro screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ParentingHelperApp());

    expect(find.text('Parenting Helper'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);

    // Splash waits 3 seconds before navigating.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
  });
}
