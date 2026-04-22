import 'package:flutter_test/flutter_test.dart';
import 'package:hatch2revenue/app.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const PoultryApp());
    expect(find.text('Hatch2Revenue'), findsOneWidget);
  });
}
