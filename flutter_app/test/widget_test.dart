import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daymap/main.dart';

void main() {
  testWidgets('Daymap app renders calendar tab', (WidgetTester tester) async {
    await tester.pumpWidget(const DaymapApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('달력'), findsWidgets);
  });
}
