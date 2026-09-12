import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arena/app.dart';
import 'package:arena/core/tutorial_state.dart';

void main() {
  // ArenaScreen reads Settings via SharedPreferences at arena entry
  // (DECISIONS D-006) -- without a seeded mock backend that future never
  // resolves under the test harness. `hasSeenIntro: true` skips the D-084
  // first-boot tutorial auto-push for these tests, which exercise the main
  // menu/character-select flow itself, not the tutorial -- the fresh-save
  // tutorial path gets its own test below, with its own empty-prefs seed.
  setUp(() {
    SharedPreferences.setMockInitialValues({
      TutorialState.kHasSeenIntroKey: true,
    });
  });

  testWidgets('Main menu shows Start/Settings/Credits', (tester) async {
    await tester.pumpWidget(const ArenaApp());
    expect(find.text('START'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('CREDITS'), findsOneWidget);
  });

  // Coverage stops at Character Select (DECISIONS D-019): once GameWidget
  // mounts, ArenaGame.onLoad() does real PNG decoding via Flame.images,
  // which never resolves under flutter_test's fake-async pump() -- not an
  // app bug, a harness limitation. The arena flow (including combat, now
  // that Phase 4 wires it up) is verified on-device via rebuildinstall.bat.
  testWidgets('Menu -> Character Select is navigable', (tester) async {
    await tester.pumpWidget(const ArenaApp());

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(find.text('ENTER ARENA'), findsOneWidget);

    // Character Select scrolls on a short viewport (test harness is 800x600).
    await tester.ensureVisible(find.text('ENTER ARENA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The Apprentice'), findsOneWidget);
  });

  // DECISIONS D-084: on a genuinely fresh save (nothing written yet), the
  // main menu should push the tutorial automatically, once, without any
  // tap at all.
  testWidgets(
    'Fresh save auto-opens the tutorial, and finishing it returns to the menu',
    (tester) async {
      SharedPreferences.setMockInitialValues({}); // genuinely fresh save
      await tester.pumpWidget(const ArenaApp());
      await tester.pumpAndSettle();

      expect(find.text('HOW TO PLAY'), findsOneWidget);
      expect(find.text('MOVE & SURVIVE'), findsOneWidget);

      // "SKIP" on page 1, "GET STARTED" once paged to the last slide --
      // either one should mark it seen and return to the menu.
      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();

      expect(find.text('HOW TO PLAY'), findsNothing);
      expect(find.text('START'), findsOneWidget);
      expect(await TutorialState.hasSeenIntro(), isTrue);
    },
  );

  // The "?" button should reopen the tutorial on demand even once it's
  // already been seen (main menu, not auto-triggered this time).
  testWidgets('The "?" button reopens the tutorial manually', (tester) async {
    await tester.pumpWidget(const ArenaApp());
    await tester.pumpAndSettle();
    expect(find.text('HOW TO PLAY'), findsNothing); // already seen, no auto-push

    await tester.tap(find.text('?'));
    await tester.pumpAndSettle();
    expect(find.text('HOW TO PLAY'), findsOneWidget);
  });
}
