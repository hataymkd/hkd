import 'package:hkd/core/session/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesSessionStorage implements SessionStorage {
  static const String _userIdKey = 'hkd_session_user_id';

  @override
  Future<String?> readUserId() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(_userIdKey);
  }

  @override
  Future<void> writeUserId(String userId) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userIdKey, userId);
  }

  @override
  Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userIdKey);
  }
}
