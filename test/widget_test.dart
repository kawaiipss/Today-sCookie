import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_cookie/main.dart';

void main() {
  testWidgets('앱 smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FortuneCookieApp());
    expect(find.byType(FortuneCookieApp), findsOneWidget);
  });
}
