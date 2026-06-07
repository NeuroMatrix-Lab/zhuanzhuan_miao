import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ffmpeg_converter/main.dart';

void main() {
  testWidgets('App starts and displays title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('FFmpeg Converter'), findsOneWidget);
  });

  testWidgets('Initial status is Ready', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('Drop zone is present', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Drag and drop a file here'), findsOneWidget);
  });
}
