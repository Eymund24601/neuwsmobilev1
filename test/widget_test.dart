// Basic smoke test for the nEUws MVP.
import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/main.dart';

void main() {
  testWidgets('App builds and shows home content', (WidgetTester tester) async {
    await tester.pumpWidget(const NeuwsApp());
    expect(find.text('The Latest'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
