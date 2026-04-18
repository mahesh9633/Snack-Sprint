import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';
final String kApiBase = ApiConfig.indexPhp;
final String kImgBase = ApiConfig.imageBase;

class ApiService {
  static Future<bool> validateToken({
    required String token,
    required String customerId,
  }) async {
    try {
      final result = await getInitialData(token: token, customerId: customerId);

      // ✅ Server confirmed token is valid
      if (result['success'] == true) {
        return true;
      }

      final message = result['message']?.toString().toLowerCase() ?? '';

      //  Only clear session on explicit auth/token errors
      final isAuthError = message.contains('unauthorized') ||
          message.contains('invalid token') ||
          message.contains('token expired') ||
          message.contains('expired') ||
          message.contains('401') ||
          message.contains('unauthenticated');

      if (isAuthError) {

        return false;
      }

      return true;

    } catch (e) {

      return true;
    }
  }

  // ─── Send OTP ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendOtp(String telephone) async {
    final uri = Uri.parse('$kApiBase?route=groceries/categories.send_otp');
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {'telephone': telephone},
      ).timeout(const Duration(seconds: 15));


      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) return data;
          if (data is List && data.isNotEmpty) return data.first as Map<String, dynamic>;
          return {'success': false, 'message': 'Unexpected response format'};
        } catch (_) {
          return {'success': false, 'message': 'Invalid server response', 'raw': response.body};
        }
      }
      return {'success': false, 'message': 'HTTP ${response.statusCode}: ${response.reasonPhrase}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── Verify OTP ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyOtp({
    required String telephone,
    required String otp,
    String? otpRef,
  }) async {
    final uri = Uri.parse('$kApiBase?route=groceries/categories.verify_otp');
    final Map<String, String> body = {'telephone': telephone, 'otp': otp};
    if (otpRef != null && otpRef.isNotEmpty) body['otp_ref'] = otpRef;

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));


      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            final bool ok = data['success'] == '1' ||
                data['success'] == 1 ||
                data['success'] == true;
            if (ok) {
            }
            return data;
          }
          return {'success': false, 'message': 'Unexpected response format'};
        } catch (_) {
          return {'success': false, 'message': 'Invalid server response', 'raw': response.body};
        }
      }
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── Get Initial Data ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getInitialData({
    String? customerId,
    String? token,
    String? mobile,
  }) async {
    final uri = Uri.parse(
      '$kApiBase?route=groceries/categories.getInitialData&token=$token&api_token=$token',
    );

    final Map<String, String> body = {};
    if (customerId != null && customerId.isNotEmpty) body['customer_id'] = customerId;
    if (mobile     != null && mobile.isNotEmpty)     body['mobile']      = mobile;
    if (token      != null && token.isNotEmpty) {
      body['token']      = token;
      body['api_token']  = token;
      body['auth_token'] = token;
    }

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (token != null && token.isNotEmpty) 'X-Auth-Token': token,
        },
        body: body,
      ).timeout(const Duration(seconds: 20));



      if (response.statusCode != 200 || response.body.isEmpty) {

        return {'success': false, 'message': 'Server error ${response.statusCode}'};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {'success': false, 'message': 'Invalid response format'};
      }

      final bool isSuccess = decoded['status']?.toString() == 'success' ||
          decoded['success'] == true ||
          decoded['success'] == 1 ||
          decoded['success'] == '1';


      if (isSuccess) return {'success': true, 'data': decoded};
      return {'success': false, 'message': decoded['message']?.toString() ?? 'Server error'};
    } catch (e, st) {

      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── Get Category Data ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getCategoryData({
    String? categoryId,
    String? token,
  }) async {
    final uri = Uri.parse(
      '$kApiBase?route=groceries/categories.getCategoryData&token=$token&api_token=$token',
    );

    final Map<String, String> body = {};
    if (categoryId != null && categoryId.isNotEmpty) {
      body['category_id'] = categoryId;
    }
    if (token != null && token.isNotEmpty) {
      body['token']      = token;
      body['api_token']  = token;
      body['auth_token'] = token;
    }

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (token != null && token.isNotEmpty) 'X-Auth-Token': token,
        },
        body: body,
      ).timeout(const Duration(seconds: 60));


      if (response.statusCode != 200 || response.body.isEmpty) {

        return {'success': false, 'message': 'Server error ${response.statusCode}'};
      }

      final raw = jsonDecode(response.body);
      if (raw is! Map<String, dynamic>) {
        return {'success': false, 'message': 'Invalid response format'};
      }

      final bool isSuccess = raw['status']?.toString() == 'success' ||
          raw['success'] == true ||
          raw['success'] == 1 ||
          raw['success'] == '1';

      final List<dynamic> subcategories =
      raw['subcategories'] is List ? raw['subcategories'] as List : [];
      final List<dynamic> products =
      raw['products'] is List ? raw['products'] as List : [];

      int nestedTotal = 0;
      for (final s in subcategories) {
        nestedTotal += ((s as Map)['products'] as List? ?? []).length;
      }

      for (int i = 0; i < subcategories.length; i++) {
        final s     = subcategories[i] as Map;
        final count = (s['products'] as List? ?? []).length;

      }

      if (isSuccess) {
        return {
          'success':       true,
          'data':          raw,
          'subcategories': subcategories,
          'products':      products,
        };
      }
      return {'success': false, 'message': raw['message']?.toString() ?? 'Unknown error'};
    } catch (e, st) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

// ─── Top-level aliases (used by home_mtl_screen.dart directly) ───────────────
Future<Map<String, dynamic>> getInitialData({
  String? customerId,
  String? token,
  String? mobile,
}) =>
    ApiService.getInitialData(customerId: customerId, token: token, mobile: mobile);

Future<Map<String, dynamic>> getCategoryData({
  String? categoryId,
  String? token,
}) =>
    ApiService.getCategoryData(categoryId: categoryId, token: token);