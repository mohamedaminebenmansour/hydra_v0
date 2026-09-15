// Widget tests for the Save Report screen's premium-overhaul bits: the roomy
// problem-category picker and the clean red recording surface.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/screens/save_report_screen.dart';

/// Smallest valid PNG (1x1, transparent) so `Image.file` resolves for real
/// instead of falling into its error builder.
const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// Pins the test surface to a phone-shaped viewport. The default 800x600 test
/// window is much shorter than any real device and would report layout
/// overflows that users never see.
void _usePhoneViewport(WidgetTester tester, {double height = 780}) {
  tester.view.physicalSize = Size(360 * 3, height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Container that draws the circle behind a category icon.
Container _circleAround(WidgetTester tester, IconData icon) {
  return tester.widget<Container>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(Container)).first,
  );
}

BoxDecoration _decorationAround(WidgetTester tester, IconData icon) {
  return _circleAround(tester, icon).decoration! as BoxDecoration;
}

void main() {
  late Directory tempDir;
  late String photoPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hydra_ui_test');
    final file = File('${tempDir.path}/photo.jpg')
      ..writeAsBytesSync(_kTransparentPng);
    photoPath = file.path;
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpSaveReport(
    WidgetTester tester, {
    String type = 'problem',
    double height = 780,
  }) async {
    _usePhoneViewport(tester, height: height);
    await tester.pumpWidget(
      MaterialApp(home: SaveReportScreen(type: type, photoPath: photoPath)),
    );
    await tester.pump();
  }

  testWidgets('problem categories breathe: Wrap with 16px spacing', (
    WidgetTester tester,
  ) async {
    await pumpSaveReport(tester);

    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    expect(wrap.spacing, 16.0);
    expect(wrap.runSpacing, 16.0);
    expect(wrap.alignment, WrapAlignment.center);

    // All four categories render as 40px icons inside padded circles.
    final icons = [
      Icons.build,
      Icons.inventory,
      Icons.terrain,
      Icons.person_off,
    ];
    for (final icon in icons) {
      expect(tester.widget<Icon>(find.byIcon(icon)).size, 40);
      expect(_circleAround(tester, icon).padding, const EdgeInsets.all(12));
    }

    // The 16px spacing / 16px run spacing above is what gives the row room to
    // breathe; nothing overflows even on a narrow 360px-wide phone.
    // (Note: exact row/column wrapping is font-metric dependent and the test
    // VM uses a placeholder font, so we assert the layout contract instead.)
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a category fills its circle with the category color', (
    WidgetTester tester,
  ) async {
    await pumpSaveReport(tester);

    // Nothing selected yet: hollow circles only.
    expect(_decorationAround(tester, Icons.inventory).color, isNull);
    expect(_decorationAround(tester, Icons.build).color, isNull);

    // Material selected -> solid Amber circle, ink flipped for contrast.
    await tester.tap(find.byIcon(Icons.inventory));
    await tester.pump();

    expect(_decorationAround(tester, Icons.inventory).color, Colors.amber);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.inventory)).color,
      Colors.black87,
    );
    // Other categories stay unselected.
    expect(_decorationAround(tester, Icons.build).color, isNull);

    // Machine selected -> solid red circle with white ink.
    await tester.tap(find.byIcon(Icons.build));
    await tester.pump();

    expect(_decorationAround(tester, Icons.build).color, Colors.red);
    expect(tester.widget<Icon>(find.byIcon(Icons.build)).color, Colors.white);
    expect(_decorationAround(tester, Icons.inventory).color, isNull);
  });

  testWidgets('mic zone is a clean grey surface when idle', (
    WidgetTester tester,
  ) async {
    await pumpSaveReport(tester);

    final micZoneFinder = find
        .ancestor(
          of: find.text('ADD VOICE NOTE'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final micZone = tester.widget<AnimatedContainer>(micZoneFinder);

    expect(
      (micZone.decoration! as BoxDecoration).color,
      Colors.grey.shade900,
    );
    // The control scales down instead of overflowing on short screens.
    expect(
      find.descendant(of: micZoneFinder, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(find.text('ADD VOICE NOTE'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
  });

  testWidgets('mic zone survives a short phone screen without overflowing', (
    WidgetTester tester,
  ) async {
    await pumpSaveReport(tester, height: 640);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-problem reports hide the category picker', (
    WidgetTester tester,
  ) async {
    await pumpSaveReport(tester, type: 'work');

    expect(find.byType(Wrap), findsNothing);
    expect(find.text('Problem Category'), findsNothing);
  });
}
