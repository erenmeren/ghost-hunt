import 'package:shared_preferences/shared_preferences.dart';

import 'game/economy.dart';

/// Loads the player's [Profile] and saves it after every change
/// (localStorage on the web, NSUserDefaults/SharedPreferences on phones).
class ProfileStore {
  static const _key = 'ghost_hunt_profile_v1';

  static Future<Profile> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = Profile.fromJson(prefs.getString(_key));
      p.onChanged = () => prefs.setString(_key, p.toJson());
      return p;
    } catch (_) {
      // No storage backend (tests): keep progress in memory only.
      return Profile();
    }
  }
}
