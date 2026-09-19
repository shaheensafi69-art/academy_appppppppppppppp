import 'package:flutter_test/flutter_test.dart';
import 'package:safi_academy_app/main.dart';

void main() {
  testWidgets('app widget test can instantiate', (WidgetTester tester) async {
    expect(const SafiAcademyApp(), isNotNull);
  });
}
