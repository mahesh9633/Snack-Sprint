import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config_service.dart';
final String _kApiBase = ApiConfig.indexPhp;
// ─── Response model ──────────────────────────────────────────────────────────
class CancelOrderResult {
  final bool success;
  final String message;

  const CancelOrderResult({
    required this.success,
    this.message = '',
  });

  factory CancelOrderResult.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    return CancelOrderResult(
      success: status == 'success',
      message: json['message']?.toString() ?? '',
    );
  }

  factory CancelOrderResult.error(String msg) =>
      CancelOrderResult(success: false, message: msg);
}

// ─── API class ───────────────────────────────────────────────────────────────
class CancelOrderApi {
  static Future<CancelOrderResult> cancelOrder({
    required String token,
    required String orderId,
  }) async {
    final uri = Uri.parse(
      '$_kApiBase?route=groceries/categories.cancelOrder'
          '&token=$token&api_token=$token',
    );

    final body = <String, String>{
      'order_id': orderId,
      'token': token,
      'api_token': token,
      'auth_token': token,
    };


    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (token.isNotEmpty) 'X-Auth-Token': token,
        },
        body: body,
      ).timeout(const Duration(seconds: 15));


      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final rawBody = response.body.trim();
          final data = jsonDecode(rawBody);
          if (data is Map<String, dynamic>) {
            return CancelOrderResult.fromJson(data);
          }
          return CancelOrderResult.error('Unexpected response format');
        } catch (_) {
          return CancelOrderResult.error('Invalid server response');
        }
      }
      return CancelOrderResult.error('Server error: ${response.statusCode}');
    } catch (e) {
      return CancelOrderResult.error('Network error: $e');
    }
  }
}