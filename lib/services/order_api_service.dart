import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/session_manager.dart';
import '../model/cart_model.dart';
import '../model/address_model.dart';
import 'api_config_service.dart';

class OrderApiService {
  static final String _baseUrl = ApiConfig.indexPhp;
  static const String _route   = 'groceries/home.addOrder';

  static Future<Map<String, dynamic>> placeOrder({
    required CartModel    cart,
    required AddressModel address,
    required String       paymentMethod,
    String                couponCode       = '',
    double                couponDiscount   = 0.0,
    String?               screenshotBase64,
    String                utrNumber        = '',
  }) async {
    final token = await SessionManager.getToken();
    final customerIdStr = await SessionManager.getCustomerId();
    final customerId    = int.tryParse(customerIdStr ?? '') ?? 0;

    if (kDebugMode) {
    }

    final cartProducts = cart.items.values.map((item) {
      final total = item.product.price * item.quantity;
      return {
        'product_id': int.tryParse(item.product.id) ?? item.product.id,
        'name':       item.product.name,
        'quantity':   item.quantity,
        'price':      item.product.price.toInt(),
        'total':      total.toInt(),
      };
    }).toList();

    final subtotal      = cart.totalPrice;
    final grandTotal    = subtotal - couponDiscount;
    final numberOfItems = cart.items.values.fold<int>(0, (s, i) => s + i.quantity);

    final invoiceInfo = {
      'SUBTotal':            subtotal.toInt(),
      'TotalBeforeRoundoff': grandTotal.toInt(),
      'NumberOfItems':       cart.items.length,
      'QuantityTotal':       numberOfItems,
      'TotalTax':            0,
      'RoundOffAmount':      0,
      'DiscountIncluded':    couponDiscount.toInt(),
      'GrandTotal':          grandTotal.toInt(),
      'InvoiceNumber':       '',
      'Coupon':              couponCode,
      'CouponAmount':        couponDiscount.toInt(),
    };

    final orderDetails = <String, dynamic>{
      'customerIdNumber': customerId,
      'CustomerName':     address.fullName,
      'Email':            '',
      'Mobile':           address.phone,
      'Payment_address_1': address.addressLine1,
      'Payment_address_2': address.addressLine2,
      'Payment_city':      address.city,
      'Payment_postcode':  address.pinCode,
      'Payment_country':   'India',
      'Payment_zone':      address.state,
      'PaymentThrough': paymentMethod,
      'CashAmount':     paymentMethod == 'COD' ? grandTotal.toInt() : 0,
      'UPIAmount':      paymentMethod == 'UPI' ? grandTotal.toInt() : 0,
      if (utrNumber.isNotEmpty) 'UTRNumber': utrNumber,
      if (screenshotBase64 != null && screenshotBase64.isNotEmpty)
        'PaymentScreenshot': screenshotBase64,
      'coupon':         couponCode,
      'CouponDiscount': couponDiscount.toInt(),
      'TotalReceivedAmount':     grandTotal.toInt(),
      'PendingAmount':           0,
      'ReturnableBalance':       0,
      'SaveReturnableAsAdvance': false,
      'DueAmountUsed':           false,
      'DueAmountValue':          0,
      'CreditPointsUsed':        0,
      'redeem_points_status':    false,
      'previousOrderId':      0,
      'activeQuoteId':        0,
      'previourseditorderid': 0,
      'SellerId':             0,
      'Note': '',
      'tracking': address.tracking ?? '',
      'CartProducts': cartProducts,
      'InvoiceInfo':  invoiceInfo,
      if (address.officeName != null) 'OfficeName': address.officeName,
    };

    final body     = {'orderDetails': orderDetails};
    final jsonBody = jsonEncode(body);

    if (kDebugMode) {
    }

    final uri = Uri.parse('$_baseUrl?route=$_route&token=${token ?? ''}');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body:    jsonBody,
      ).timeout(const Duration(seconds: 30));

      final rawBody = response.body.trim();

      if (kDebugMode) {
      }

      if (response.statusCode == 200) {
        if (!rawBody.startsWith('{') && !rawBody.startsWith('[')) {
          return {
            'status':  'error',
            'message': 'Server returned invalid response: $rawBody',
          };
        }
        try {
          return jsonDecode(rawBody) as Map<String, dynamic>;
        } on FormatException catch (e) {
          return {'status': 'error', 'message': 'Failed to parse server response.'};
        }
      } else {
        return {
          'status':  'error',
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on http.ClientException catch (e) {
      return {'status': 'error', 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'status': 'error', 'message': 'Unexpected error: $e'};
    }
  }
}