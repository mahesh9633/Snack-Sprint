import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _keyIsLoggedIn  = 'is_logged_in';
  static const _keyTelephone   = 'telephone';
  static const _keyCustomerId  = 'customer_id';
  static const _keyToken       = 'token';

  // ── Save ──────────────────────────────────────────────────────────────────
  static Future<void> saveSession({
    required String telephone,
    required String? customerId,
    required String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyTelephone, telephone);
    await prefs.setString(_keyCustomerId, customerId ?? '');
    await prefs.setString(_keyToken, token ?? '');

  }

  // ── Read ──────────────────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getTelephone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTelephone);
  }

  static Future<String?> getCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomerId);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // ── Generic key-value (used for profile name, email, etc.) ────────────────
  static Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<void> printSession() async {
    final prefs = await SharedPreferences.getInstance();
  }

  // ── Per-user address key ──────────────────────────────────────────────────
  static Future<String> addressKey() async {
    final prefs = await SharedPreferences.getInstance();
    final id    = prefs.getString(_keyCustomerId) ?? 'guest';
    return 'saved_addresses_$id';
  }

  // static Future<void> clearSession() async {
  //   final prefs   = await SharedPreferences.getInstance();
  //   final addrKey = await addressKey();
  //
  //   await prefs.remove(_keyIsLoggedIn);
  //   await prefs.remove(_keyTelephone);
  //   await prefs.remove(_keyCustomerId);
  //   await prefs.remove(_keyToken);
  //   await prefs.remove(addrKey);
  // }
  static Future<void> clearSession() async {
    final prefs   = await SharedPreferences.getInstance();
    final addrKey = await addressKey();

    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyTelephone);
    await prefs.remove(_keyCustomerId);
    await prefs.remove(_keyToken);
    await prefs.remove(addrKey);

    // Clear saved delivery location so next login always asks for location
    await prefs.remove('saved_address_label');
    await prefs.remove('saved_address_subtitle');
    await prefs.remove('saved_address_pincode');
    await prefs.remove('saved_address_lat');
    await prefs.remove('saved_address_lng');
    await prefs.setBool('address_confirmed', false);


    // Clear recent addresses (both storage formats used across the app)
    await prefs.remove('recent_addresses_v2');

    // Clear all token-based recent address keys
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('recent_addresses_')) {
        await prefs.remove(key);
      }
    }
  }
}