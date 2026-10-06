import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/core/app.dart';

void main() {
  testWidgets('shows app title', (tester) async {
    await tester.pumpWidget(const GoodNightApp());
    expect(find.text('GoodNight 🌙'), findsOneWidget);
  });
}
