import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config_service.dart';

class StoreModel {
  final String storeId;
  final String name;
  final String contact;
  final String address;
  final String upiId;
  final String minOrderValue;

  const StoreModel({
    required this.storeId,
    required this.name,
    required this.contact,
    required this.address,
    required this.upiId,
    required this.minOrderValue,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
    storeId:       json['store_id']?.toString()       ?? '',
    name:          json['name']?.toString()            ?? '',
    contact:       json['contact']?.toString()         ?? '',
    address:       json['address']?.toString()         ?? '',
    upiId:         json['upi']?.toString()             ?? '',
    minOrderValue: json['min_order_value']?.toString() ?? '0',
  );
}

class StoreUpiResult {
  final bool        success;
  final StoreModel? store;
  final String      error;

  const StoreUpiResult({
    required this.success,
    this.store,
    this.error = '',
  });
}

class StoreUpiService {
  /// Fetches store/UPI info from the profile endpoint (already has UPI data).
  static Future<StoreUpiResult> getStoreUpi({required String token}) async {
    try {
      final url = Uri.parse(
        ApiConfig.route('groceries/categories.getProfile', token: token),
      );

      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return StoreUpiResult(
          success: false,
          error: 'Server error: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (json['status']?.toString().toLowerCase() != 'success') {
        return StoreUpiResult(
          success: false,
          error: json['message']?.toString() ?? 'Failed to load store info',
        );
      }

      // Profile response has store info nested in 'data'
      final data = json['data'] as Map<String, dynamic>? ?? {};

      final upiId = data['upi']?.toString() ?? '';
      if (upiId.isEmpty) {
        return const StoreUpiResult(
          success: false,
          error: 'No UPI ID configured for this store',
        );
      }

      return StoreUpiResult(
        success: true,
        store: StoreModel.fromJson(data),
      );
    } catch (e) {
      return StoreUpiResult(
        success: false,
        error: 'Network error: $e',
      );
    }
  }
}