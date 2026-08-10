import 'package:flutter_test/flutter_test.dart';
import 'package:batmin_connect/main.dart';

void main() {
  testWidgets('application starts', (WidgetTester tester) async {
    await tester.pumpWidget(const BatminConnectApp());

    expect(find.byType(BatminConnectApp), findsOneWidget);
  });
}
