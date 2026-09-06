import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arena/app.dart';

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
}
