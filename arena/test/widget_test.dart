import 'package:flutter_test/flutter_test.dart';

import 'package:arena/app.dart';
import 'package:arena/ui/screens/main_menu_screen.dart';

void main() {
  testWidgets('Main menu shows Start/Settings/Credits', (tester) async {
    await tester.pumpWidget(const ArenaApp());
    expect(find.text('ARENA'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('CREDITS'), findsOneWidget);
  });

  testWidgets('Full flow: menu -> select -> arena -> die -> menu',
      (tester) async {
    await tester.pumpWidget(const ArenaApp());

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(find.text('ENTER ARENA'), findsOneWidget);

    // Character Select scrolls on a short viewport (test harness is 800x600).
    await tester.ensureVisible(find.text('ENTER ARENA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTER ARENA'));
    await tester.pumpAndSettle();
    expect(find.text('DIE (debug)'), findsOneWidget);

    await tester.tap(find.text('DIE (debug)'));
    await tester.pumpAndSettle();
    expect(find.text('ROUND OVER'), findsOneWidget);

    await tester.tap(find.text('MAIN MENU'));
    await tester.pumpAndSettle();
    expect(find.byType(MainMenuScreen), findsOneWidget);
  });
}
