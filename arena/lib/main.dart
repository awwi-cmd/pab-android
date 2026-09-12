import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/game_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // DECISIONS D-090: must finish before `runApp` -- `kCharacters`,
  // `EnemyStats`/`BossStats`, the XP curve, and `Settings.defaults` are all
  // read synchronously (no `FutureBuilder`, no loading state) the moment the
  // very first frame builds, so `GameConfig` has to already be populated by
  // then rather than racing the UI to load.
  await GameConfig.instance.load();
  runApp(const ArenaApp());
}
