import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SeboApp(isRegistered: false));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
