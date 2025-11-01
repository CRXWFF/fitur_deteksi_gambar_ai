import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitur_deteksi_gambar_ai/main.dart';

void main() {
  testWidgets('App builds and shows Home page', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const MyApp());

    // Allow frames to settle
    await tester.pumpAndSettle();

    // Verify Home page is shown and Start/Stop button exists
    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
