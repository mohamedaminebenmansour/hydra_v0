// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/main.dart';

void main() {
  testWidgets('Home screen shows three action buttons', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HydraApp());

    // Verify that the three action buttons are present.
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('PROBLEM'), findsOneWidget);
    expect(find.text('MATERIAL'), findsOneWidget);

    // Verify the history FAB icon is present.
    expect(find.byIcon(Icons.history), findsOneWidget);
  });
}
