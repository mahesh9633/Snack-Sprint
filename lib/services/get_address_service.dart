import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../model/address_model.dart';
import 'api_config_service.dart';

class GetAddressApi {
  static final String _baseUrl = ApiConfig.indexPhp;
  static const String _route   = 'groceries/categories.getAddress';

  static Future<List<AddressModel>> getAddresses({
    required String token,


  }) async {
    try {
      final uri = Uri.parse('$_baseUrl?route=$_route&token=$token');

      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      final rawBody  = response.body.trim();

      if (response.statusCode != 200) return [];
      if (!rawBody.startsWith('{'))   return [];

      final data   = jsonDecode(rawBody) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      if (status != 'success') return [];

      final list = data['data'] as List? ?? [];
      debugPrint('🔵 RAW ADDRESS LIST: $list');
      return list.map((e) {
        final m          = e as Map<String, dynamic>;
        final addressId  = m['address_id']?.toString() ?? '';
        final firstname  = m['firstname']?.toString()  ?? '';
        final lastname   = m['lastname']?.toString()   ?? '';
        final fullName   = '$firstname $lastname'.trim();
        final company    = m['company']?.toString()    ?? '';
        final address1   = m['address_1']?.toString()  ?? '';
        final address2   = m['address_2']?.toString()  ?? '';
        final city       = m['city']?.toString()        ?? '';
        final postcode   = m['postcode']?.toString()    ?? '';
        final rawContact = m['contact']?.toString()     ?? '';
        final contact    = (rawContact.isNotEmpty && rawContact != '0')
            ? rawContact
            : (m['telephone']?.toString() ?? '');
        final isDefault  = m['default']?.toString() == '1';
        final tracking   = m['tracking']?.toString() ?? '';

        // ✅ Parse lat/lng from dedicated columns first.
        final rawLat = m['latitude']?.toString()  ?? '';
        final rawLng = m['longitude']?.toString() ?? '';
        double? lat  = rawLat.isNotEmpty ? double.tryParse(rawLat) : null;
        double? lng  = rawLng.isNotEmpty ? double.tryParse(rawLng) : null;

        // ✅ FALLBACK — older addresses saved before GPS capture have empty
        // latitude/longitude columns, but often still have coordinates
        // embedded in the Google Maps `tracking` link. Extract them from
        // there if the dedicated columns are missing.
        if (lat == null || lng == null) {
          final trackingUrl = m['tracking']?.toString() ?? '';
          final match = RegExp(r'destination=(-?\d+\.\d+),(-?\d+\.\d+)')
              .firstMatch(trackingUrl);
          if (match != null) {
            lat = double.tryParse(match.group(1)!);
            lng = double.tryParse(match.group(2)!);
          }
        }

        final knownLabels = ['Home', 'Office', 'Other'];
        final name = knownLabels.contains(company) ? company : 'Home';

        return AddressModel(
          id:           addressId,
          name:         name,
          fullName:     fullName,
          phone:        contact,
          addressLine1: address1,
          addressLine2: address2,
          city:         city,
          state:        '',
          pinCode:      postcode,
          isDefault:    isDefault,
          latitude:     lat,   // ✅ NEW
          longitude:    lng,   // ✅ NEW
          tracking:     tracking.isNotEmpty ? tracking : null,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}