import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ffmpeg_converter/main.dart';

void main() {
  testWidgets('App starts and displays title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('FFmpeg Converter'), findsOneWidget);
  });

  testWidgets('Initial status is Ready', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the initial status is Ready
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('Select File button is present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the Select File button is present
    expect(find.text('Select File'), findsOneWidget);
  });

  testWidgets('Batch Select button is present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the Batch Select button is present
    expect(find.text('Batch Select'), findsOneWidget);
  });
}
