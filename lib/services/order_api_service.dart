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
    double                deliveryCharge   = 0.0,
    String?               screenshotBase64,
    String                utrNumber        = '',
  }) async {
    final token = await SessionManager.getToken();
    final customerIdStr = await SessionManager.getCustomerId();
    final customerId    = int.tryParse(customerIdStr ?? '') ?? 0;

    if (kDebugMode) {
    }

    final cartProducts = cart.items.entries.map((entry) {
      final cartKey = entry.key;   // e.g. "4952_piece_31" or plain "4952"
      final item    = entry.value;

      // Extract base product_id and piece row id from cart key
      int baseProductId;
      int pieceRowId;

      if (cartKey.contains('_piece_')) {
        final parts   = cartKey.split('_piece_');
        baseProductId = int.tryParse(parts[0]) ?? 0;
        pieceRowId    = int.tryParse(parts[1]) ?? 0;
      } else {
        baseProductId = int.tryParse(cartKey) ?? 0;
        pieceRowId    = 0;
      }

      final matchedPiece = item.product.pieces.isNotEmpty
          ? item.product.pieces.first
          : null;

      if (kDebugMode) {
        print('============== ORDER DEBUG ==============');
        print('Cart Key        : $cartKey');
        print('Product Name    : ${item.product.name}');
        print('Base Product ID : $baseProductId');
        print('Piece Row ID    : $pieceRowId');
        print('Cart Row ID : $pieceRowId');
        print('Piece ID    : ${matchedPiece?.pieceId}');
        print('Model Row ID: ${matchedPiece?.rowId}');

        if (matchedPiece != null) {
          print('Matched Piece   : $matchedPiece');
        }

        print('=========================================');
      }

      final minQty = matchedPiece?.minQuantity ?? 0;
      final isCombo     = item.product.isCombo;
      // quantity = min_quantity × user quantity (e.g. min=2, user=3 → quantity=6)
      final comboQty    = minQty > 0 ? minQty * item.quantity : item.quantity;
      final total       = item.product.price * item.quantity;

      return {
        'product_id':        baseProductId,
        'name':              item.product.name,
        'quantity':          comboQty,           // min_qty × user_qty
        'price':             item.product.price.round(),
        'total':             total.round(),
        'is_combo':          isCombo ? 'Yes' : 'No',
        'piece_id': int.tryParse(matchedPiece?.pieceId ?? '') ?? pieceRowId,
        'min_quantity':      minQty,             // e.g. 2 or 4
        'selected_quantity': item.quantity,      // user tapped qty e.g. 3
      };
    }).toList();

    final subtotal      = cart.totalPrice;
    final grandTotal = subtotal - couponDiscount + deliveryCharge;
    final numberOfItems = cart.items.values.fold<int>(0, (s, i) => s + i.quantity);

    final invoiceInfo = {
      'SUBTotal':            subtotal.round(),
      'TotalBeforeRoundoff': (subtotal - couponDiscount).round(),
      'NumberOfItems':       cart.items.length,
      'QuantityTotal':       numberOfItems,
      'TotalTax':            0,
      'RoundOffAmount':      0,
      'DiscountIncluded':    couponDiscount.round(),
      'GrandTotal':          grandTotal.round(),
      'InvoiceNumber':       '',
      'Coupon':              couponCode,
      'CouponAmount':        couponDiscount.round(),
      'TakeawayAmount':      deliveryCharge.round(),
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
      'CashAmount':          paymentMethod == 'COD' ? (subtotal - couponDiscount).round() : 0,
      'UPIAmount':           paymentMethod == 'UPI' ? (subtotal - couponDiscount).round() : 0,
      'TakeawayAmount':      deliveryCharge.round(),
      if (utrNumber.isNotEmpty) 'UTRNumber': utrNumber,
      if (screenshotBase64 != null && screenshotBase64.isNotEmpty)
        'PaymentScreenshot': screenshotBase64,
      'coupon':         couponCode,
      'CouponDiscount':      couponDiscount.round(),
      'TotalReceivedAmount': grandTotal.round(),
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
      print('=========== ORDER JSON ===========');
      print(jsonBody);
      print('=================================');
    }

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