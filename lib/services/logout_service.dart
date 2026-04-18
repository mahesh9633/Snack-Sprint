import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config_service.dart';
import 'session_manager.dart';

class LogoutService {

  static final String _baseUrl = ApiConfig.indexPhp;

  /// Calls the logout API with the current session token, then clears local session.
  static Future<bool> logout() async {
    try {
      final token      = await SessionManager.getToken();
      final customerId = await SessionManager.getCustomerId();
      final telephone  = await SessionManager.getTelephone();

      if (token == null || token.isEmpty) {
        await SessionManager.clearSession();
        return true;
      }

      // ✅ FIXED — all params passed as proper query parameters
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'route':     'groceries/categories.logout',
          'token':     token,
          'api_token': token,
          if (customerId != null && customerId.isNotEmpty)
            'customer_id': customerId,
          if (telephone != null && telephone.isNotEmpty)
            'telephone': telephone,
        },
      );


      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));


      // Always clear local session regardless of API response
      await SessionManager.clearSession();
      return true;
    } catch (e) {
      // Always clear session even if API call fails
      await SessionManager.clearSession();
      return true;
    }
  }
}