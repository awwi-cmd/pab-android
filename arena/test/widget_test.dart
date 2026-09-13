import 'dart:ui' show Size;

import 'package:flutter/widgets.dart' show Key;
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
  //
  // `pumpAndSettle()`, not `pump()`, here: Character Select's wallet row
  // (`CoinIcon`, DECISIONS D-002 follow-up "coin-icon.png is not
  // animating") now spins on a perpetually-repeating `AnimationController`,
  // which never stops scheduling frames -- `pumpAndSettle` would wait for
  // that forever ("pumpAndSettle timed out"), so a couple of bounded
  // `pump()`s stand in for it instead, same fix this project already
  // reaches for anywhere a real animation never settles.
  testWidgets('Menu -> Character Select is navigable', (tester) async {
    // DECISIONS D-005 ("make sure there is no scrolling in character
    // select"): the test harness's default surface (800x600 logical) is
    // shorter than any real phone in portrait and shorter than this
    // now-non-scrolling page's content actually needs -- was previously
    // masked by `ensureVisible` scrolling the real page down to reach
    // ENTER ARENA, which no longer applies now that the page doesn't
    // scroll at all. A realistic tall-phone surface (this app's own
    // kDesignWidth, scaled up) is what the page is actually designed
    // against, not the test runner's default arbitrary window.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ArenaApp());

    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ENTER ARENA'), findsOneWidget);
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

    // DECISIONS D-011: the '?' is a real pixel-art button now, not a
    // `Text('?')` widget -- `Key('helpButton')` is what's stable to find.
    await tester.tap(find.byKey(const Key('helpButton')));
    await tester.pumpAndSettle();
    expect(find.text('HOW TO PLAY'), findsOneWidget);
  });
}
