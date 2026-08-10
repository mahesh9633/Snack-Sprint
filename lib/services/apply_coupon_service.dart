import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_server.dart';

class CouponModel {
  final String couponId;
  final String name;
  final String code;

  final String type;

  final double discount;
  final double total;
  final double minimumTotal;
  final String dateStart;
  final String dateEnd;
  final int    usesTotal;
  final int    usesCustomer;
  final bool   status;
  final double discountAmount; // NEW: authoritative amount from backend
  final double finalTotal;     // NEW: authoritative final total from backend

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
    this.discountAmount = 0,
    this.finalTotal = 0,
  });

  // ── Parse from API JSON ───────────────────────────────────────────────────
  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      couponId:     json['coupon_id']?.toString()            ?? '',
      name:         json['name']?.toString()                  ?? '',
      code:         json['code']?.toString()                  ?? '',
      type:         json['type']?.toString()                  ?? 'P',
      discount:     double.tryParse(json['discount']?.toString()      ?? '0') ?? 0,
      total:        double.tryParse(json['total']?.toString()         ?? '0') ?? 0,
      minimumTotal: double.tryParse(json['minimum_total']?.toString() ?? '0') ?? 0,
      dateStart:    json['date_start']?.toString()            ?? '',
      dateEnd:      json['date_end']?.toString()              ?? '',
      usesTotal:    int.tryParse(json['uses_total']?.toString()    ?? '0') ?? 0,
      usesCustomer: int.tryParse(json['uses_customer']?.toString() ?? '0') ?? 0,
      status:       json['status']?.toString() == '1',
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0,
      finalTotal:     double.tryParse(json['final_total']?.toString()     ?? '0') ?? 0,
    );
  }

  // ── Auto-generated title ──────────────────────────────────────────────────
  String get title {
    if (type == 'P') return '${discount.toStringAsFixed(0)}% Off';
    return '₹${discount.toStringAsFixed(0)} Off';
  }

  // ── Auto-generated description ────────────────────────────────────────────
  String get description {
    final base    = type == 'P'
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

  // ── Discount calculation (PREVIEW ONLY — used for the "Save ₹X" badge
  // in the coupon list; the actual applied amount always comes from the
  // backend's discount_amount, see _applySuccess in payment_method_screen) ──
  double computeDiscount(double cartTotal) {
    if (!isEligible(cartTotal)) return 0;
    double disc;
    if (type == 'P') {
      disc = cartTotal * discount / 100;
      // 'total' field = max discount cap for percentage coupons
      if (total > 0 && disc > total) disc = total;
    } else {
      disc = discount;
      // Flat discount cannot exceed cart total (matches backend)
      if (disc > cartTotal) disc = cartTotal;
    }
    return disc;
  }

  // ── Amount the user still needs to add to unlock ──────────────────────────
  double amountNeeded(double cartTotal) {
    if (cartTotal >= minimumTotal) return 0;
    return minimumTotal - cartTotal;
  }
}

class ApplyCouponResult {
  final bool        success;
  final String      error;
  final CouponModel? coupon; // null on failure

  const ApplyCouponResult._({
    required this.success,
    required this.error,
    this.coupon,
  });

  factory ApplyCouponResult.ok(CouponModel coupon) =>
      ApplyCouponResult._(success: true,  error: '',      coupon: coupon);

  factory ApplyCouponResult.fail(String error) =>
      ApplyCouponResult._(success: false, error: error,   coupon: null);
}

class CouponApiService {
  static Future<ApplyCouponResult> applyCoupon({
    required String token,
    required String couponCode,
    required double grandTotal,
  }) async {
    final uri = Uri.parse(
      '$kApiBase?route=groceries/categories.applycoupon'
          '&token=$token'
          '&api_token=$token',
    );

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'coupon':      couponCode,
          'grand_total': grandTotal.toStringAsFixed(2),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.body.isEmpty) {
        return ApplyCouponResult.fail('Server error ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return ApplyCouponResult.fail('Unexpected response format');
      }

      // Backend returns {"error": "..."} on failure
      if (decoded.containsKey('error')) {
        return ApplyCouponResult.fail(decoded['error'].toString());
      }

      // Backend returns {"success": "...", "coupon_info": {...}} on success
      final info = decoded['coupon_info'];
      if (info is! Map<String, dynamic>) {
        return ApplyCouponResult.fail('Invalid coupon data from server');
      }

      final coupon = CouponModel.fromJson(info);
      return ApplyCouponResult.ok(coupon);
    } catch (e) {
      return ApplyCouponResult.fail(e.toString());
    }
  }

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
          'Accept':        'application/json',
          'Authorization': 'Bearer $token',
          'X-Auth-Token':  token,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.body.isEmpty) {
        return CouponResult.error('Server error ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return CouponResult.error('Unexpected response format');
      }

      if (decoded['status']?.toString() != 'success') {
        return CouponResult.error(
          decoded['message']?.toString() ?? 'Failed to load coupons',
        );
      }

      final rawList = decoded['coupons'];
      if (rawList is! List) return CouponResult.success([]);

      final coupons = rawList
          .whereType<Map<String, dynamic>>()
          .map(CouponModel.fromJson)
          .where((c) => c.status)
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
      CouponResult._(success: false, coupons: [],      message: message);
}