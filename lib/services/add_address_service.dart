import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config_service.dart';
final String _kApiBase = ApiConfig.indexPhp;

// ─── Response model ──────────────────────────────────────────────────────────
class AddAddressResult {
  final bool   success;
  final int?   addressId;
  final String message;

  const AddAddressResult({
    required this.success,
    this.addressId,
    this.message = '',
  });

  factory AddAddressResult.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    return AddAddressResult(
      success:   status == 'success',
      addressId: json['address_id'] is int
          ? json['address_id'] as int
          : int.tryParse(json['address_id']?.toString() ?? ''),
      message:   json['message']?.toString() ?? '',
    );
  }

  factory AddAddressResult.error(String msg) =>
      AddAddressResult(success: false, message: msg);
}

// ─── API class ───────────────────────────────────────────────────────────────
class AddAddressApi {

  static Future<AddAddressResult> addAddress({
    required String token,
    required String customerId,
    required String firstname,
    String          lastname     = '',
    String          contact      = '',   // ✅ ADDED - per-address phone number
    String          company      = '',
    required String addressLine1,
    String          addressLine2 = '',
    required String city,
    String          postcode     = '',
    int             countryId    = 99,
    int             zoneId       = 0,
    bool            isDefault    = false,   // ← ADD
    String          tracking          = '',
  }) async {

    final uri = Uri.parse(
      '$_kApiBase?route=groceries/categories.addAddress'
          '&token=$token&api_token=$token',
    );

    final body = <String, String>{
      'customer_id': customerId,
      'firstname':   firstname,
      'lastname':    lastname,
      'contact':     contact,      // ✅ ADDED - sends phone to server
      'company':     company,
      'address_1':   addressLine1,
      'address_2':   addressLine2,
      'city':        city,
      'postcode':    postcode,
      'country_id':  countryId.toString(),
      'zone_id':     zoneId.toString(),
      'default':     isDefault ? '1' : '0',  // ← ADD
      'tracking':    tracking,
      'token':       token,
      'api_token':   token,
      'auth_token':  token,
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept':        'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (token.isNotEmpty) 'X-Auth-Token':  token,
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            return AddAddressResult.fromJson(data);
          }
          return AddAddressResult.error('Unexpected response format');
        } catch (_) {
          return AddAddressResult.error('Invalid server response');
        }
      }
      return AddAddressResult.error('Server error: ${response.statusCode}');
    } catch (e) {
      return AddAddressResult.error('Network error: $e');
    }
  }
}