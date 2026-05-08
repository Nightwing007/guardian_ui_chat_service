import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthService {
  static const String baseUrl = 'https://seraphguardlabs.com';

  Future<Map<String, dynamic>> registerParent({
    required String name,
    required String email,
    required String password,
  }) async {
    print('AuthService.registerParent called');
    print('Attempting to connect to: $baseUrl/api/signup/');

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/signup/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Account created successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to create account',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('AuthService Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Network error: Please check your connection ($e)',
      };
    }
  }

  Future<Map<String, dynamic>> loginParent({
    required String email,
    required String password,
  }) async {
    print('AuthService.loginParent called');
    print('Attempting to connect to: $baseUrl/api/login/');

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Login successful', 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Invalid email or password',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('AuthService Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Network error: Please check your connection ($e)',
      };
    }
  }

  Future<Map<String, dynamic>> addChildAccount({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? dateOfBirth,
  }) async {
    print('AuthService.addChildAccount called');
    print('Attempting to connect to: $baseUrl/api/mobile/children/add/');

    try {
      final body = <String, dynamic>{'first_name': firstName};
      if (lastName != null) body['last_name'] = lastName;
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mobile/children/add/'),
            headers: {
              'Content-Type': 'application/json',
              'X-Auth-Email': email,
              'X-Auth-Password': password,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('addChildAccount status: ${response.statusCode}');
      debugPrint('addChildAccount body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Child account created successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to create child account',
        };
      }
    } catch (e, stackTrace) {
      print('addChildAccount error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> getChildUsage({
    required String email,
    required String password,
    required String childHash,
    String? date,
  }) async {
    print('AuthService.getChildUsage called for $childHash');
    final uri = Uri.parse(
      '$baseUrl/api/mobile/children/$childHash/usage',
    ).replace(queryParameters: date != null ? {'date': date} : null);

    try {
      final response = await http
          .get(uri, headers: {'X-Email': email, 'X-Password': password})
          .timeout(const Duration(seconds: 10));

      debugPrint('getChildUsage status: ${response.statusCode}');
      debugPrint('getChildUsage body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to fetch usage',
        };
      }
    } catch (e, stackTrace) {
      print('getChildUsage error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> getChildren({
    required String email,
    required String password,
  }) async {
    print('AuthService.getChildren called');
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/mobile/children/'),
            headers: {
              'Content-Type': 'application/json',
              'X-Email': email,
              'X-Password': password,
            },
          )
          .timeout(const Duration(seconds: 10));

      print('getChildren status: ${response.statusCode}');
      print('getChildren body: ${response.body}');

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to fetch children',
        };
      }
    } catch (e, stackTrace) {
      print('getChildren error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> generatePairingToken({
    required String email,
    required String password,
    required String childHash,
  }) async {
    print('AuthService.generatePairingToken called for $childHash');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/children/$childHash/pairing-token'),
            headers: {'X-Email': email, 'X-Password': password},
          )
          .timeout(const Duration(seconds: 10));

      print('generatePairingToken status: ${response.statusCode}');
      print('generatePairingToken body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to generate token',
        };
      }
    } catch (e, stackTrace) {
      print('generatePairingToken error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> claimPairingToken({
    required String pairingToken,
    required String deviceModel,
    required String platform,
  }) async {
    print('AuthService.claimPairingToken called');

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/pair/claim'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'pairing_token': pairingToken,
              'device_info': {'model': deviceModel, 'platform': platform},
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('claimPairingToken status: ${response.statusCode}');
      print('claimPairingToken body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'device_token': data['device_token'],
          'child_hash': data['child_hash'] ?? data['child']?['child_hash'],
          'child_name': data['child_name'] ?? data['child']?['name'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to claim pairing token',
        };
      }
    } catch (e, stackTrace) {
      print('claimPairingToken error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> syncInstalledApps({
    required String childHash,
    required String deviceToken,
    required List<Map<String, dynamic>> apps,
  }) async {
    print('AuthService.syncInstalledApps called');

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/children/$childHash/installed-apps/sync/'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-Token': deviceToken,
            },
            body: jsonEncode({'apps': apps}),
          )
          .timeout(const Duration(seconds: 30));

      print('syncInstalledApps status: ${response.statusCode}');
      print('syncInstalledApps body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to sync installed apps',
        };
      }
    } catch (e, stackTrace) {
      print('syncInstalledApps error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> getInstalledApps({
    required String email,
    required String password,
    required String childHash,
  }) async {
    print('AuthService.getInstalledApps called for $childHash');

    try {
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/api/mobile/children/$childHash/installed-apps/',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Email': email,
              'X-Password': password,
            },
          )
          .timeout(const Duration(seconds: 15));

      print('getInstalledApps status: ${response.statusCode}');
      print('getInstalledApps body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to fetch installed apps',
        };
      }
    } catch (e, stackTrace) {
      print('getInstalledApps error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> getAppLimits({
    required String email,
    required String password,
    required String childHash,
  }) async {
    print('AuthService.getAppLimits called for $childHash');

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/mobile/children/$childHash/app-limits/'),
            headers: {
              'Content-Type': 'application/json',
              'X-Email': email,
              'X-Password': password,
            },
          )
          .timeout(const Duration(seconds: 15));

      print('getAppLimits status: ${response.statusCode}');
      print('getAppLimits body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to fetch app limits',
        };
      }
    } catch (e, stackTrace) {
      print('getAppLimits error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> createAppLimit({
    required String email,
    required String password,
    required String childHash,
    required int installedAppId,
    required int limitMinutes,
  }) async {
    print('AuthService.createAppLimit called for $childHash');

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/mobile/children/$childHash/app-limits/'),
            headers: {
              'Content-Type': 'application/json',
              'X-Email': email,
              'X-Password': password,
            },
            body: jsonEncode({
              'installed_app_id': installedAppId,
              'limit_minutes': limitMinutes,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('createAppLimit status: ${response.statusCode}');
      print('createAppLimit body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to create app limit',
        };
      }
    } catch (e, stackTrace) {
      print('createAppLimit error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> updateAppLimit({
    required String email,
    required String password,
    required String childHash,
    required int limitId,
    required int limitMinutes,
    required bool isActive,
  }) async {
    print('AuthService.updateAppLimit called for $childHash');

    try {
      final response = await http
          .patch(
            Uri.parse(
              '$baseUrl/api/mobile/children/$childHash/app-limits/$limitId/',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Email': email,
              'X-Password': password,
            },
            body: jsonEncode({
              'limit_minutes': limitMinutes,
              'is_active': isActive,
            }),
          )
          .timeout(const Duration(seconds: 15));

      print('updateAppLimit status: ${response.statusCode}');
      print('updateAppLimit body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to update app limit',
        };
      }
    } catch (e, stackTrace) {
      print('updateAppLimit error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }

  Future<Map<String, dynamic>> deleteAppLimit({
    required String email,
    required String password,
    required String childHash,
    required int limitId,
  }) async {
    print('AuthService.deleteAppLimit called for $childHash');

    try {
      final response = await http
          .delete(
            Uri.parse(
              '$baseUrl/api/mobile/children/$childHash/app-limits/$limitId/',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Email': email,
              'X-Password': password,
            },
          )
          .timeout(const Duration(seconds: 15));

      print('deleteAppLimit status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to delete app limit',
        };
      }
    } catch (e, stackTrace) {
      print('deleteAppLimit error: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'message': 'Network error ($e)'};
    }
  }
}
