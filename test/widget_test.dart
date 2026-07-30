import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/app/app.dart';

void main() {
  testWidgets('PaySense app loads', (tester) async {
    await tester.pumpWidget(const PaySenseApp());
    expect(find.text('PaySense'), findsWidgets);
  });
}
