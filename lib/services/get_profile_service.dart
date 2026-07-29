import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/session_manager.dart';
import 'api_config_service.dart';

class ProfileGetApiService {
  static Future<Map<String, dynamic>> getProfile() async {
    final token   = await SessionManager.getToken() ?? '';
    final baseUrl = ApiConfig.baseUrl;

    final url = Uri.parse(
      '$baseUrl/index.php?route=groceries/categories.getProfile&token=$token',
    );

    try {
      final response = await http.post(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {


        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['status'] == 'success') {
          return {'success': true, 'data': json['data']};
        } else {
          return {'success': false, 'message': json['message'] ?? 'Failed to load profile'};
        }
      } else {
        return {'success': false, 'message': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}