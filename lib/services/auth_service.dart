import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'http://192.168.1.4:8000';

  Future<Map<String, dynamic>> registerParent({
    required String name,
    required String email,
    required String password,
  }) async {
    print('AuthService.registerParent called');
    print('Attempting to connect to: $baseUrl/api/signup/');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/signup/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('AuthService Error: $e');
      print('Stack trace: $stackTrace');
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/login/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Login successful',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Invalid email or password',
        };
      }
    } catch (e, stackTrace) {
      print('AuthService Error: $e');
      print('Stack trace: $stackTrace');
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
      final body = <String, dynamic>{
        'first_name': firstName,
      };
      if (lastName != null) body['last_name'] = lastName;
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;

      final response = await http.post(
        Uri.parse('$baseUrl/api/mobile/children/add/'),
        headers: {
          'Content-Type': 'application/json',
          'X-Auth-Email': email,
          'X-Auth-Password': password,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('addChildAccount status: ${response.statusCode}');
      print('addChildAccount body: ${response.body}');

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
    final uri = Uri.parse('$baseUrl/api/mobile/children/$childHash/usage')
        .replace(queryParameters: date != null ? {'date': date} : null);

    try {
      final response = await http.get(
        uri,
        headers: {
          'X-Email': email,
          'X-Password': password,
        },
      ).timeout(const Duration(seconds: 10));

      print('getChildUsage status: ${response.statusCode}');
      print('getChildUsage body: ${response.body}');

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
      return {
        'success': false,
        'message': 'Network error ($e)',
      };
    }
  }
}
