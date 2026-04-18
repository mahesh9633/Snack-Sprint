import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_server.dart';

class CouponModel {
  final String couponId;
  final String name;
  final String code;

  final String type;

  final double discount;
  final double total;           // max discount cap (0 = no cap) — "total" field
  final double minimumTotal;    // minimum cart value required
  final String dateStart;
  final String dateEnd;
  final int    usesTotal;       // 0 = unlimited
  final int    usesCustomer;    // 0 = unlimited
  final bool   status;

  const CouponModel({
    required this.couponId,
    required this.name,
    required this.code,
    required this.type,
    required this.discount,
    required this.total,
    required this.minimumTotal,
    required this.dateStart,
    required this.dateEnd,
    required this.usesTotal,
    required this.usesCustomer,
    required this.status,
  });

  // ── Factory from API JSON ─────────────────────────────────────────────────
  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      couponId:     json['coupon_id']?.toString()    ?? '',
      name:         json['name']?.toString()          ?? '',
      code:         json['code']?.toString()          ?? '',
      type:         json['type']?.toString()          ?? 'P',
      discount:     double.tryParse(json['discount']?.toString()      ?? '0') ?? 0,
      total:        double.tryParse(json['total']?.toString()         ?? '0') ?? 0,
      minimumTotal: double.tryParse(json['minimum_total']?.toString() ?? '0') ?? 0,
      dateStart:    json['date_start']?.toString()    ?? '',
      dateEnd:      json['date_end']?.toString()      ?? '',
      usesTotal:    int.tryParse(json['uses_total']?.toString()    ?? '0') ?? 0,
      usesCustomer: int.tryParse(json['uses_customer']?.toString() ?? '0') ?? 0,
      status:       json['status']?.toString() == '1',
    );
  }

  // ── Human-readable title ──────────────────────────────────────────────────
  String get title {
    if (type == 'P') return '${discount.toStringAsFixed(0)}% Off';
    return '₹${discount.toStringAsFixed(0)} Off';
  }

  // ── Human-readable description ────────────────────────────────────────────
  String get description {
    final base = type == 'P'
        ? '${discount.toStringAsFixed(0)}% off'
        : '₹${discount.toStringAsFixed(0)} flat off';
    final minPart = minimumTotal > 0
        ? ' on orders above ₹${minimumTotal.toStringAsFixed(0)}'
        : '';
    final capPart = type == 'P' && total > 0
        ? ', max discount ₹${total.toStringAsFixed(0)}'
        : '';
    return '$base$minPart$capPart';
  }

  // ── Eligibility check ─────────────────────────────────────────────────────
  bool isEligible(double cartTotal) {
    if (!status) return false;
    if (cartTotal < minimumTotal) return false;
    return true;
  }

  // ── Discount computation ──────────────────────────────────────────────────
  double computeDiscount(double cartTotal) {
    if (!isEligible(cartTotal)) return 0;
    double disc;
    if (type == 'P') {
      disc = cartTotal * discount / 100;
      // cap: 'total' field acts as max-discount cap for percentage coupons
      if (total > 0 && disc > total) disc = total;
    } else {
      disc = discount;
    }
    return disc;
  }

  // ── Amount needed to unlock ───────────────────────────────────────────────
  double amountNeeded(double cartTotal) {
    if (cartTotal >= minimumTotal) return 0;
    return minimumTotal - cartTotal;
  }
}

class CouponApiService {
  static Future<CouponResult> getCoupons({required String token}) async {
    final uri = Uri.parse(
      '$kApiBase?route=groceries/categories.getCoupon'
          '&token=$token'
          '&api_token=$token',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Auth-Token': token,
        },
      ).timeout(const Duration(seconds: 15));


      if (response.statusCode != 200 || response.body.isEmpty) {
        return CouponResult.error('Server error ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return CouponResult.error('Unexpected response format');
      }

      final apiStatus = decoded['status']?.toString();
      if (apiStatus != 'success') {
        return CouponResult.error(
          decoded['message']?.toString() ?? 'Failed to load coupons',
        );
      }

      final rawList = decoded['coupons'];
      if (rawList is! List) {
        return CouponResult.success([]);
      }

      final coupons = rawList
          .whereType<Map<String, dynamic>>()
          .map(CouponModel.fromJson)
          .where((c) => c.status) // only active coupons
          .toList();

      return CouponResult.success(coupons);
    } catch (e, st) {
      return CouponResult.error(e.toString());
    }
  }
}

class CouponResult {
  final bool              success;
  final List<CouponModel> coupons;
  final String            message;

  const CouponResult._({
    required this.success,
    required this.coupons,
    required this.message,
  });

  factory CouponResult.success(List<CouponModel> coupons) =>
      CouponResult._(success: true,  coupons: coupons, message: '');

  factory CouponResult.error(String message) =>
      CouponResult._(success: false, coupons: [],     message: message);
}