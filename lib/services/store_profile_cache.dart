import 'get_profile_service.dart';

/// In-memory cache of store-level profile settings (min order value,
/// delivery fee, free-delivery threshold).
///
/// WHY THIS EXISTS: CartScreen previously fetched this data in its own
/// initState(), which meant every time a customer opened the cart, they
/// briefly saw stale/zeroed values (₹0 delivery fee, no min-order banner)
/// until the network call finished — a visible flash + delay.
///
/// Fix: preload() is called ONCE, early (e.g. when Home loads, right
/// after login) — by the time the customer has browsed products and
/// taps into the cart, this cache is already populated. CartScreen then
/// reads these values SYNCHRONOUSLY at initState(), so it opens with the
/// correct numbers immediately, with no flash of 0. CartScreen still
/// calls ProfileGetApiService.getProfile() itself afterward (via
/// pull-to-refresh) to stay current — this cache is only about avoiding
/// the initial-load flash, not replacing that refresh entirely.
class StoreProfileCache {
  static double minOrderValue = 0;
  static double deliveryFee = 0;
  static double deliveryOrderValue = 0;

  /// True once preload() (or CartScreen's own fetch) has successfully
  /// populated real values at least once this app session.
  static bool hasLoaded = false;

  /// Fetches and caches store profile settings. Safe to call multiple
  /// times (e.g. once at Home load, and again whenever you want fresher
  /// data) — always overwrites with the latest successful response.
  static Future<void> preload() async {
    try {
      final result = await ProfileGetApiService.getProfile();
      if (result['success'] != true) return;

      // The store profile API can return `data` as either a single Map
      // or a List (as in getStores()) — handle both.
      final rawData = result['data'];
      Map<String, dynamic>? data;
      if (rawData is List && rawData.isNotEmpty) {
        data = Map<String, dynamic>.from(rawData.first as Map);
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      }
      if (data == null) return;

      minOrderValue = double.tryParse(
          data['min_order_value']?.toString() ?? '0') ??
          0;
      deliveryFee = double.tryParse(
          data['delivery_fee']?.toString() ?? '0') ??
          0;
      deliveryOrderValue = double.tryParse(
          data['delivery_order_value']?.toString() ?? '0') ??
          0;
      hasLoaded = true;
    } catch (_) {
      // Silently keep whatever was cached before (or the zero defaults
      // on very first launch, if this is the very first network call
      // the app has ever made and it happened to fail).
    }
  }
}