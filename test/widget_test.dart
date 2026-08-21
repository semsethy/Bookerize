import 'package:flutter_test/flutter_test.dart';

import 'package:bookerize/main.dart';

void main() {
  testWidgets('app builds and shows its title', (WidgetTester tester) async {
    await tester.pumpWidget(const BookerizeApp());

    expect(find.text('Bookerize'), findsOneWidget);
  });
}
