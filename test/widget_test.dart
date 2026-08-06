import 'package:flutter_test/flutter_test.dart';
import 'package:batminconnectvpn/main.dart';

void main() {
  testWidgets('application starts', (WidgetTester tester) async {
    await tester.pumpWidget(const BatminConnectApp());

    expect(find.byType(BatminConnectApp), findsOneWidget);
  });
}
