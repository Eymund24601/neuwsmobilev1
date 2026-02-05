import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/main.dart';
import 'package:neuws_mobile_v1/providers/feature_data_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [enableStartupPrefetchProvider.overrideWithValue(false)],
        child: const NeuwsApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
  }

  Future<void> switchTab(WidgetTester tester, int index) async {
    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    nav.onTap?.call(index);
    await tester.pumpAndSettle();
  }

  testWidgets('bottom nav is locked to 5 tabs', (WidgetTester tester) async {
    await pumpApp(tester);

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items.length, 5);
    final labels = nav.items.map((item) => item.label).toList();
    expect(labels, ['Home', 'Messages', 'Words', 'Play', 'You']);
  });

  testWidgets('home to saved and events flow works', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Events').first);
    await tester.pumpAndSettle();
    expect(find.text('Events'), findsWidgets);

    await tester.tap(find.text('Details').first);
    await tester.pumpAndSettle();
    expect(find.text('RSVP (UI only)'), findsOneWidget);
  });

  testWidgets('learn to track to lesson flow works', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await switchTab(tester, 2);
    expect(
      find.text('Short tracks on Europe, culture, and politics'),
      findsOneWidget,
    );

    await tester.tap(find.text('Open').first);
    await tester.pumpAndSettle();
    expect(find.text('Track'), findsOneWidget);

    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
    expect(find.text('Lesson'), findsOneWidget);
  });

  testWidgets('drawer links open premium settings and creative studio', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Premium'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Settings'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Creative Studio'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Premium'));
    await tester.pumpAndSettle();
    expect(find.text('Premium'), findsWidgets);
    expect(find.text('EUR 7.99 / month'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Settings'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Creative Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Open Write Flow'), findsOneWidget);
  });

  testWidgets('games to quiz flow works', (WidgetTester tester) async {
    await pumpApp(tester);

    await switchTab(tester, 3);
    expect(find.text('Puzzles & Quizzes'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Open Quiz Categories'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -140));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Quiz Categories'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Quiz Categories'), findsWidgets);

    await tester.tap(find.text('Geography'));
    await tester.pumpAndSettle();
    expect(find.text('Capitals Sprint'), findsOneWidget);
  });
}
