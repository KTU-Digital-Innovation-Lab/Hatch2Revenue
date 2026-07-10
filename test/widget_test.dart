import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hatch2revenue/app.dart';

void main() {
  testWidgets('App launches and shows the dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PoultryApp());
    await tester.pump();

    // App bar title of the initial screen.
    expect(find.text('Dashboard'), findsOneWidget);
    // Dashboard nav cards render.
    expect(find.text('Batch Lifecycle'), findsOneWidget);
    expect(find.text('Financials'), findsOneWidget);
  });
}
