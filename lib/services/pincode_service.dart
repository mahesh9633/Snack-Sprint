import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class PostOffice {
  final String name;
  final String branchType;
  final String deliveryStatus;
  final String circle;
  final String district;
  final String division;
  final String region;
  final String block;
  final String state;
  final String country;
  final String pincode;

  const PostOffice({
    required this.name,
    required this.branchType,
    required this.deliveryStatus,
    required this.circle,
    required this.district,
    required this.division,
    required this.region,
    required this.block,
    required this.state,
    required this.country,
    required this.pincode,
  });

  factory PostOffice.fromJson(Map<String, dynamic> json) {
    return PostOffice(
      name:           json['Name']?.toString()           ?? '',
      branchType:     json['BranchType']?.toString()     ?? '',
      deliveryStatus: json['DeliveryStatus']?.toString() ?? '',
      circle:         json['Circle']?.toString()         ?? '',
      district:       json['District']?.toString()       ?? '',
      division:       json['Division']?.toString()       ?? '',
      region:         json['Region']?.toString()         ?? '',
      block:          json['Block']?.toString()          ?? '',
      state:          json['State']?.toString()          ?? '',
      country:        json['Country']?.toString()        ?? '',
      pincode:        json['Pincode']?.toString()        ?? '',
    );
  }

  @override
  String toString() => '$name, $district, $state $pincode';
}

/// Result object returned by PincodeService.lookup()
class PincodeResult {
  /// True if the API returned valid data
  final bool isSuccess;

  /// Error message if isSuccess is false
  final String error;

  /// Primary post office name (first result)
  final String area;

  /// District / City
  final String city;

  /// State
  final String state;

  /// Country
  final String country;

  /// Pincode
  final String pincode;

  /// All post offices for this pincode
  final List<PostOffice> allOffices;

  const PincodeResult._({
    required this.isSuccess,
    required this.error,
    required this.area,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
    required this.allOffices,
  });

  /// Success factory
  factory PincodeResult.success({
    required String area,
    required String city,
    required String state,
    required String country,
    required String pincode,
    required List<PostOffice> allOffices,
  }) =>
      PincodeResult._(
        isSuccess:  true,
        error:      '',
        area:       area,
        city:       city,
        state:      state,
        country:    country,
        pincode:    pincode,
        allOffices: allOffices,
      );

  /// Failure factory
  factory PincodeResult.failure(String error) => PincodeResult._(
    isSuccess:  false,
    error:      error,
    area:       '',
    city:       '',
    state:      '',
    country:    '',
    pincode:    '',
    allOffices: [],
  );

  /// Convenience: full formatted address string
  String get fullAddress {
    final parts = [area, city, state, pincode]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

class PincodeService {
  PincodeService._(); // prevent instantiation — use static methods only

  static const String   _baseUrl = 'https://api.postalpincode.in/pincode';
  static const Duration _timeout = Duration(seconds: 10);

  static Future<PincodeResult> lookup(String pincode) async {
    // ── Validate locally first ───────────────────────────────────────────
    final cleaned = pincode.trim();
    if (cleaned.isEmpty) {
      return PincodeResult.failure('Pincode cannot be empty');
    }
    if (cleaned.length != 6) {
      return PincodeResult.failure('Enter a valid 6-digit pincode');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(cleaned)) {
      return PincodeResult.failure('Pincode must contain only digits');
    }

    // ── Try primary API first ────────────────────────────────────────────
    try {
      final uri      = Uri.parse('$_baseUrl/$cleaned');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List && decoded.isNotEmpty) {
          final block  = decoded[0] as Map<String, dynamic>;
          final status = block['Status']?.toString() ?? '';

          if (status == 'Success') {
            final rawOffices = block['PostOffice'] as List?;

            if (rawOffices != null && rawOffices.isNotEmpty) {
              final offices = rawOffices
                  .map((o) => PostOffice.fromJson(o as Map<String, dynamic>))
                  .toList();
              final primary = offices.first;

              return PincodeResult.success(
                area:       primary.name,
                city:       primary.district,
                state:      primary.state,
                country:    primary.country,
                pincode:    cleaned,
                allOffices: offices,
              );
            }
          }
        }
      }
    } catch (_) {
      // Primary API failed — fall through to geocoding fallback
    }

    // ── Fallback: geocoding ──────────────────────────────────────────────
    try {
      final locations = await locationFromAddress('$cleaned, India')
          .timeout(const Duration(seconds: 10));

      if (locations.isEmpty) {
        return PincodeResult.failure(
            'Could not find this pincode. Please check and try again.');
      }

      final placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      ).timeout(const Duration(seconds: 10));

      if (placemarks.isEmpty) {
        return PincodeResult.failure('Could not resolve pincode details.');
      }

      final p = placemarks.first;

      final area = [p.subLocality, p.locality]
          .where((s) => s != null && s!.isNotEmpty)
          .join(', ');

      return PincodeResult.success(
        area:       area.isNotEmpty ? area : (p.name ?? cleaned),
        city:       p.subAdministrativeArea ?? p.locality ?? '',
        state:      p.administrativeArea    ?? '',
        country:    p.country               ?? 'India',
        pincode:    cleaned,
        allOffices: [],
      );
    } catch (e) {
      return PincodeResult.failure(
          'Could not find pincode. Please check your internet and try again.');
    }
  }

  static Future<List<String>> getOfficeNames(String pincode) async {
    final result = await lookup(pincode);
    if (!result.isSuccess) return [];
    return result.allOffices.map((o) => o.name).toList();
  }
}