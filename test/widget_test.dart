import 'package:flutter_test/flutter_test.dart';
import 'package:batmin_connect/main.dart';

void main() {
  testWidgets('application starts', (WidgetTester tester) async {
    await tester.pumpWidget(const BatminConnectApp());

    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(BatminConnectApp), findsOneWidget);
  });
}
