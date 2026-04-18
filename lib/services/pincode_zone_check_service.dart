import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config_service.dart'; // adjust import path as needed

class ZoneResult {
  final bool   available;
  final String zoneId;
  final String zoneName;
  final String error;

  const ZoneResult._({
    required this.available,
    this.zoneId   = '',
    this.zoneName = '',
    this.error    = '',
  });

  factory ZoneResult.available({required String zoneId, required String zoneName}) =>
      ZoneResult._(available: true, zoneId: zoneId, zoneName: zoneName);

  factory ZoneResult.unavailable() =>
      const ZoneResult._(available: false);

  factory ZoneResult.error(String message) =>
      ZoneResult._(available: false, error: message);

  bool get hasError => error.isNotEmpty;
}

class ZoneCheckService {
  static Future<ZoneResult> check({
    required String postcode,
    required String token,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.indexPhp}'
            '?route=groceries/categories.checkZone'
            '&token=$token'
            '&postcode=$postcode',
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return ZoneResult.error('Server error (${response.statusCode})');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['status'] == 'error') {
        return ZoneResult.error(body['message'] ?? 'Unknown error');
      }

      final available = body['available'] == true;
      if (available) {
        return ZoneResult.available(
          zoneId:   body['zone_id']?.toString()   ?? '',
          zoneName: body['zone_name']?.toString() ?? '',
        );
      }
      return ZoneResult.unavailable();
    } catch (e) {
      return ZoneResult.error(e.toString());
    }
  }
}