import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/session_manager.dart';

import 'api_config_service.dart';
final String kImgBase = ApiConfig.imageBase;

String buildImageUrl(String? raw) {
  if (raw == null) return '';
  final clean = raw.trim();
  if (clean.isEmpty) return '';

  // ── Known placeholders → treat as no image ──────────────────────────────
  const placeholders = {
    'no_image.png',
    'catalog/s-l400.jpg',
    'no_image',
  };
  if (placeholders.contains(clean)) return '';

  // ── Already a full URL ───────────────────────────────────────────────────
  if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;

  if (!clean.contains('/')) return '';

  // ── Relative path → prepend base ─────────────────────────────────────────
  return '$kImgBase$clean';
}

// ─── Model ────────────────────────────────────────────────────────────────────

class SimilarProduct {
  final String productId;
  final String name;
  final String price;
  final String rawImage;
  final String posQuantity;
  final String posStatus;

  const SimilarProduct({
    required this.productId,
    required this.name,
    required this.price,
    required this.rawImage,
    required this.posQuantity,
    required this.posStatus,
  });

  bool get isInStock =>
      posStatus == '1' &&
          int.tryParse(posQuantity) != null &&
          int.parse(posQuantity) > 0;

  /// Always safe to pass to Image.network() — returns '' if no valid image.
  String get fullImageUrl => buildImageUrl(rawImage);

  double get priceDouble => double.tryParse(price) ?? 0.0;

  factory SimilarProduct.fromJson(Map<String, dynamic> json) => SimilarProduct(
    productId:   json['product_id']?.toString() ?? '',
    name:        json['name']?.toString()        ?? '',
    price:       json['price']?.toString()       ?? '0.00',
    rawImage:    json['image']?.toString()       ?? '',
    posQuantity: json['pos_quentity']?.toString() ?? '0',
    posStatus:   json['pos_status']?.toString()  ?? '0',
  );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class SimilarProductsService {

  static final String _baseUrl = ApiConfig.indexPhp;

  static Future<List<SimilarProduct>> getSimilarProducts(
      String productId) async {
    final token = await SessionManager.getToken();

    final uri = Uri.parse(
      '$_baseUrl?route=groceries/categories.getProductDetails'
          '&token=$token&api_token=$token&product_id=$productId',
    );

    try {
      final response =
      await http.get(uri).timeout(const Duration(seconds: 15));


      if (response.statusCode != 200 || response.body.isEmpty) {
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['status']?.toString() != 'success') {
        return [];
      }

      final List<dynamic> related =
          data['related_products'] as List? ?? [];
      final results = related
          .map((p) => SimilarProduct.fromJson(p as Map<String, dynamic>))
          .toList();


      return results;
    } catch (e) {
      return [];
    }
  }
}