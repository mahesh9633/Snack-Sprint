import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class OtpResult {
  final bool success;
  final String? otp;
  final String? otpRef;
  final String? message;

  OtpResult({required this.success, this.otp, this.otpRef, this.message});
}

class VerifyResult {
  final bool success;
  final String? customerId;
  final String? token;
  final String? otpRef;
  final String? message;

  VerifyResult({
    required this.success,
    this.customerId,
    this.token,
    this.otpRef,
    this.message,
  });
}

// ─── AuthService ──────────────────────────────────────────────────────────────

class AuthService {
  static final String _baseUrl = ApiConfig.indexPhp;

  // ── Send OTP ─────────────────────────────────────────────────────────────────
  static Future<OtpResult> sendOtp(String phone) async {
    final url = '$_baseUrl?route=groceries/categories.send_otp';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'telephone': phone},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.body.isEmpty) {
        return OtpResult(
            success: false,
            message: 'Server error (${response.statusCode})');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final bool isSuccess =
          data['success'] == 1 ||
              data['success'].toString() == '1' ||
              data['message']?.toString() == 'success_otp_resent'; // ← FIX

      if (isSuccess) {

        return OtpResult(
          success: true,
          otp: data['otp']?.toString(),
          otpRef: data['otp_ref']?.toString(),
          message: data['message']?.toString(),
        );
      } else {
        return OtpResult(
            success: false,
            message: data['message']?.toString() ?? 'OTP request failed');
      }
    } on FormatException catch (e) {

      return OtpResult(success: false, message: 'Invalid response from server');
    } catch (e) {
      return OtpResult(success: false, message: e.toString());
    } finally {

    }
  }

  // ── Verify OTP ───────────────────────────────────────────────────────────────
  static Future<VerifyResult> verifyOtp({
    required String telephone,
    required String otp,
    required String otpRef,
  }) async {
    final url = '$_baseUrl?route=groceries/categories.verify_otp';
    final body = {'telephone': telephone, 'otp': otp, 'otp_ref': otpRef};



    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 15));


      if (response.statusCode != 200 || response.body.isEmpty) {
        return VerifyResult(
            success: false,
            message: 'Server error (${response.statusCode})');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final bool isSuccess =
          data['success'] == 1 || data['success'].toString() == '1';

      if (isSuccess) {

        return VerifyResult(
          success: true,
          customerId: data['customer_id']?.toString(),
          token: data['token']?.toString(),
          otpRef: data['otp_ref']?.toString(),
          message: data['message']?.toString(),
        );
      } else {

        return VerifyResult(
            success: false,
            message:
            data['message']?.toString() ?? 'OTP verification failed');
      }
    } on FormatException catch (e) {

      return VerifyResult(
          success: false, message: 'Invalid response from server');

    } catch (e) {

      return VerifyResult(success: false, message: e.toString());
    } finally {

    }
  }

  // ── Send FCM Token ───────────────────────────────────────────────────────────
  static Future<void> sendFcmToken(String authToken) async {
    // final url = '$_baseUrl?route=groceries/categories.saveLoginToken';
    final url = '$_baseUrl?route=groceries/categories.saveLoginToken&token=$authToken';

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      debugPrint("FCM TOKEN = $fcmToken");

      if (fcmToken == null) {
        debugPrint("FCM token is null");
        return;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'login_token': fcmToken,
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("SAVE TOKEN STATUS = ${response.statusCode}");
      debugPrint("SAVE TOKEN RESPONSE = ${response.body}");
    } catch (e) {
      debugPrint("FCM token send failed: $e");
    }
  }
}