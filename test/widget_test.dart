import 'package:flutter_test/flutter_test.dart';

import 'package:safi_academy_app/main.dart';

void main() {
  testWidgets('app renders the welcome screen without Supabase initialization', (WidgetTester tester) async {
    await tester.pumpWidget(const SafiAcademyApp(supabaseReady: false));

    expect(find.text('SAFI ACADEMY'), findsOneWidget);
  });
}
