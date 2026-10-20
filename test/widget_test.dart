import 'package:bartender_on_device/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shows its title', (WidgetTester tester) async {
    await tester.pumpWidget(const BartenderApp());

    expect(find.text('Bartender On Device'), findsOneWidget);
  });
}
