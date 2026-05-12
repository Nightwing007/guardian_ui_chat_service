import 'dart:io';

import 'package:myapp/services/chat/chat_api.dart';
import 'package:myapp/services/chat/chat_crypto.dart';

Future<void> main() async {
  final email = Platform.environment['GUARDIAN_EMAIL'];
  final password = Platform.environment['GUARDIAN_PASSWORD'];
  final childHash = Platform.environment['CHILD_HASH'];
  final baseUrl = Platform.environment['CHAT_BASE_URL'];

  if (email == null || password == null || childHash == null) {
    stderr.writeln('Missing required environment variables.');
    stderr.writeln('Set GUARDIAN_EMAIL, GUARDIAN_PASSWORD, and CHILD_HASH.');
    stderr.writeln('Optional: CHAT_BASE_URL (defaults to https://seraphguardlabs.com)');
    exit(64);
  }

  final api = ChatApi(baseUrl: baseUrl);
  final crypto = ChatCrypto();

  stdout.writeln('Generating RSA keys...');
  final guardianKeys = crypto.generateKeyPair();
  final childKeys = crypto.generateKeyPair();

  stdout.writeln('Uploading public keys...');
  await api.setGuardianPublicKey(
    email: email,
    password: password,
    publicKey: guardianKeys.publicKeyPem,
  );
  await api.setChildPublicKey(
    childHash: childHash,
    publicKey: childKeys.publicKeyPem,
  );

  final guardianInfo = await api.getGuardianPublicKey(
    email: email,
    password: password,
  );

  stdout.writeln('Testing guardian -> child message...');
  final guardianPlaintext =
      'Guardian test message at ${DateTime.now().toIso8601String()}';
  final guardianCiphertext = crypto.encrypt(
    plaintext: guardianPlaintext,
    publicKeyPem: childKeys.publicKeyPem,
  );
  final guardianSend = await api.sendGuardianMessage(
    email: email,
    password: password,
    childHash: childHash,
    messageEncrypted: guardianCiphertext,
  );

  final childMessages = await api.getChildConversation(
    childHash: childHash,
    guardianId: guardianInfo.guardianId,
    markRead: true,
  );
  final childMessage = childMessages.firstWhere(
    (msg) => msg.id == guardianSend.messageId,
    orElse: () => throw StateError('Child did not receive guardian message'),
  );
  final decryptedByChild = crypto.decrypt(
    ciphertextBase64: childMessage.messageEncrypted,
    privateKeyPem: childKeys.privateKeyPem,
  );
  if (decryptedByChild != guardianPlaintext) {
    throw StateError('Child decryption failed');
  }

  stdout.writeln('Testing child -> guardian message...');
  final childPlaintext =
      'Child test message at ${DateTime.now().toIso8601String()}';
  final childCiphertext = crypto.encrypt(
    plaintext: childPlaintext,
    publicKeyPem: guardianKeys.publicKeyPem,
  );
  final childSend = await api.sendChildMessage(
    childHash: childHash,
    guardianId: guardianInfo.guardianId,
    messageEncrypted: childCiphertext,
  );

  final guardianMessages = await api.getGuardianConversation(
    email: email,
    password: password,
    childHash: childHash,
    markRead: true,
  );
  final guardianMessage = guardianMessages.firstWhere(
    (msg) => msg.id == childSend.messageId,
    orElse: () => throw StateError('Guardian did not receive child message'),
  );
  final decryptedByGuardian = crypto.decrypt(
    ciphertextBase64: guardianMessage.messageEncrypted,
    privateKeyPem: guardianKeys.privateKeyPem,
  );
  if (decryptedByGuardian != childPlaintext) {
    throw StateError('Guardian decryption failed');
  }

  stdout.writeln('E2E chat smoke test passed.');
}
