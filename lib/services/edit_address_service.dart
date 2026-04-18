import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config_service.dart';

// ─── Response model ──────────────────────────────────────────────────────────
class EditAddressResult {
  final bool success;
  final String message;

  const EditAddressResult({
    required this.success,
    required this.message,
  });
}

// ─── API class ───────────────────────────────────────────────────────────────
class EditAddressApi {
  static final String _baseUrl = ApiConfig.indexPhp;
  static const String _route   = 'groceries/categories.editAddress';

  static Future<EditAddressResult> editAddress({
    required String token,
    required String addressId,
    required String firstname,
    required String lastname,
    required String contact,
    required String company,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String postcode,
    int countryId = 99,
    int zoneId = 0,
    bool isDefault = false,   // ← ADD
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?route=$_route&token=$token&api_token=$token',
      );

      // ✅ Send as form-encoded (same pattern as add/cancel order APIs)
      final body = <String, String>{
        'address_id': addressId,
        'firstname': firstname,
        'lastname': lastname,
        'contact': contact,
        'company': company,
        'address_1': addressLine1,
        'address_2': addressLine2,
        'city': city,
        'postcode': postcode,
        'country_id': countryId.toString(),
        'zone_id': zoneId.toString(),
        'default': isDefault ? '1' : '0',  // ← ADD
        'token': token,
        'api_token': token,
        'auth_token': token,
      };

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (token.isNotEmpty) 'X-Auth-Token': token,
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      final rawBody = response.body.trim();


      if (response.statusCode == 200 && rawBody.isNotEmpty) {
        // Guard against HTML error pages
        if (!rawBody.startsWith('{')) {
          return const EditAddressResult(
            success: false,
            message: 'Invalid server response',
          );
        }

        try {
          final data = jsonDecode(rawBody) as Map<String, dynamic>;
          final status = data['status']?.toString() ?? '';

          if (status == 'success') {
            return EditAddressResult(
              success: true,
              message: data['message']?.toString() ??
                  'Address updated successfully',
            );
          } else {
            return EditAddressResult(
              success: false,
              message: data['message']?.toString() ??
                  'Failed to update address',
            );
          }
        } catch (_) {
          return const EditAddressResult(
            success: false,
            message: 'Invalid server response',
          );
        }
      }

      return EditAddressResult(
        success: false,
        message: 'Server error: ${response.statusCode}',
      );
    } on http.ClientException catch (e) {
      return EditAddressResult(
        success: false,
        message: 'Network error: ${e.message}',
      );
    } catch (e) {
      return EditAddressResult(
        success: false,
        message: 'Unexpected error: $e',
      );
    }
  }
}