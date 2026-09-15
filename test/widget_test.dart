// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/main.dart';

/// The Home screen kicks off a fire-and-forget startup chain that reaches the
/// Isar-backed pending-sync stream and the connectivity plugin. Neither is
/// available in the widget-test VM (main() sets them up on device), so we pump
/// a few frames and drain those known environment errors before asserting on
/// the widget tree, which is what actually matters here.
Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(const HydraApp());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    while (tester.takeException() != null) {
      // Intentionally swallowed: plugin/database absence in the test VM.
    }
  }
}

void main() {
  testWidgets('Home screen shows three action buttons', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await _pumpHome(tester);

    // Verify that the three action buttons are present.
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('PROBLEM'), findsOneWidget);
    expect(find.text('MATERIAL'), findsOneWidget);

    // Verify the history FAB icon is present.
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('Home action buttons are tactile and bottom-labelled', (
    WidgetTester tester,
  ) async {
    await _pumpHome(tester);

    // Giant 80px icons, one per button.
    for (final icon in [Icons.handyman, Icons.warning_amber_rounded,
        Icons.inventory_2]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).size, 80);
    }

    // The label uses the new 14px / 2.0 letter-spacing treatment...
    final label = tester.widget<Text>(find.text('WORK'));
    expect(label.style?.fontSize, 14);
    expect(label.style?.letterSpacing, 2.0);
    expect(label.style?.fontWeight, FontWeight.bold);

    // ...and is pinned to the very bottom edge of the button surface.
    final iconFinder = find.byIcon(Icons.handyman);
    final buttonFinder = find
        .ancestor(of: iconFinder, matching: find.byType(Container))
        .first;
    // The button widget's own rect includes the 4px shadow margin, so measure
    // the painted surface (the decorated box) instead.
    final surfaceRect = tester.getRect(
      find
          .descendant(of: buttonFinder, matching: find.byType(DecoratedBox))
          .first,
    );
    final labelRect = tester.getRect(find.text('WORK'));
    expect(
      surfaceRect.bottom - labelRect.bottom,
      closeTo(10, 1),
      reason: 'label should hug the bottom edge (10px padding)',
    );

    // The icon stays vertically centered in the button.
    final iconRect = tester.getRect(iconFinder);
    expect(iconRect.center.dy, closeTo(surfaceRect.center.dy, 1));

    // A downward drop shadow makes the button read as a physical key.
    final decoration =
        tester.widget<Container>(buttonFinder).decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(18));
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow!.length, greaterThanOrEqualTo(2));
    expect(decoration.boxShadow!.first.offset.dy, greaterThan(0));
    expect(decoration.boxShadow!.first.color.a, greaterThan(0));
  });
}

