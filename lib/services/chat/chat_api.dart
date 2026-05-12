import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ChatApiException implements Exception {
  final String message;

  ChatApiException(this.message);

  @override
  String toString() => message;
}

class ChatMessageApi {
  final int id;
  final String senderType;
  final String messageEncrypted;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessageApi({
    required this.id,
    required this.senderType,
    required this.messageEncrypted,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessageApi.fromJson(Map<String, dynamic> json) {
    // Null-safe parse for id
    final id = json['id'];
    final parsedId = (id is int)
        ? id
        : (id is num)
            ? id.toInt()
            : int.tryParse(id?.toString() ?? '') ?? 0;

    // Null-safe parse for created timestamp
    final createdRaw = json['created']?.toString() ?? '';
    DateTime createdAt;
    try {
      createdAt = createdRaw.isNotEmpty
          ? DateTime.parse(createdRaw)
          : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }

    return ChatMessageApi(
      id: parsedId,
      senderType: json['sender_type']?.toString() ?? '',
      messageEncrypted: json['message_encrypted']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: createdAt,
    );
  }
}

class SendMessageResult {
  final int messageId;
  final DateTime createdAt;

  const SendMessageResult({required this.messageId, required this.createdAt});
}

class GuardianPublicKeyResult {
  final int guardianId;
  final String guardianName;
  final String publicKey;

  const GuardianPublicKeyResult({
    required this.guardianId,
    required this.guardianName,
    required this.publicKey,
  });
}

class ChildPublicKeyResult {
  final String childName;
  final String publicKey;

  const ChildPublicKeyResult({required this.childName, required this.publicKey});
}

class ChatApi {
  ChatApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://seraphguardlabs.com';

  final http.Client _client;
  final String _baseUrl;

  // ── Public Key endpoints ─────────────────────────────────────────────

  Future<GuardianPublicKeyResult> getGuardianPublicKey({
    required String email,
    required String password,
  }) async {
    final json = await _getJson(
      '/api/mobile/guardian/public-key/',
      headers: _guardianHeaders(email, password),
    );
    final rawId = json['guardian_id'];
    final guardianId = (rawId is int)
        ? rawId
        : (rawId is num)
            ? rawId.toInt()
            : int.tryParse(rawId?.toString() ?? '') ?? 0;

    return GuardianPublicKeyResult(
      guardianId: guardianId,
      guardianName: json['guardian_name']?.toString() ?? '',
      publicKey: json['public_key']?.toString() ?? '',
    );
  }

  Future<void> setGuardianPublicKey({
    required String email,
    required String password,
    required String publicKey,
  }) async {
    await _postJson(
      '/api/mobile/guardian/public-key/',
      headers: _guardianHeaders(email, password),
      body: {'public_key': publicKey},
    );
  }

  Future<ChildPublicKeyResult> getChildPublicKey({
    required String childHash,
  }) async {
    final json = await _getJson('/api/mobile/child/$childHash/public-key/');
    return ChildPublicKeyResult(
      childName: json['child_name']?.toString() ?? '',
      publicKey: json['public_key']?.toString() ?? '',
    );
  }

  /// Upload the child's public key to the server.
  /// The [childHash] is passed both in the URL and as an X-Child-Hash header
  /// so the backend can authenticate the request when needed.
  Future<void> setChildPublicKey({
    required String childHash,
    required String publicKey,
  }) async {
    await _postJson(
      '/api/mobile/child/$childHash/public-key/',
      headers: {'X-Child-Hash': childHash},
      body: {'public_key': publicKey},
    );
  }

  Future<List<GuardianPublicKeyResult>> getChildGuardianPublicKeys({
    required String childHash,
  }) async {
    final json =
        await _getJson('/api/mobile/child/$childHash/guardians/public-keys/');
    final guardians = json['guardians'];
    if (guardians is! List) return [];
    return guardians
        .whereType<Map>()
        .map((entry) {
          final rawId = entry['guardian_id'];
          final gId = (rawId is int)
              ? rawId
              : (rawId is num)
                  ? rawId.toInt()
                  : int.tryParse(rawId?.toString() ?? '') ?? 0;
          return GuardianPublicKeyResult(
            guardianId: gId,
            guardianName: entry['guardian_name']?.toString() ?? '',
            publicKey: entry['public_key']?.toString() ?? '',
          );
        })
        .toList();
  }

  // ── Chat message endpoints ───────────────────────────────────────────

  Future<List<ChatMessageApi>> getGuardianConversation({
    required String email,
    required String password,
    required String childHash,
    bool markRead = false,
  }) async {
    final query = markRead ? {'mark_read': 'true'} : const <String, String>{};
    final json = await _getJson(
      '/api/mobile/child/$childHash/chat/',
      headers: _guardianHeaders(email, password),
      query: query,
    );
    return _parseMessages(json['messages']);
  }

  Future<List<ChatMessageApi>> getChildConversation({
    required String childHash,
    required int guardianId,
    bool markRead = false,
  }) async {
    final query = markRead ? {'mark_read': 'true'} : const <String, String>{};
    final json = await _getJson(
      '/api/mobile/guardian/$guardianId/chat/',
      headers: {'X-Child-Hash': childHash},
      query: query,
    );
    return _parseMessages(json['messages']);
  }

  Future<SendMessageResult> sendGuardianMessage({
    required String email,
    required String password,
    required String childHash,
    required String messageEncrypted,
  }) async {
    final json = await _postJson(
      '/api/mobile/child/$childHash/chat/',
      headers: _guardianHeaders(email, password),
      body: {'message_encrypted': messageEncrypted},
    );
    return _parseSendResult(json);
  }

  Future<SendMessageResult> sendChildMessage({
    required String childHash,
    required int guardianId,
    required String messageEncrypted,
  }) async {
    final json = await _postJson(
      '/api/mobile/guardian/$guardianId/chat/',
      headers: {'X-Child-Hash': childHash},
      body: {'message_encrypted': messageEncrypted},
    );
    return _parseSendResult(json);
  }

  // ── Private helpers ──────────────────────────────────────────────────

  SendMessageResult _parseSendResult(Map<String, dynamic> json) {
    final rawId = json['message_id'];
    final messageId = (rawId is int)
        ? rawId
        : (rawId is num)
            ? rawId.toInt()
            : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final createdRaw = json['created']?.toString() ?? '';
    DateTime createdAt;
    try {
      createdAt = createdRaw.isNotEmpty
          ? DateTime.parse(createdRaw)
          : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }

    return SendMessageResult(messageId: messageId, createdAt: createdAt);
  }

  List<ChatMessageApi> _parseMessages(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((entry) => ChatMessageApi.fromJson(
              Map<String, dynamic>.from(entry),
            ))
        .toList();
  }

  Map<String, String> _guardianHeaders(String email, String password) {
    return {
      'Content-Type': 'application/json',
      'X-Email': email,
      'X-Password': password,
    };
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? headers,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    http.Response response;
    try {
      response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ChatApiException('Request timed out. Please try again.');
    } on SocketException {
      throw ChatApiException('Network error. Check your connection.');
    } catch (e) {
      throw ChatApiException('Request failed. $e');
    }
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body ?? const {}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ChatApiException('Request timed out. Please try again.');
    } on SocketException {
      throw ChatApiException('Network error. Check your connection.');
    } catch (e) {
      throw ChatApiException('Request failed. $e');
    }
    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Empty 2xx body — return empty map (e.g. 204 No Content)
        return const {};
      }
      throw ChatApiException(
        'Empty response from server (status ${response.statusCode})',
      );
    }

    dynamic json;
    try {
      json = jsonDecode(response.body);
    } catch (_) {
      throw ChatApiException(
        'Invalid JSON response (status ${response.statusCode})',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return Map<String, dynamic>.from(json);
      // 2xx but non-Map body (e.g. bare list or string) — return wrapper
      return {'data': json};
    }

    // Error response — extract message
    if (json is Map) {
      final message = json['error']?.toString() ??
          json['message']?.toString() ??
          json['detail']?.toString() ??
          'Request failed (status ${response.statusCode})';
      throw ChatApiException(message);
    }

    throw ChatApiException(
      'Request failed with status ${response.statusCode}',
    );
  }
}
