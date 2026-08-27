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
          data['success'] == 1 ||
              data['success'] == 2 ||
              data['success'].toString() == '1' ||
              data['success'].toString() == '2';

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
  //
  // // ── Send Mail OTP ─────────────────────────────────────────────────────────────
  // static Future<OtpResult> sendMailOtp(String email) async {
  //   final url = '$_baseUrl?route=groceries/categories.send_mail_otp';
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  //       body: {'email': email},
  //     ).timeout(const Duration(seconds: 15));
  //
  //     if (response.statusCode != 200 || response.body.isEmpty) {
  //       return OtpResult(
  //           success: false,
  //           message: 'Server error (${response.statusCode})');
  //     }
  //
  //     final data = json.decode(response.body) as Map<String, dynamic>;
  //     final bool isSuccess =
  //         data['success'] == 1 ||
  //             data['success'] == 2 ||
  //             data['success'].toString() == '1' ||
  //             data['success'].toString() == '2';
  //
  //     if (isSuccess) {
  //       return OtpResult(
  //         success: true,
  //         otp: data['otp']?.toString(),
  //         otpRef: data['otp_ref']?.toString(),
  //         message: data['message']?.toString(),
  //       );
  //     } else {
  //       return OtpResult(
  //           success: false,
  //           message: data['message']?.toString() ?? 'OTP request failed');
  //     }
  //   } on FormatException catch (e) {
  //     return OtpResult(success: false, message: 'Invalid response from server');
  //   } catch (e) {
  //     return OtpResult(success: false, message: e.toString());
  //   }
  // }
  //
  // // ── Verify Mail OTP ──────────────────────────────────────────────────────────
  // static Future<VerifyResult> verifyMailOtp({
  //   required String email,
  //   required String otp,
  //   required String otpRef,
  // }) async {
  //   final url = '$_baseUrl?route=groceries/categories.verify_otp';
  //   final body = {'email': email, 'otp': otp, 'otp_ref': otpRef};
  //
  //   try {
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  //       body: body,
  //     ).timeout(const Duration(seconds: 15));
  //
  //     if (response.statusCode != 200 || response.body.isEmpty) {
  //       return VerifyResult(
  //           success: false,
  //           message: 'Server error (${response.statusCode})');
  //     }
  //
  //     final data = json.decode(response.body) as Map<String, dynamic>;
  //     final bool isSuccess =
  //         data['success'] == 1 ||
  //             data['success'] == 2 ||
  //             data['success'].toString() == '1' ||
  //             data['success'].toString() == '2';
  //
  //     if (isSuccess) {
  //       return VerifyResult(
  //         success: true,
  //         customerId: data['customer_id']?.toString(),
  //         token: data['token']?.toString(),
  //         otpRef: data['otp_ref']?.toString(),
  //         message: data['message']?.toString(),
  //       );
  //     } else {
  //       return VerifyResult(
  //           success: false,
  //           message: data['message']?.toString() ?? 'OTP verification failed');
  //     }
  //   } on FormatException catch (e) {
  //     return VerifyResult(
  //         success: false, message: 'Invalid response from server');
  //   } catch (e) {
  //     return VerifyResult(success: false, message: e.toString());
  //   }
  // }

  // ── Send FCM Token ───────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
// ADD THESE TWO METHODS TO YOUR EXISTING lib/services/auth_service.dart,
// inside the AuthService class (right after verifyOtp() works well).
//
// Reuses your existing OtpResult / VerifyResult classes as-is — no new
// models needed. Routes point at the ws/transactions/common controller
// shown in your PHP (send_mail_otp / verify_mail_otp).
// ─────────────────────────────────────────────────────────────────────────

// ── Send Mail OTP ────────────────────────────────────────────────────────
  static Future<OtpResult> sendMailOtp({
    required String email,
    required String telephone,
  }) async {
    final url = '$_baseUrl?route=groceries/categories.send_mail_otp';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'email': email, 'telephone': telephone},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 || response.body.isEmpty) {
        return OtpResult(
            success: false,
            message: 'Server error (${response.statusCode})');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final bool isSuccess =
          data['success'] == 1 ||
              data['success'] == 2 ||
              data['success'].toString() == '1' ||
              data['success'].toString() == '2';

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
    }
  }

// ── Verify Mail OTP ──────────────────────────────────────────────────────
  static Future<VerifyResult> verifyMailOtp({
    required String email,
    required String telephone,
    required String otp,
    required String otpRef,
  }) async {
    final url = '$_baseUrl?route=groceries/categories.verify_otp';
    final body = {
      'email': email,
      'telephone': telephone,
      'otp': otp,
      'otp_ref': otpRef,
    };

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
            message: data['message']?.toString() ?? 'OTP verification failed');
      }
    } on FormatException catch (e) {
      return VerifyResult(
          success: false, message: 'Invalid response from server');
    } catch (e) {
      return VerifyResult(success: false, message: e.toString());
    }
  }

// ─────────────────────────────────────────────────────────────────────────
// NOTE on routes: your backend controller method is literally named
// verify_mail_otp() and now requires BOTH email and telephone (see
// validate_verify_mail_otp). Earlier testing showed route=...verify_otp
// (the phone route) also accepting email/otp/otp_ref and returning the
// mail-otp response shape — that was BEFORE telephone became mandatory.
// Worth re-testing both route=groceries/categories.verify_otp and
// route=groceries/categories.verify_mail_otp in Postman with email +
// telephone + otp + otp_ref now, to confirm which one is actually correct
// post-update. Same goes for send_mail_otp, though that one's already
// confirmed working at its own dedicated route.
// ─────────────────────────────────────────────────────────────────────────
  static Future<void> sendFcmToken(String authToken) async {
    // final url = '$_baseUrl?route=groceries/categories.saveLoginToken';
    final url = '$_baseUrl?route=groceries/categories.saveLoginToken&token=$authToken';

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null) {
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

    } catch (e) {
    }
  }
}

//=====================================================================================
// import 'dart:convert';
//
// import 'package:firebase_app_check/firebase_app_check.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import 'api_config_service.dart';
//
// // ─── Models ───────────────────────────────────────────────────────────────────
//
// class OtpResult {
//   final bool success;
//   final String? otp;
//   final String? otpRef;
//   final String? message;
//
//   OtpResult({
//     required this.success,
//     this.otp,
//     this.otpRef,
//     this.message,
//   });
// }
//
// class VerifyResult {
//   final bool success;
//   final String? customerId;
//   final String? token;
//   final String? otpRef;
//   final String? message;
//
//   VerifyResult({
//     required this.success,
//     this.customerId,
//     this.token,
//     this.otpRef,
//     this.message,
//   });
// }
//
// // ─── AuthService ──────────────────────────────────────────────────────────────
//
// class AuthService {
//   static final String _baseUrl = ApiConfig.indexPhp;
//
//   // Key used to store the device ID locally.
//   static const String _deviceIdKey = 'snack_sprint_device_id';
//
//   // ────────────────────────────────────────────────────────────────────────────
//   // Get / create a persistent device ID
//   // ────────────────────────────────────────────────────────────────────────────
//   static Future<String> _getDeviceId() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//
//       // Check if we already have a device ID.
//       final existingId = prefs.getString(_deviceIdKey);
//
//       if (existingId != null && existingId.isNotEmpty) {
//         debugPrint('DEVICE ID: $existingId');
//         return existingId;
//       }
//
//       // Create a new persistent ID.
//       final deviceId =
//           'snack_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
//
//       await prefs.setString(_deviceIdKey, deviceId);
//
//       debugPrint('DEVICE ID CREATED: $deviceId');
//
//       return deviceId;
//     } catch (e) {
//       debugPrint('DEVICE ID ERROR: $e');
//
//       // Fallback so the request can still be sent.
//       final fallback =
//           'snack_fallback_${DateTime.now().millisecondsSinceEpoch}';
//
//       debugPrint('DEVICE ID FALLBACK: $fallback');
//
//       return fallback;
//     }
//   }
//
//   // ────────────────────────────────────────────────────────────────────────────
//   // Get Firebase App Check token
//   // ────────────────────────────────────────────────────────────────────────────
//   static Future<String?> _getAppCheckToken() async {
//     try {
//       final token = await FirebaseAppCheck.instance.getToken();
//
//       if (token == null || token.isEmpty) {
//         debugPrint('APP CHECK TOKEN: EMPTY');
//         return null;
//       }
//
//       debugPrint('APP CHECK TOKEN RECEIVED: YES');
//
//       return token;
//     } catch (e) {
//       debugPrint('APP CHECK TOKEN ERROR: $e');
//       return null;
//     }
//   }
//
//   // ────────────────────────────────────────────────────────────────────────────
//   // Send OTP
//   // ────────────────────────────────────────────────────────────────────────────
//   static Future<OtpResult> sendOtp(String phone) async {
//     final url = '$_baseUrl?route=groceries/categories.send_otp';
//
//     try {
//       // Get device ID required by PHP backend.
//       final deviceId = await _getDeviceId();
//
//       // Get Firebase App Check token required by PHP backend.
//       final appCheckToken = await _getAppCheckToken();
//
//       if (appCheckToken == null) {
//         return OtpResult(
//           success: false,
//           message: 'App verification failed. Please try again.',
//         );
//       }
//
//       debugPrint('SEND OTP DEVICE ID: $deviceId');
//
//       final response = await http
//           .post(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//
//           // PHP reads:
//           // $_SERVER['HTTP_X_FIREBASE_APPCHECK']
//           'X-Firebase-AppCheck': appCheckToken,
//         },
//         body: {
//           'telephone': phone,
//           'device_id': deviceId,
//         },
//       )
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint('SEND OTP STATUS: ${response.statusCode}');
//       debugPrint('SEND OTP RESPONSE: ${response.body}');
//
//       if (response.statusCode != 200 || response.body.isEmpty) {
//         return OtpResult(
//           success: false,
//           message: 'Server error (${response.statusCode})',
//         );
//       }
//
//       final data = json.decode(response.body) as Map<String, dynamic>;
//
//       final successValue = data['success']?.toString();
//
//       final bool isSuccess =
//           successValue == '1' || successValue == '2';
//
//       if (isSuccess) {
//         return OtpResult(
//           success: true,
//           otp: data['otp']?.toString(),
//           otpRef: data['otp_ref']?.toString(),
//           message: data['message']?.toString(),
//         );
//       }
//
//       return OtpResult(
//         success: false,
//         message: data['message']?.toString() ?? 'OTP request failed',
//       );
//     } on FormatException {
//       return OtpResult(
//         success: false,
//         message: 'Invalid response from server',
//       );
//     } catch (e) {
//       debugPrint('SEND OTP ERROR: $e');
//
//       return OtpResult(
//         success: false,
//         message: e.toString(),
//       );
//     }
//   }
//
//   // ────────────────────────────────────────────────────────────────────────────
//   // Verify OTP
//   // ────────────────────────────────────────────────────────────────────────────
//   static Future<VerifyResult> verifyOtp({
//     required String telephone,
//     required String otp,
//     required String otpRef,
//   }) async {
//     final url = '$_baseUrl?route=groceries/categories.verify_otp';
//
//     try {
//       // Same device ID used when OTP was requested.
//       final deviceId = await _getDeviceId();
//
//       // Get App Check token.
//       final appCheckToken = await _getAppCheckToken();
//
//       if (appCheckToken == null) {
//         return VerifyResult(
//           success: false,
//           message: 'App verification failed. Please try again.',
//         );
//       }
//
//       debugPrint('VERIFY OTP DEVICE ID: $deviceId');
//
//       final response = await http
//           .post(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//
//           // Send App Check here too.
//           'X-Firebase-AppCheck': appCheckToken,
//         },
//         body: {
//           'telephone': telephone,
//           'otp': otp,
//           'otp_ref': otpRef,
//           'device_id': deviceId,
//         },
//       )
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint('VERIFY OTP STATUS: ${response.statusCode}');
//       debugPrint('VERIFY OTP RESPONSE: ${response.body}');
//
//       if (response.statusCode != 200 || response.body.isEmpty) {
//         return VerifyResult(
//           success: false,
//           message: 'Server error (${response.statusCode})',
//         );
//       }
//
//       final data = json.decode(response.body) as Map<String, dynamic>;
//
//       final bool isSuccess =
//           data['success']?.toString() == '1';
//
//       if (isSuccess) {
//         return VerifyResult(
//           success: true,
//           customerId: data['customer_id']?.toString(),
//           token: data['token']?.toString(),
//           otpRef: data['otp_ref']?.toString(),
//           message: data['message']?.toString(),
//         );
//       }
//
//       return VerifyResult(
//         success: false,
//         message:
//         data['message']?.toString() ?? 'OTP verification failed',
//       );
//     } on FormatException {
//       return VerifyResult(
//         success: false,
//         message: 'Invalid response from server',
//       );
//     } catch (e) {
//       debugPrint('VERIFY OTP ERROR: $e');
//
//       return VerifyResult(
//         success: false,
//         message: e.toString(),
//       );
//     }
//   }
//
//   // ────────────────────────────────────────────────────────────────────────────
//   // Send FCM Token
//   // ────────────────────────────────────────────────────────────────────────────
//   static Future<void> sendFcmToken(String authToken) async {
//     final url =
//         '$_baseUrl?route=groceries/categories.saveLoginToken&token=$authToken';
//
//     try {
//       final fcmToken =
//       await FirebaseMessaging.instance.getToken();
//
//       if (fcmToken == null || fcmToken.isEmpty) {
//         debugPrint('FCM TOKEN: EMPTY');
//         return;
//       }
//
//       debugPrint('FCM TOKEN RECEIVED');
//
//       final response = await http
//           .post(
//         Uri.parse(url),
//         headers: {
//           'Content-Type': 'application/x-www-form-urlencoded',
//         },
//         body: {
//           'login_token': fcmToken,
//         },
//       )
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint(
//         'FCM TOKEN SAVE STATUS: ${response.statusCode}',
//       );
//       debugPrint(
//         'FCM TOKEN SAVE RESPONSE: ${response.body}',
//       );
//     } catch (e) {
//       debugPrint('FCM TOKEN ERROR: $e');
//     }
//   }
// }