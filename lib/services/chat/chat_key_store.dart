import 'package:shared_preferences/shared_preferences.dart';

import 'chat_crypto.dart';

class ChatKeyStore {
  static const _guardianPublicPrefix = 'chat_guardian_public_';
  static const _guardianPrivatePrefix = 'chat_guardian_private_';
  static const _guardianIdPrefix = 'chat_guardian_id_';

  static const _childPublicPrefix = 'chat_child_public_';
  static const _childPrivatePrefix = 'chat_child_private_';
  static const _childGuardianIdPrefix = 'chat_child_guardian_id_';

  Future<ChatKeyPair?> loadGuardianKeys(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(email);
    final publicKey = prefs.getString('$_guardianPublicPrefix$key');
    final privateKey = prefs.getString('$_guardianPrivatePrefix$key');
    if (publicKey == null || privateKey == null) return null;
    return ChatKeyPair(publicKeyPem: publicKey, privateKeyPem: privateKey);
  }

  Future<void> saveGuardianKeys(String email, ChatKeyPair pair) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(email);
    await prefs.setString('$_guardianPublicPrefix$key', pair.publicKeyPem);
    await prefs.setString('$_guardianPrivatePrefix$key', pair.privateKeyPem);
  }

  Future<int?> loadGuardianId(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(email);
    return prefs.getInt('$_guardianIdPrefix$key');
  }

  Future<void> saveGuardianId(String email, int guardianId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(email);
    await prefs.setInt('$_guardianIdPrefix$key', guardianId);
  }

  Future<ChatKeyPair?> loadChildKeys(String childHash) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(childHash);
    final publicKey = prefs.getString('$_childPublicPrefix$key');
    final privateKey = prefs.getString('$_childPrivatePrefix$key');
    if (publicKey == null || privateKey == null) return null;
    return ChatKeyPair(publicKeyPem: publicKey, privateKeyPem: privateKey);
  }

  Future<void> saveChildKeys(String childHash, ChatKeyPair pair) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(childHash);
    await prefs.setString('$_childPublicPrefix$key', pair.publicKeyPem);
    await prefs.setString('$_childPrivatePrefix$key', pair.privateKeyPem);
  }

  Future<int?> loadChildGuardianId(String childHash) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(childHash);
    return prefs.getInt('$_childGuardianIdPrefix$key');
  }

  Future<void> saveChildGuardianId(String childHash, int guardianId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _safeKey(childHash);
    await prefs.setInt('$_childGuardianIdPrefix$key', guardianId);
  }

  String _safeKey(String input) {
    return input.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
  }
}
