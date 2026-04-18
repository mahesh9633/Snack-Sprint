import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config_service.dart';

// ── Return Order Result Model ─────────────────────────────────────────────────

class ReturnOrderResult {
  final bool success;
  final String message;

  const ReturnOrderResult({
    required this.success,
    required this.message,
  });
}

// ── Return Order API ──────────────────────────────────────────────────────────

class ReturnOrderApi {
  static Future<ReturnOrderResult> returnOrder({
    required String token,
    required String orderId,
  }) async {
    try {
      final uri = Uri.parse(
        ApiConfig.route('groceries/categories.returnOrder', token: token),
      );

      final response = await http
          .post(
        uri,
        body: {'order_id': orderId},
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body) as Map<String, dynamic>;
        final status  = data['status']?.toString()  ?? '';
        final message = data['message']?.toString() ?? '';

        if (status == 'success') {
          return ReturnOrderResult(success: true, message: message);
        } else {
          return ReturnOrderResult(
            success: false,
            message: message.isNotEmpty
                ? message
                : 'Return failed. Please try again.',
          );
        }
      } else {
        return ReturnOrderResult(
          success: false,
          message: 'Server error (${response.statusCode}). Try again.',
        );
      }
    } catch (e) {
      return ReturnOrderResult(
        success: false,
        message: 'Network error. Check your connection.',
      );
    }
  }
}