// import 'get_profile_service.dart';
//
// class StoreProfileCache {
//   static double minOrderValue = 0;
//   static double deliveryFee = 0;
//   static double deliveryOrderValue = 0;
//
//   static bool hasLoaded = false;
//
//   static Future<void>? _loadingFuture;
//
//   static Future<void> preload({bool forceRefresh = false}) {
//     if (hasLoaded && !forceRefresh) {
//       return Future.value();
//     }
//
//     if (_loadingFuture != null) {
//       return _loadingFuture!;
//     }
//
//     _loadingFuture = _loadProfile();
//
//     return _loadingFuture!.whenComplete(() {
//       _loadingFuture = null;
//     });
//   }
//
//   static Future<void> _loadProfile() async {
//     try {
//       final result = await ProfileGetApiService.getProfile();
//
//       if (result['success'] != true) return;
//
//       final rawData = result['data'];
//       Map<String, dynamic>? data;
//
//       if (rawData is List && rawData.isNotEmpty) {
//         final first = rawData.first;
//         if (first is Map) {
//           data = Map<String, dynamic>.from(first);
//         }
//       } else if (rawData is Map) {
//         data = Map<String, dynamic>.from(rawData);
//       }
//
//       if (data == null) return;
//
//       minOrderValue =
//           double.tryParse(data['min_order_value']?.toString() ?? '0') ?? 0;
//
//       deliveryFee =
//           double.tryParse(data['delivery_fee']?.toString() ?? '0') ?? 0;
//
//       deliveryOrderValue =
//           double.tryParse(
//             data['delivery_order_value']?.toString() ?? '0',
//           ) ??
//               0;
//
//       hasLoaded = true;
//     } catch (_) {
//     }
//   }
//
//   static void update({
//     required double minOrderValueValue,
//     required double deliveryFeeValue,
//     required double deliveryOrderValueValue,
//   }) {
//     minOrderValue = minOrderValueValue;
//     deliveryFee = deliveryFeeValue;
//     deliveryOrderValue = deliveryOrderValueValue;
//     hasLoaded = true;
//   }
//
//   static void clear() {
//     minOrderValue = 0;
//     deliveryFee = 0;
//     deliveryOrderValue = 0;
//     hasLoaded = false;
//     _loadingFuture = null;
//   }
// }


import 'get_profile_service.dart';
import 'payment_methods_service.dart';

class StoreProfileCache {
  static double minOrderValue = 0;
  static double deliveryFee = 0;
  static double deliveryOrderValue = 0;

  // ── Enabled payment methods, cached at splash so the customer app's
  // Payment screen can show them instantly with no loading spinner ────────
  static List<Map<String, dynamic>> paymentMethods = [];

  static bool hasLoaded = false;

  static Future<void>? _loadingFuture;

  static Future<void> preload({bool forceRefresh = false}) {
    if (hasLoaded && !forceRefresh) {
      return Future.value();
    }

    if (_loadingFuture != null) {
      return _loadingFuture!;
    }

    _loadingFuture = _loadProfile();

    return _loadingFuture!.whenComplete(() {
      _loadingFuture = null;
    });
  }

  static Future<void> _loadProfile() async {
    try {
      // ── API call #1: getProfile (unchanged, separate API) ───────────────
      final result = await ProfileGetApiService.getProfile();

      if (result['success'] != true) return;

      final rawData = result['data'];
      Map<String, dynamic>? data;

      if (rawData is List && rawData.isNotEmpty) {
        final first = rawData.first;
        if (first is Map) {
          data = Map<String, dynamic>.from(first);
        }
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      }

      if (data == null) return;

      minOrderValue =
          double.tryParse(data['min_order_value']?.toString() ?? '0') ?? 0;

      deliveryFee =
          double.tryParse(data['delivery_fee']?.toString() ?? '0') ?? 0;

      deliveryOrderValue =
          double.tryParse(
            data['delivery_order_value']?.toString() ?? '0',
          ) ??
              0;

      // ── API call #2: getPaymentMethods (separate API, uses store_id
      // that just came back from getProfile above) ────────────────────────
      final storeId = data['store_id']?.toString() ?? '';
      if (storeId.isNotEmpty) {
        final pmResult = await PaymentMethodsApiService.getPaymentMethods(storeId);
        if (pmResult['success'] == true) {
          final rawMethods = pmResult['data'] as List<dynamic>? ?? [];
          paymentMethods = rawMethods
              .map((m) => Map<String, dynamic>.from(m as Map))
          // Only show methods the admin has enabled.
              .where((m) => m['status']?.toString() == '1')
              .toList();
        }
      }

      hasLoaded = true;
    } catch (_) {
      // Silent fail — screens fall back to cached/default values.
    }
  }

  static void update({
    required double minOrderValueValue,
    required double deliveryFeeValue,
    required double deliveryOrderValueValue,
  }) {
    minOrderValue = minOrderValueValue;
    deliveryFee = deliveryFeeValue;
    deliveryOrderValue = deliveryOrderValueValue;
    hasLoaded = true;
  }

  static void clear() {
    minOrderValue = 0;
    deliveryFee = 0;
    deliveryOrderValue = 0;
    paymentMethods = [];
    hasLoaded = false;
    _loadingFuture = null;
  }
}
