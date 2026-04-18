import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'api_server.dart';

class ProfileApiService {

  static Future<bool> validateToken(String token) async {
    try {
      final uri = Uri.parse(
        '$kApiBase?route=groceries/categories.getCategoryData'
            '&token=$token'
            '&api_token=$token',
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body);

      // Token is invalid if the server explicitly says so
      if (body is Map) {
        final status  = body['status']?.toString().toLowerCase();
        if (status == 'error') return false;

        final message = body['message']?.toString().toLowerCase() ?? '';
        if (message.contains('invalid token') ||
            message.contains('unauthorized')) {
          return false;
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    required String telephone,
    required String firstName,
    required String lastName,
    required String email,
    File? imageFile,
  }) async {

    // ── Step 1: validate token ─────────────────────────────────────
    final isValid = await validateToken(token);
    if (!isValid) {
      throw TokenInvalidException('Session expired. Please log in again.');
    }

    // ── Step 2: build request body ─────────────────────────────────
    final Map<String, dynamic> body = {
      'telephone': telephone,
      'firstname': firstName,
      'lastname':  lastName,
      'email':     email,
    };

    // Encode image to base64 if provided
    if (imageFile != null && imageFile.existsSync()) {
      final bytes = await imageFile.readAsBytes();
      body['image_base64'] = base64Encode(bytes);
    }

    // ── Step 3: call addProfile with token & api_token ─────────────
    final uri = Uri.parse(
      '$kApiBase?route=groceries/categories.addProfile'
          '&token=$token'
          '&api_token=$token',
    );

    final response = await http
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body:    jsonEncode(body),
    )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
          'Server error: ${response.statusCode} ${response.reasonPhrase}');
    }

    final Map<String, dynamic> result =
    jsonDecode(response.body) as Map<String, dynamic>;

    return result;
  }
}

// ── Custom Exception ──────────────────────────────────────────────────────────
class TokenInvalidException implements Exception {
  final String message;
  const TokenInvalidException(this.message);

  @override
  String toString() => message;
}