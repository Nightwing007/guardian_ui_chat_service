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
}
