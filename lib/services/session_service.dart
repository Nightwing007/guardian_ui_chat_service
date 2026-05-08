import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _parentEmailKey = 'parent_email';
  static const String _parentPasswordKey = 'parent_password';
  static const String _childHashKey = 'child_hash';
  static const String _isParentLoggedInKey = 'is_parent_logged_in';

  static const String _childDeviceTokenKey = 'child_device_token';
  static const String _isChildLinkedKey = 'is_child_linked';
  static const String _userRoleKey = 'user_role';
  static const String childRole = 'child';
  static const String parentRole = 'parent';

  static Future<void> saveParentSession({
    required String email,
    required String password,
    required String childHash,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_parentEmailKey, email);
    await prefs.setString(_parentPasswordKey, password);
    await prefs.setString(_childHashKey, childHash);
    await prefs.setBool(_isParentLoggedInKey, true);
    await prefs.setString(_userRoleKey, parentRole);
  }

  static Future<Map<String, String?>> getParentSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_parentEmailKey),
      'password': prefs.getString(_parentPasswordKey),
      'childHash': prefs.getString(_childHashKey),
      'isLoggedIn': prefs.getBool(_isParentLoggedInKey)?.toString() ?? 'false',
    };
  }

  static Future<void> clearParentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_parentEmailKey);
    await prefs.remove(_parentPasswordKey);
    await prefs.remove(_childHashKey);
    await prefs.remove(_isParentLoggedInKey);
    if (prefs.getString(_userRoleKey) == parentRole) {
      await prefs.remove(_userRoleKey);
    }
  }

  static Future<void> saveChildSession({required String deviceToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_childDeviceTokenKey, deviceToken);
    await prefs.setBool(_isChildLinkedKey, true);
    await prefs.setString(_userRoleKey, childRole);
  }

  static Future<Map<String, String?>> getChildSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'deviceToken': prefs.getString(_childDeviceTokenKey),
      'isLinked': prefs.getBool(_isChildLinkedKey)?.toString() ?? 'false',
      'role': prefs.getString(_userRoleKey),
    };
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<void> clearChildSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_childDeviceTokenKey);
    await prefs.remove(_isChildLinkedKey);
    if (prefs.getString(_userRoleKey) == childRole) {
      await prefs.remove(_userRoleKey);
    }
  }
}
