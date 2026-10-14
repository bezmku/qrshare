import 'package:flutter_test/flutter_test.dart';
import 'package:qrshare/main.dart';

void main() {
  testWidgets('home screen shows file sharing choices', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('QRShare'), findsOneWidget);
    expect(find.text('Send files'), findsOneWidget);
    expect(find.text('Receive files'), findsOneWidget);
  });
}
