import 'dart:convert';
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

  static const String _baseUrl = 'https://api.postalpincode.in/pincode';
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

    // ── Call API ─────────────────────────────────────────────────────────
    try {
      final uri      = Uri.parse('$_baseUrl/$cleaned');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        return PincodeResult.failure(
            'Server error (${response.statusCode}). Please try again.');
      }

      final decoded = jsonDecode(response.body);

      // API returns a List with one element
      if (decoded is! List || decoded.isEmpty) {
        return PincodeResult.failure('Unexpected response from server');
      }

      final block  = decoded[0] as Map<String, dynamic>;
      final status = block['Status']?.toString() ?? '';

      if (status != 'Success') {
        // API returns "Error" status for invalid pincodes
        return PincodeResult.failure('Invalid pincode. No results found.');
      }

      final rawOffices = block['PostOffice'] as List?;
      if (rawOffices == null || rawOffices.isEmpty) {
        return PincodeResult.failure('No post offices found for this pincode');
      }

      // Parse all offices
      final offices = rawOffices
          .map((o) => PostOffice.fromJson(o as Map<String, dynamic>))
          .toList();

      // Use the first office as the primary result
      final primary = offices.first;

      return PincodeResult.success(
        area:       primary.name,
        city:       primary.district,
        state:      primary.state,
        country:    primary.country,
        pincode:    cleaned,
        allOffices: offices,
      );
    } on http.ClientException catch (e) {
      return PincodeResult.failure('Network error: ${e.message}');
    } catch (e) {
      return PincodeResult.failure('Something went wrong. Please try again.');
    }
  }

  static Future<List<String>> getOfficeNames(String pincode) async {
    final result = await lookup(pincode);
    if (!result.isSuccess) return [];
    return result.allOffices.map((o) => o.name).toList();
  }
}