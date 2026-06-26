import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class UpiQrResult {
  final bool   success;
  final String error;
  final String qrImageUrl;
  final String upiUrl;
  final String vpa;
  final String name;
  final double amount;

  UpiQrResult({
    required this.success,
    this.error      = '',
    this.qrImageUrl = '',
    this.upiUrl     = '',
    this.vpa        = '',
    this.name       = '',
    this.amount     = 0,
  });
}
class UpiQrService {
  static Future<UpiQrResult> generateQr({
    required String token,
    required double amount,
  }) async {
    try {
      print('Token passed into generateQr: "$token"');

      final uri = Uri.parse(
        ApiConfig.route('groceries/home.generateUpiQr', token: token),
      );

      print('Final UPI QR request URL: $uri');
      print('Amount sent in body: ${amount.toStringAsFixed(0)}');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount.toStringAsFixed(0),
        },
      );
      print('UPI QR raw response [${response.statusCode}]: ${response.body}');
      final data = jsonDecode(response.body);

      if (data['status']?.toString().toLowerCase() == 'success') {
        return UpiQrResult(
          success:    true,
          qrImageUrl: data['qr_image']?.toString() ?? '',
          upiUrl:     data['upi_url']?.toString()   ?? '',
          vpa:        data['vpa']?.toString()       ?? '',
          name:       data['name']?.toString()      ?? '',
          amount:     double.tryParse(data['amount']?.toString() ?? '') ?? amount,
        );
      } else {
        return UpiQrResult(
          success: false,
          error:   data['message']?.toString() ?? 'Could not generate QR code',
        );
      }
    } catch (e) {
      return UpiQrResult(success: false, error: 'Network error: $e');
    }
  }
}