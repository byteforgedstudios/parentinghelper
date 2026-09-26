import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parentinghelper/app.dart';

void main() {
  testWidgets('First launch goes from splash to the intro screen', (
    WidgetTester tester,
  ) async {
    // No consent recorded yet.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ParentingHelperApp());

    expect(find.text('Parenting Helper'), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);

    // Splash waits 3 seconds before navigating.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
  });
}
