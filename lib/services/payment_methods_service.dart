import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/session_manager.dart';
import 'api_config_service.dart';

class PaymentMethodsApiService {
  /// Fetches the store's payment methods, filtered by store_id.
  /// This is a completely separate API call from getProfile — it hits
  /// the groceries/categories.getPaymentMethods route (the same one the
  /// admin app already uses to manage payment methods).
  static Future<Map<String, dynamic>> getPaymentMethods(String storeId) async {
    final token   = await SessionManager.getToken() ?? '';
    final baseUrl = ApiConfig.baseUrl;

    final url = Uri.parse(
      '$baseUrl/index.php?route=groceries/categories.getPaymentMethods&token=$token&store_id=$storeId',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['status'] == 'success') {
          return {'success': true, 'data': json['data']};
        } else {
          return {
            'success': false,
            'message': json['message'] ?? 'Failed to load payment methods',
          };
        }
      } else {
        return {'success': false, 'message': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}