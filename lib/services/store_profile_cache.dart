import 'get_profile_service.dart';

class StoreProfileCache {
  static double minOrderValue = 0;
  static double deliveryFee = 0;
  static double deliveryOrderValue = 0;

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

      hasLoaded = true;
    } catch (_) {
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
    hasLoaded = false;
    _loadingFuture = null;
  }
}
