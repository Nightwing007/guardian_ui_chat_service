import 'package:shared_preferences/shared_preferences.dart';

class DeviceAuthService {
  static final DeviceAuthService _instance = DeviceAuthService._internal();
  factory DeviceAuthService() => _instance;
  DeviceAuthService._internal();

  static const _childHashKey = 'device_child_hash';
  static const _deviceTokenKey = 'device_token';

  // Hardcoded dev credentials — used when no credentials are stored
  static const _devChildHash = 'D8L_Y5hP3iV7Ht8i';
  static const _devDeviceToken = 'seed-device-token-dev-only-not-for-production-abc123';

  static const bool _useDevCredentials = true;

  Future<void> saveCredentials({
    required String childHash,
    required String deviceToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_childHashKey, childHash);
    await prefs.setString(_deviceTokenKey, deviceToken);
  }

  Future<String> getChildHash() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_childHashKey);
    if (stored != null) return stored;
    if (_useDevCredentials) return _devChildHash;
    throw StateError('No child hash available');
  }

  Future<String> getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_deviceTokenKey);
    if (stored != null) return stored;
    if (_useDevCredentials) return _devDeviceToken;
    throw StateError('No device token available');
  }

  Future<bool> isDeviceRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_childHashKey) && prefs.containsKey(_deviceTokenKey)) return true;
    return _useDevCredentials;
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_childHashKey);
    await prefs.remove(_deviceTokenKey);
  }
}
