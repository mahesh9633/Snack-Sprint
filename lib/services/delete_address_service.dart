import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_server.dart';

class DeleteAddressResult {
  final bool   success;
  final String message;
  const DeleteAddressResult({required this.success, required this.message});
}

class DeleteAddressApi {
  static Future<DeleteAddressResult> deleteAddress({
    required String token,
    required String addressId,
  }) async {
    // ✅ Token in URL — same pattern as getInitialData / getCategoryData
    final uri = Uri.parse(
      '$kApiBase?route=groceries/categories.deleteAddress&token=$token&api_token=$token',
    );

    final body = {
      'address_id': addressId,
      'token':      token,
      'api_token':  token,
      'auth_token': token,
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
          'X-Auth-Token':  token,
        },
        body: body,
      ).timeout(const Duration(seconds: 15));


      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';

      if (response.statusCode == 200 && status == 'success') {
        return DeleteAddressResult(
          success: true,
          message: data['message'] as String? ?? 'Address deleted successfully',
        );
      }

      return DeleteAddressResult(
        success: false,
        message: data['message'] as String? ?? 'Failed to delete address',
      );
    } catch (e) {
      return DeleteAddressResult(success: false, message: 'Network error: $e');
    }
  }
}