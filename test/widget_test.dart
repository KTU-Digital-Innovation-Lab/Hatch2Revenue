import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hatch2revenue/app.dart';
import 'package:hatch2revenue/screens/splash_screen.dart';

void main() {
  testWidgets('App launches on the splash, then reaches the dashboard',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Fresh launch always starts on the splash.
    SplashScreen.completed = false;

    await tester.pumpWidget(const PoultryApp());
    await tester.pump();

    // Splash brand + tagline are shown first.
    expect(find.text('Hatch2Revenue'), findsOneWidget);
    expect(find.text('From hatch to harvest.'), findsOneWidget);

    // Advance past the hold timer (800ms) and the fade transition
    // (400ms). Explicit pumps — pumpAndSettle would hang on the
    // dashboard's repeating "bobbing hen" animation.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Batch Lifecycle'), findsOneWidget);
    expect(find.text('Financials'), findsOneWidget);
  });
}
