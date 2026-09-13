import 'package:shared_preferences/shared_preferences.dart';

/// The `CharacterDef.id` last played (DECISIONS D-009, "save last character
/// played for next round") — Character Select jumps straight to it on
/// open instead of always starting on the Apprentice. One value, one key,
/// same minimal shape as `TutorialState`'s single persisted flag (not a
/// full repository class since there's only ever this one field).
class LastCharacterState {
  LastCharacterState._();

  /// Public so tests can seed/inspect it directly via
  /// `SharedPreferences.setMockInitialValues` without duplicating the
  /// literal string.
  static const kLastCharacterIdKey = 'lastCharacter.id';

  /// `null` on a fresh install/save, or if the id it finds no longer
  /// matches any `CharacterDef` (a future roster change) — callers fall
  /// back to the default first slot either way, same as `TutorialState`'s
  /// own "missing means the fresh-save default" shape.
  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kLastCharacterIdKey);
  }

  /// Called the moment the player commits to a character (ENTER ARENA),
  /// not just on hovering/swiping past it in the carousel.
  static Future<void> save(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLastCharacterIdKey, characterId);
  }
}
