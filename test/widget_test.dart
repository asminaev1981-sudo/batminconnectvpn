import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:batmin_connect/core/services/connection_controller.dart';
import 'package:batmin_connect/features/home/home_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('home screen shows product name', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => ConnectionController(), child: const MaterialApp(home: HomePage())));
    expect(find.text('Batmin Connect'), findsOneWidget);
  });
}
