import 'dart:developer' as developer;

import 'package:myapp/models/chat/chat_message.dart';
import 'package:myapp/services/app_database.dart';
import 'package:myapp/services/session_service.dart';

import 'chat_api.dart';
import 'chat_crypto.dart';
import 'chat_key_store.dart';

class ChatServiceException implements Exception {
  final String message;

  ChatServiceException(this.message);

  @override
  String toString() => message;
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final ChatApi _api = ChatApi();
  final ChatCrypto _crypto = ChatCrypto();
  final ChatKeyStore _keyStore = ChatKeyStore();
  final AppDatabase _db = AppDatabase();

  // ── Guardian-side ────────────────────────────────────────────────────

  Future<List<ChatMessageItem>> fetchGuardianConversation({
    required String childHash,
    bool markRead = false,
  }) async {
    await _db.initialize();

    final context = await _loadGuardianContext(childHash: childHash);
    final messages = await _api.getGuardianConversation(
      email: context.email,
      password: context.password,
      childHash: context.childHash,
      markRead: markRead,
    );

    for (final message in messages) {
      if (message.senderType == 'child') {
        // Message from child → decrypt with guardian's private key
        final plaintext = _decryptOrPlaceholder(
          ciphertext: message.messageEncrypted,
          privateKeyPem: context.guardianKeys.privateKeyPem,
          label: 'guardian fetch (child→guardian)',
        );
        await _db.parent.upsertChatMessage(
          childHash: context.childHash,
          guardianId: context.guardianId,
          remoteId: message.id,
          senderType: message.senderType,
          text: plaintext,
          createdAt: message.createdAt,
          isRead: markRead ? true : message.isRead,
          isMe: false,
        );
      } else if (message.senderType == 'guardian') {
        // Our own message — just update read status if server marked it read
        if (message.isRead) {
          await _db.parent.updateChatMessageReadStatus(
            childHash: context.childHash,
            guardianId: context.guardianId,
            remoteId: message.id,
            isRead: true,
          );
        }
      }
    }

    if (markRead) {
      await _db.parent.markConversationRead(
        childHash: context.childHash,
        guardianId: context.guardianId,
      );
    }

    return _db.parent.getChatMessages(
      childHash: context.childHash,
      guardianId: context.guardianId,
    );
  }

  Future<ChatMessageItem> sendGuardianMessage({
    required String childHash,
    required String text,
  }) async {
    await _db.initialize();

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ChatServiceException('Message cannot be empty');
    }

    final context = await _loadGuardianContext(childHash: childHash);

    // Encrypt the message with the CHILD's public key
    final String encrypted;
    try {
      encrypted = _crypto.encrypt(
        plaintext: trimmedText,
        publicKeyPem: context.childPublicKey,
      );
    } catch (e) {
      throw ChatServiceException('Unable to encrypt message. Please try again.');
    }

    final result = await _api.sendGuardianMessage(
      email: context.email,
      password: context.password,
      childHash: context.childHash,
      messageEncrypted: encrypted,
    );

    final message = ChatMessageItem(
      remoteId: result.messageId,
      text: trimmedText,
      createdAt: result.createdAt,
      isMe: true,
      isSeen: false,
      senderType: 'guardian',
    );

    await _db.parent.upsertChatMessage(
      childHash: context.childHash,
      guardianId: context.guardianId,
      remoteId: result.messageId,
      senderType: 'guardian',
      text: trimmedText,
      createdAt: result.createdAt,
      isRead: false,
      isMe: true,
    );

    return message;
  }

  // ── Child-side ───────────────────────────────────────────────────────

  Future<List<ChatMessageItem>> fetchChildConversation({
    int? guardianId,
    bool markRead = false,
  }) async {
    await _db.initialize();

    final context = await _loadChildContext(guardianId: guardianId);
    final messages = await _api.getChildConversation(
      childHash: context.childHash,
      guardianId: context.guardianId,
      markRead: markRead,
    );

    for (final message in messages) {
      if (message.senderType == 'guardian') {
        // Message from guardian → decrypt with child's private key
        final plaintext = _decryptOrPlaceholder(
          ciphertext: message.messageEncrypted,
          privateKeyPem: context.childKeys.privateKeyPem,
          label: 'child fetch (guardian→child)',
        );
        await _db.child.upsertChatMessage(
          childHash: context.childHash,
          guardianId: context.guardianId,
          remoteId: message.id,
          senderType: message.senderType,
          text: plaintext,
          createdAt: message.createdAt,
          isRead: markRead ? true : message.isRead,
          isMe: false,
        );
      } else if (message.senderType == 'child') {
        // Our own message — just update read status
        if (message.isRead) {
          await _db.child.updateChatMessageReadStatus(
            childHash: context.childHash,
            guardianId: context.guardianId,
            remoteId: message.id,
            isRead: true,
          );
        }
      }
    }

    if (markRead) {
      await _db.child.markConversationRead(
        childHash: context.childHash,
        guardianId: context.guardianId,
      );
    }

    return _db.child.getChatMessages(
      childHash: context.childHash,
      guardianId: context.guardianId,
    );
  }

  Future<ChatMessageItem> sendChildMessage(String text, {int? guardianId}) async {
    await _db.initialize();

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ChatServiceException('Message cannot be empty');
    }

    final context = await _loadChildContext(guardianId: guardianId);

    // Encrypt the message with the GUARDIAN's public key
    final String encrypted;
    try {
      encrypted = _crypto.encrypt(
        plaintext: trimmedText,
        publicKeyPem: context.guardianPublicKey,
      );
    } catch (e) {
      throw ChatServiceException('Unable to encrypt message. Please try again.');
    }

    final result = await _api.sendChildMessage(
      childHash: context.childHash,
      guardianId: context.guardianId,
      messageEncrypted: encrypted,
    );

    final message = ChatMessageItem(
      remoteId: result.messageId,
      text: trimmedText,
      createdAt: result.createdAt,
      isMe: true,
      isSeen: false,
      senderType: 'child',
    );

    await _db.child.upsertChatMessage(
      childHash: context.childHash,
      guardianId: context.guardianId,
      remoteId: result.messageId,
      senderType: 'child',
      text: trimmedText,
      createdAt: result.createdAt,
      isRead: false,
      isMe: true,
    );

    return message;
  }

  // ── Context loaders ──────────────────────────────────────────────────

  Future<_GuardianContext> _loadGuardianContext({
    required String childHash,
  }) async {
    final session = await SessionService.getParentSession();
    final email = session['email'];
    final password = session['password'];
    if (email == null || email.isEmpty) {
      throw ChatServiceException('Guardian session email is missing — please log in again');
    }
    if (password == null || password.isEmpty) {
      throw ChatServiceException('Guardian session password is missing — please log in again');
    }

    final trimmedChildHash = childHash.trim();
    if (trimmedChildHash.isEmpty) {
      throw ChatServiceException('Child hash is required');
    }

    // Ensure guardian has RSA keys (generates + uploads if missing)
    final guardianKeys = await _ensureGuardianKeys(email, password);

    // Fetch the guardian's ID from server (also verifies credentials)
    final guardianInfo = await _api.getGuardianPublicKey(
      email: email,
      password: password,
    );
    if (guardianInfo.guardianId == 0) {
      throw ChatServiceException('Could not retrieve guardian ID from server');
    }

    final localGuardianKey = guardianKeys.publicKeyPem.trim();
    final serverGuardianKey = guardianInfo.publicKey.trim();
    if (serverGuardianKey.isEmpty || serverGuardianKey != localGuardianKey) {
      try {
        await _api.setGuardianPublicKey(
          email: email,
          password: password,
          publicKey: localGuardianKey,
        );
        developer.log(
          'Guardian public key synced to server',
          name: 'ChatService',
        );
      } catch (e) {
        throw ChatServiceException(
          'Unable to sync guardian encryption keys. Please check your connection and try again.',
        );
      }
    }

    await _keyStore.saveGuardianId(email, guardianInfo.guardianId);

    // Fetch the child's public key (needed to encrypt outbound messages)
    final childInfo = await _api.getChildPublicKey(childHash: trimmedChildHash);
    if (childInfo.publicKey.isEmpty) {
      throw ChatServiceException(
        'Child has not set up encryption keys yet. '
        'Ask them to open the app and go to Chat once.',
      );
    }

    return _GuardianContext(
      email: email,
      password: password,
      childHash: trimmedChildHash,
      guardianId: guardianInfo.guardianId,
      guardianKeys: guardianKeys,
      childPublicKey: childInfo.publicKey,
    );
  }

  Future<_ChildContext> _loadChildContext({int? guardianId}) async {
    final session = await SessionService.getChildSession();
    final childHash = session['childHash'];
    if (childHash == null || childHash.trim().isEmpty) {
      throw ChatServiceException(
        'Child session is missing — please link this device to a child account first',
      );
    }

    final trimmedChildHash = childHash.trim();

    // Ensure child has RSA keys (generates + uploads if missing)
    final childKeys = await _ensureChildKeys(trimmedChildHash);

    // Resolve guardian ID (use passed-in or previously saved)
    int? resolvedGuardianId =
        guardianId ?? await _keyStore.loadChildGuardianId(trimmedChildHash);

    // Fetch all guardian public keys linked to this child
    final guardians = await _api.getChildGuardianPublicKeys(
      childHash: trimmedChildHash,
    );
    if (guardians.isEmpty) {
      throw ChatServiceException(
        'No guardian is linked to this child account. '
        'Ask your parent to connect via the Guardian app.',
      );
    }

    // Select the requested guardian or fall back to first
    final guardianInfo = resolvedGuardianId == null
        ? guardians.first
        : guardians.firstWhere(
            (entry) => entry.guardianId == resolvedGuardianId,
            orElse: () => guardians.first,
          );

    await _keyStore.saveChildGuardianId(
      trimmedChildHash,
      guardianInfo.guardianId,
    );

    if (guardianInfo.publicKey.isEmpty) {
      throw ChatServiceException(
        'Guardian has not set up encryption keys yet. '
        'Ask them to open the Guardian app and go to Chat once.',
      );
    }

    return _ChildContext(
      childHash: trimmedChildHash,
      guardianId: guardianInfo.guardianId,
      guardianPublicKey: guardianInfo.publicKey,
      childKeys: childKeys,
    );
  }

  // ── Key management ───────────────────────────────────────────────────

  /// Loads existing guardian keys or generates + uploads new ones.
  Future<ChatKeyPair> _ensureGuardianKeys(
    String email,
    String password,
  ) async {
    var keys = await _keyStore.loadGuardianKeys(email);
    if (keys != null && !_crypto.isValidKeyPair(keys)) {
      developer.log(
        'Stored guardian keys are invalid - regenerating',
        name: 'ChatService',
        level: 900,
      );
      keys = null;
    }
    if (keys == null) {
      developer.log(
        'Guardian keys not found locally — generating new RSA key pair',
        name: 'ChatService',
      );
      try {
        keys = _crypto.generateKeyPair();
      } catch (e) {
        developer.log(
          'Failed to generate guardian keys: $e',
          name: 'ChatService',
          level: 1000,
        );
        throw ChatServiceException(
          'Unable to generate encryption keys. Please try again.',
        );
      }
      await _keyStore.saveGuardianKeys(email, keys);
      // Upload public key to server so child can encrypt messages for us
      await _api.setGuardianPublicKey(
        email: email,
        password: password,
        publicKey: keys.publicKeyPem,
      );
      developer.log(
        'Guardian public key uploaded to server',
        name: 'ChatService',
      );
    }
    return keys;
  }

  /// Loads existing child keys or generates + uploads new ones.
  Future<ChatKeyPair> _ensureChildKeys(String childHash) async {
    var keys = await _keyStore.loadChildKeys(childHash);
    if (keys != null && !_crypto.isValidKeyPair(keys)) {
      developer.log(
        'Stored child keys are invalid - regenerating',
        name: 'ChatService',
        level: 900,
      );
      keys = null;
    }
    if (keys == null) {
      developer.log(
        'Child keys not found locally — generating new RSA key pair',
        name: 'ChatService',
      );
      try {
        keys = _crypto.generateKeyPair();
      } catch (e) {
        developer.log(
          'Failed to generate child keys: $e',
          name: 'ChatService',
          level: 1000,
        );
        throw ChatServiceException(
          'Unable to generate encryption keys. Please try again.',
        );
      }
      await _keyStore.saveChildKeys(childHash, keys);
    }

    final localChildKey = keys.publicKeyPem.trim();
    try {
      final serverInfo = await _api.getChildPublicKey(childHash: childHash);
      final serverChildKey = serverInfo.publicKey.trim();
      if (serverChildKey.isEmpty || serverChildKey != localChildKey) {
        await _api.setChildPublicKey(
          childHash: childHash,
          publicKey: localChildKey,
        );
        developer.log(
          'Child public key uploaded to server',
          name: 'ChatService',
        );
      }
    } catch (e) {
      developer.log(
        'Failed to sync child public key: $e',
        name: 'ChatService',
        level: 900,
      );
      throw ChatServiceException(
        'Unable to sync child encryption keys. Please check your connection and try again.',
      );
    }

    return keys;
  }

  // ── Decrypt helper ───────────────────────────────────────────────────

  String _decryptOrPlaceholder({
    required String ciphertext,
    required String privateKeyPem,
    String label = '',
  }) {
    if (ciphertext.trim().isEmpty) return '[Empty message]';
    try {
      return _crypto.decrypt(
        ciphertextBase64: ciphertext,
        privateKeyPem: privateKeyPem,
      );
    } catch (e) {
      developer.log(
        'Decryption failed [$label]: $e',
        name: 'ChatService',
        level: 900, // warning
      );
      return '[Unable to decrypt message]';
    }
  }
}

// ── Context value objects ────────────────────────────────────────────────────

class _GuardianContext {
  final String email;
  final String password;
  final String childHash;
  final int guardianId;
  final ChatKeyPair guardianKeys;
  final String childPublicKey;

  const _GuardianContext({
    required this.email,
    required this.password,
    required this.childHash,
    required this.guardianId,
    required this.guardianKeys,
    required this.childPublicKey,
  });
}

class _ChildContext {
  final String childHash;
  final int guardianId;
  final String guardianPublicKey;
  final ChatKeyPair childKeys;

  const _ChildContext({
    required this.childHash,
    required this.guardianId,
    required this.guardianPublicKey,
    required this.childKeys,
  });
}
