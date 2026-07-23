// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ultimate_team_manager/main.dart';

void main() {
  testWidgets('App boots into the login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump();

    // The router's initial route is '/login', so its title should show up.
    expect(find.text('Ultimate Team\nManager'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
