import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arena/app.dart';
import 'package:arena/ui/screens/main_menu_screen.dart';

void main() {
  // ArenaScreen reads Settings via SharedPreferences at arena entry
  // (DECISIONS D-006) -- without a seeded mock backend that future never
  // resolves under the test harness.
  SharedPreferences.setMockInitialValues({});

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

    // Once the GameWidget mounts it drives its own render ticker that
    // reschedules a frame every pump regardless of ArenaGame's paused
    // state, so pumpAndSettle never converges from here on -- pump a
    // bounded number of frames instead.
    await _pumpFrames(tester);
    expect(find.text('DIE (debug)'), findsOneWidget);

    await tester.tap(find.text('DIE (debug)'));
    await _pumpFrames(tester);
    expect(find.text('ROUND OVER'), findsOneWidget);

    await tester.tap(find.text('MAIN MENU'));
    await _pumpFrames(tester);
    expect(find.byType(MainMenuScreen), findsOneWidget);
  });
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
