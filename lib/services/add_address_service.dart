// import 'package:flutter/foundation.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
//
// import 'api_config_service.dart';
// final String _kApiBase = ApiConfig.indexPhp;
//
// // ─── Response model ──────────────────────────────────────────────────────────
// class AddAddressResult {
//   final bool   success;
//   final int?   addressId;
//   final String message;
//
//   const AddAddressResult({
//     required this.success,
//     this.addressId,
//     this.message = '',
//   });
//
//   factory AddAddressResult.fromJson(Map<String, dynamic> json) {
//     final status = json['status']?.toString() ?? '';
//     return AddAddressResult(
//       success:   status == 'success',
//       addressId: json['address_id'] is int
//           ? json['address_id'] as int
//           : int.tryParse(json['address_id']?.toString() ?? ''),
//       message:   json['message']?.toString() ?? '',
//     );
//   }
//
//   factory AddAddressResult.error(String msg) =>
//       AddAddressResult(success: false, message: msg);
// }
//
// // ─── Delivery zone check result ──────────────────────────────────────────────
// class DeliveryZoneResult {
//   final bool    available;
//   final String  message;
//   final double? distanceKm;      // ✅ NEW
//   final double? deliveryCharge;  // ✅ NEW
//
//   const DeliveryZoneResult({
//     required this.available,
//     this.message = '',
//     this.distanceKm,
//     this.deliveryCharge,
//   });
// }
//
// // ─── API class ───────────────────────────────────────────────────────────────
// class AddAddressApi {
//
//   static Future<AddAddressResult> addAddress({
//     required String token,
//     required String customerId,
//     required String firstname,
//     String          lastname     = '',
//     String          contact      = '',
//     String          company      = '',
//     required String addressLine1,
//     String          addressLine2 = '',
//     required String city,
//     String          postcode     = '',
//     int             countryId    = 99,
//     int             zoneId       = 0,
//     bool            isDefault    = false,
//     String          tracking     = '',
//     double?         latitude,    // ✅ NEW
//     double?         longitude,   // ✅ NEW
//   }) async {
//
//     final uri = Uri.parse(
//       '$_kApiBase?route=groceries/categories.addAddress'
//           '&token=$token&api_token=$token',
//     );
//
//     final body = <String, String>{
//       'customer_id': customerId,
//       'firstname':   firstname,
//       'lastname':    lastname,
//       'contact':     contact,
//       'company':     company,
//       'address_1':   addressLine1,
//       'address_2':   addressLine2,
//       'city':        city,
//       'postcode':    postcode,
//       'country_id':  countryId.toString(),
//       'zone_id':     zoneId.toString(),
//       'default':     isDefault ? '1' : '0',
//       'tracking':    tracking,
//       if (latitude != null)  'latitude':  latitude.toString(),   // ✅ NEW
//       if (longitude != null) 'longitude': longitude.toString(),  // ✅ NEW
//       'token':       token,
//       'api_token':   token,
//       'auth_token':  token,
//     };
//
//     try {
//       final response = await http.post(
//         uri,
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//           'Accept':        'application/json',
//           if (token.isNotEmpty) 'Authorization': 'Bearer $token',
//           if (token.isNotEmpty) 'X-Auth-Token':  token,
//         },
//         body: body,
//       ).timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200 && response.body.isNotEmpty) {
//         try {
//           final data = jsonDecode(response.body);
//           if (data is Map<String, dynamic>) {
//             return AddAddressResult.fromJson(data);
//           }
//           return AddAddressResult.error('Unexpected response format');
//         } catch (_) {
//           return AddAddressResult.error('Invalid server response');
//         }
//       }
//       return AddAddressResult.error('Server error: ${response.statusCode}');
//     } catch (e) {
//       return AddAddressResult.error('Network error: $e');
//     }
//   }
//
//   // ✅ Checks whether a given lat/lng is within any store's delivery
//   // range on the backend, AND returns the exact delivery charge for that
//   // distance. Used both:
//   //   1. Live, right when a user pins a location (GPS or map picker)
//   //   2. When a user taps "Deliver here" on a saved address
//   // Does NOT save/update anything — read-only check.
//   static Future<DeliveryZoneResult> checkDeliveryZone({
//     required String token,
//     required double latitude,
//     required double longitude,
//   }) async {
//
//     final uri = Uri.parse(
//       '$_kApiBase?route=groceries/categories.checkDeliveryZone'
//           '&token=$token&api_token=$token',
//     );
//
//     final body = <String, String>{
//       'latitude':   latitude.toString(),
//       'longitude':  longitude.toString(),
//       'token':      token,
//       'api_token':  token,
//       'auth_token': token,
//     };
//
//     try {
//       final response = await http.post(
//         uri,
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//           'Accept':        'application/json',
//           if (token.isNotEmpty) 'Authorization': 'Bearer $token',
//           if (token.isNotEmpty) 'X-Auth-Token':  token,
//         },
//         body: body,
//       ).timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200 && response.body.isNotEmpty) {
//         try {
//           final data = jsonDecode(response.body);
//           if (data is Map<String, dynamic>) {
//             final status  = data['status']?.toString() ?? 'error';
//             final message = data['message']?.toString() ??
//                 'Something went wrong. Please try again.';
//             final d = data['data'] as Map<String, dynamic>?;
//
//             return DeliveryZoneResult(
//               available:      status == 'success',
//               message:        message,
//               distanceKm:     d != null ? double.tryParse(d['distance']?.toString() ?? '') : null,
//               deliveryCharge: d != null ? double.tryParse(d['delivery_charge']?.toString() ?? '') : null,
//             );
//           }
//           return DeliveryZoneResult(
//             available: false,
//             message: 'Unexpected response format',
//           );
//         } catch (_) {
//           return DeliveryZoneResult(
//             available: false,
//             message: 'Invalid server response',
//           );
//         }
//       }
//       return DeliveryZoneResult(
//         available: false,
//         message: 'Server error: ${response.statusCode}',
//       );
//     } catch (e) {
//       return DeliveryZoneResult(available: false, message: 'Network error: $e');
//     }
//   }
//
//   // ✅ Deletes a saved address on the backend.
//   static Future<AddAddressResult> deleteAddress({
//     required String token,
//     required String addressId,
//   }) async {
//
//     final uri = Uri.parse(
//       '$_kApiBase?route=groceries/categories.deleteAddress'
//           '&token=$token&api_token=$token',
//     );
//
//     final body = <String, String>{
//       'address_id': addressId,
//       'token':      token,
//       'api_token':  token,
//       'auth_token': token,
//     };
//
//     try {
//       final response = await http.post(
//         uri,
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//           'Accept':        'application/json',
//           if (token.isNotEmpty) 'Authorization': 'Bearer $token',
//           if (token.isNotEmpty) 'X-Auth-Token':  token,
//         },
//         body: body,
//       ).timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200 && response.body.isNotEmpty) {
//         try {
//           final data = jsonDecode(response.body);
//           if (data is Map<String, dynamic>) {
//             return AddAddressResult.fromJson(data);
//           }
//           return AddAddressResult.error('Unexpected response format');
//         } catch (_) {
//           return AddAddressResult.error('Invalid server response');
//         }
//       }
//       return AddAddressResult.error('Server error: ${response.statusCode}');
//     } catch (e) {
//       return AddAddressResult.error('Network error: $e');
//     }
//   }
// }

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

// ─── Delivery zone check result ──────────────────────────────────────────────
class DeliveryZoneResult {
  final bool    available;
  final String  message;
  final double? distanceKm;
  final double? deliveryCharge;

  const DeliveryZoneResult({
    required this.available,
    this.message = '',
    this.distanceKm,
    this.deliveryCharge,
  });
}

// ─── API class ───────────────────────────────────────────────────────────────
class AddAddressApi {

  static Future<AddAddressResult> addAddress({
    required String token,
    required String customerId,
    required String firstname,
    String          lastname     = '',
    String          contact      = '',
    String          company      = '',
    required String addressLine1,
    String          addressLine2 = '',
    required String city,
    String          postcode     = '',
    int             countryId    = 99,
    int             zoneId       = 0,
    bool            isDefault    = false,
    String          tracking     = '',
    double?         latitude,
    double?         longitude,
  }) async {

    final uri = Uri.parse(
      '$_kApiBase?route=groceries/categories.addAddress'
          '&token=$token&api_token=$token',
    );

    final body = <String, String>{
      'customer_id': customerId,
      'firstname':   firstname,
      'lastname':    lastname,
      'contact':     contact,
      'company':     company,
      'address_1':   addressLine1,
      'address_2':   addressLine2,
      'city':        city,
      'postcode':    postcode,
      'country_id':  countryId.toString(),
      'zone_id':     zoneId.toString(),
      'default':     isDefault ? '1' : '0',
      'tracking':    tracking,
      if (latitude != null)  'latitude':  latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
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

  // ✅ NEW — edits an existing address. Same lat/lng handling as
  // addAddress: if provided, backend validates delivery range for the
  // new location before saving.
  static Future<AddAddressResult> editAddress({
    required String token,
    required String addressId,
    required String firstname,
    String          lastname     = '',
    String          contact      = '',
    String          company      = '',
    required String addressLine1,
    String          addressLine2 = '',
    required String city,
    String          postcode     = '',
    int             countryId    = 99,
    int             zoneId       = 0,
    bool            isDefault    = false,
    String          tracking     = '',
    double?         latitude,
    double?         longitude,
  }) async {

    final uri = Uri.parse(
      '$_kApiBase?route=groceries/categories.editAddress'
          '&token=$token&api_token=$token',
    );

    final body = <String, String>{
      'address_id':  addressId,
      'firstname':   firstname,
      'lastname':    lastname,
      'contact':     contact,
      'company':     company,
      'address_1':   addressLine1,
      'address_2':   addressLine2,
      'city':        city,
      'postcode':    postcode,
      'country_id':  countryId.toString(),
      'zone_id':     zoneId.toString(),
      'default':     isDefault ? '1' : '0',
      'tracking':    tracking,
      if (latitude != null)  'latitude':  latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
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

  // ✅ Checks whether a given lat/lng is within any store's delivery
  // range on the backend, AND returns the exact delivery charge for that
  // distance. Used both:
  //   1. Live, right when a user pins a location (GPS or map picker)
  //   2. When a user taps "Deliver here" on a saved address
  // Does NOT save/update anything — read-only check.
  static Future<DeliveryZoneResult> checkDeliveryZone({
    required String token,
    required double latitude,
    required double longitude,
  }) async {

    final uri = Uri.parse(
      '$_kApiBase?route=groceries/categories.checkDeliveryZone'
          '&token=$token&api_token=$token',
    );

    final body = <String, String>{
      'latitude':   latitude.toString(),
      'longitude':  longitude.toString(),
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
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          if (token.isNotEmpty) 'X-Auth-Token':  token,
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            final status  = data['status']?.toString() ?? 'error';
            final message = data['message']?.toString() ??
                'Something went wrong. Please try again.';
            final d = data['data'] as Map<String, dynamic>?;

            return DeliveryZoneResult(
              available:      status == 'success',
              message:        message,
              distanceKm:     d != null ? double.tryParse(d['distance']?.toString() ?? '') : null,
              deliveryCharge: d != null ? double.tryParse(d['delivery_charge']?.toString() ?? '') : null,
            );
          }
          return DeliveryZoneResult(
            available: false,
            message: 'Unexpected response format',
          );
        } catch (_) {
          return DeliveryZoneResult(
            available: false,
            message: 'Invalid server response',
          );
        }
      }
      return DeliveryZoneResult(
        available: false,
        message: 'Server error: ${response.statusCode}',
      );
    } catch (e) {
      return DeliveryZoneResult(available: false, message: 'Network error: $e');
    }
  }

  // ✅ Deletes a saved address on the backend.
  static Future<AddAddressResult> deleteAddress({
    required String token,
    required String addressId,
  }) async {

    final uri = Uri.parse(
      '$_kApiBase?route=groceries/categories.deleteAddress'
          '&token=$token&api_token=$token',
    );

    final body = <String, String>{
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