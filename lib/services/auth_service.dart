import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.20.10:8000';

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
      return {
        'success': false,
        'message': 'Network error ($e)',
      };
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
            headers: {
              'X-Email': email,
              'X-Password': password,
            },
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
}
