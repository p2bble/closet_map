import 'package:flutter_test/flutter_test.dart';
import 'package:closet_map/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClosetMapApp());
    expect(find.text('홈'), findsWidgets);
  });
}
