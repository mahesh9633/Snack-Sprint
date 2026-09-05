// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
//
// import '../services/session_manager.dart';
// import '../model/cart_model.dart';
// import '../model/address_model.dart';
// import 'api_config_service.dart';
//
// class OrderApiService {
//   static final String _baseUrl = ApiConfig.indexPhp;
//   static const String _route   = 'groceries/home.addOrder';
//
//   static Future<Map<String, dynamic>> placeOrder({
//     required CartModel    cart,
//     required AddressModel address,
//     required String       paymentMethod,
//     String                couponCode       = '',
//     double                couponDiscount   = 0.0,
//     double                deliveryCharge   = 0.0,
//     String?               screenshotBase64,
//     String                utrNumber        = '',
//     double                walletAmountUsed = 0.0,
//   }) async {
//     final token = await SessionManager.getToken();
//     final customerIdStr = await SessionManager.getCustomerId();
//     final customerId    = int.tryParse(customerIdStr ?? '') ?? 0;
//
//     final cartProducts = cart.items.entries.map((entry) {
//       final cartKey = entry.key;
//       final item    = entry.value;
//
//       int baseProductId;
//       int pieceRowId;
//
//       if (cartKey.contains('_piece_')) {
//         final parts   = cartKey.split('_piece_');
//         baseProductId = int.tryParse(parts[0]) ?? 0;
//         pieceRowId    = int.tryParse(parts[1]) ?? 0;
//       } else {
//         baseProductId = int.tryParse(cartKey) ?? 0;
//         pieceRowId    = 0;
//       }
//
//       final matchedPiece = item.product.pieces.isNotEmpty
//           ? item.product.pieces.firstWhere(
//             (p) => p.rowId.toString() == pieceRowId.toString(),
//         orElse: () => item.product.pieces.first,
//       )
//           : null;
//
//       final minQty   = matchedPiece?.minQuantity ?? 0;
//       final isCombo  = item.product.isCombo;
//       final comboQty = minQty > 0 ? minQty * item.quantity : item.quantity;
//       final total    = item.product.price * item.quantity;
//
//       // Matches PHP: $order_data["products"][] read from CartProducts
//       return {
//         'product_id':        baseProductId,
//         'name':              item.product.name,
//         'quantity':          comboQty,
//         'price':             item.product.price.round(),
//         'total':             total.round(),
//         'is_combo':          isCombo ? 'Yes' : 'No',
//         'piece_id':          int.tryParse(matchedPiece?.pieceId ?? '') ?? pieceRowId,
//         'min_quantity':      minQty,
//         'selected_quantity': item.quantity,
//       };
//     }).toList();
//
//     final subtotal = cart.totalPrice;
//
//     // Grand total BEFORE wallet is applied (subtotal - coupon + delivery).
//     final grandTotal = subtotal - couponDiscount + deliveryCharge;
//
//     // Wallet can never cover more than the grand total, and can't go negative.
//     final walletApplied = walletAmountUsed <= 0
//         ? 0.0
//         : (walletAmountUsed > grandTotal ? grandTotal : walletAmountUsed);
//
//     // What the customer actually pays via COD/UPI after wallet is applied.
//     final payableAmount = grandTotal - walletApplied;
//
//     final numberOfItems = cart.items.values.fold<int>(0, (s, i) => s + i.quantity);
//
//     // Matches PHP: $invoiceInfo = $get($orderDetails, "InvoiceInfo", []);
//     final invoiceInfo = {
//       'SUBTotal':            subtotal.round(),
//       'TotalBeforeRoundoff': (subtotal - couponDiscount).round(),
//       'NumberOfItems':       cart.items.length,
//       'QuantityTotal':       numberOfItems,
//       'TotalTax':            0,
//       'RoundOffAmount':      0,
//       'DiscountIncluded':    couponDiscount.round(),
//       'InvoiceNumber':       '',
//       'Coupon':              couponCode,
//       'CouponAmount':        couponDiscount.round(),
//       // ── Wallet discount reflected in the invoice breakdown ─────────────
//       'WalletDiscount':      walletApplied.round(),
//     };
//
//     // Matches PHP: $orderDetails = $get($post, "orderDetails", []);
//     // Every key below is read by Home.php addorder() using the exact same name.
//     final orderDetails = <String, dynamic>{
//       'customerIdNumber':  customerId,
//       'CustomerName':      address.fullName,
//       'Email':             '',
//       'Mobile':            address.phone,
//
//       // ── Address fields — read as $payment_address_1, etc. in PHP ──────
//       'Payment_address_1': address.addressLine1,
//       'Payment_address_2': address.addressLine2,
//       'Payment_city':      address.city,
//       'Payment_postcode':  address.pinCode,
//       'Payment_country':   'India',
//       'Payment_zone':      address.state,
//
//       'PaymentThrough':    paymentMethod,
//       // ── Cash/UPI amount now reflects the amount payable AFTER wallet
//       // has been applied — not the full grand total ─────────────────────
//       'CashAmount':        paymentMethod == 'COD' ? payableAmount.round() : 0,
//       'UPIAmount':         paymentMethod == 'UPI' ? payableAmount.round() : 0,
//       'TakeawayAmount':    deliveryCharge.round(),
//
//       if (screenshotBase64 != null && screenshotBase64.isNotEmpty)
//         'UPIImage': screenshotBase64,
//
//       // ── Wallet — backend reads this exact key as "AdvanceUsed" to
// // determine how much to debit from the customer's wallet balance ──
//       'AdvanceUsed': walletApplied.round(),
//
//       'TotalReceivedAmount':     payableAmount.round(),
//       'PendingAmount':           0,
//       'ReturnableBalance':       0,
//       'SaveReturnableAsAdvance': false,
//       'DueAmountUsed':           false,
//       'DueAmountValue':          0,
//       'CreditPointsUsed':        0,
//       'redeem_points_status':    false,
//       'previousOrderId':         0,
//       'activeQuoteId':           0,
//       'previourseditorderid':    0,
//       'SellerId':                0,
//       'Note':                    '',
//
//       // ── Tracking (Google Maps URL) — read as $tracking in PHP ─────────
//       'tracking': address.tracking ?? '',
//
//       'CartProducts': cartProducts,
//       'InvoiceInfo':  invoiceInfo,
//     };
//
//     final body     = {'orderDetails': orderDetails};
//     final jsonBody = jsonEncode(body);
//
//     final uri = Uri.parse('$_baseUrl?route=$_route&token=${token ?? ''}');
//
//     if (kDebugMode) {
//       // TEMP: verify exactly what's being sent before it leaves the device
//       print('placeOrder → Payment_address_1: ${address.addressLine1}');
//       print('placeOrder → Payment_city: ${address.city}');
//       print('placeOrder → tracking: ${address.tracking}');
//       print('placeOrder → walletApplied: $walletApplied, payableAmount: $payableAmount');
//       print('placeOrder → full body: $jsonBody');
//     }
//
//     try {
//       final response = await http.post(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body:    jsonBody,
//       ).timeout(const Duration(seconds: 30));
//
//       final rawBody = response.body.trim();
//
//       if (kDebugMode) {
//
//       }
//
//       if (response.statusCode == 200) {
//         if (!rawBody.startsWith('{') && !rawBody.startsWith('[')) {
//           return {
//             'status':  'error',
//             'message': 'Server returned invalid response: $rawBody',
//           };
//         }
//         try {
//           return jsonDecode(rawBody) as Map<String, dynamic>;
//         } on FormatException catch (e) {
//           if (kDebugMode) print('placeOrder → JSON parse failed: $e');
//           return {'status': 'error', 'message': 'Failed to parse server response.'};
//         }
//       } else {
//         return {
//           'status':  'error',
//           'message': 'Server error: ${response.statusCode}',
//         };
//       }
//     } on http.ClientException catch (e) {
//       if (kDebugMode) print('placeOrder → ClientException: ${e.message}');
//       return {'status': 'error', 'message': 'Network error: ${e.message}'};
//     } catch (e) {
//       if (kDebugMode) print('placeOrder → Unexpected error: $e');
//       return {'status': 'error', 'message': 'Unexpected error: $e'};
//     }
//   }
// }

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
    double                walletAmountUsed = 0.0,

    // ── Legacy UPI-proof fields — kept optional for backward compatibility
    // with any other caller still using the screenshot flow. Not used by
    // the new EasyUpiPaymentService flow.
    String?               screenshotBase64,
    String                utrNumber        = '',

    // ── New: UPI transaction fields from EasyUpiPaymentService ─────────
    // Populated only when paymentMethod is a UPI method and the payment
    // actually went through the easy_upi_payment plugin.
    String                transactionId    = '',
    String                transactionRefId = '',
    String                approvalRefNo    = '',
    String                responseCode     = '',
    double                paymentAmount    = 0.0,
  }) async {
    final token = await SessionManager.getToken();
    final customerIdStr = await SessionManager.getCustomerId();
    final customerId    = int.tryParse(customerIdStr ?? '') ?? 0;

    final cartProducts = cart.items.entries.map((entry) {
      final cartKey = entry.key;
      final item    = entry.value;

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
          ? item.product.pieces.firstWhere(
            (p) => p.rowId.toString() == pieceRowId.toString(),
        orElse: () => item.product.pieces.first,
      )
          : null;

      final minQty   = matchedPiece?.minQuantity ?? 0;
      final isCombo  = item.product.isCombo;
      final comboQty = minQty > 0 ? minQty * item.quantity : item.quantity;
      final total    = item.product.price * item.quantity;

      // Matches PHP: $order_data["products"][] read from CartProducts
      return {
        'product_id':        baseProductId,
        'name':              item.product.name,
        'quantity':          comboQty,
        'price':             item.product.price.round(),
        'total':             total.round(),
        'is_combo':          isCombo ? 'Yes' : 'No',
        'piece_id':          int.tryParse(matchedPiece?.pieceId ?? '') ?? pieceRowId,
        'min_quantity':      minQty,
        'selected_quantity': item.quantity,
      };
    }).toList();

    final subtotal = cart.totalPrice;

    // Grand total BEFORE wallet is applied (subtotal - coupon + delivery).
    final grandTotal = subtotal - couponDiscount + deliveryCharge;

    // Wallet can never cover more than the grand total, and can't go negative.
    final walletApplied = walletAmountUsed <= 0
        ? 0.0
        : (walletAmountUsed > grandTotal ? grandTotal : walletAmountUsed);

    // What the customer actually pays via COD/UPI after wallet is applied.
    final payableAmount = grandTotal - walletApplied;

    final numberOfItems = cart.items.values.fold<int>(0, (s, i) => s + i.quantity);

    final isUpi = paymentMethod.toUpperCase().contains('UPI');

    // Matches PHP: $invoiceInfo = $get($orderDetails, "InvoiceInfo", []);
    final invoiceInfo = {
      'SUBTotal':            subtotal.round(),
      'TotalBeforeRoundoff': (subtotal - couponDiscount).round(),
      'NumberOfItems':       cart.items.length,
      'QuantityTotal':       numberOfItems,
      'TotalTax':            0,
      'RoundOffAmount':      0,
      'DiscountIncluded':    couponDiscount.round(),
      'InvoiceNumber':       '',
      'Coupon':              couponCode,
      'CouponAmount':        couponDiscount.round(),
      // ── Wallet discount reflected in the invoice breakdown ─────────────
      'WalletDiscount':      walletApplied.round(),
    };

    // Matches PHP: $orderDetails = $get($post, "orderDetails", []);
    // Every key below is read by Home.php addorder() using the exact same name.
    final orderDetails = <String, dynamic>{
      'customerIdNumber':  customerId,
      'CustomerName':      address.fullName,
      'Email':             '',
      'Mobile':            address.phone,

      // ── Address fields — read as $payment_address_1, etc. in PHP ──────
      'Payment_address_1': address.addressLine1,
      'Payment_address_2': address.addressLine2,
      'Payment_city':      address.city,
      'Payment_postcode':  address.pinCode,
      'Payment_country':   'India',
      'Payment_zone':      address.state,

      'PaymentThrough':    paymentMethod,
      // ── Cash/UPI amount now reflects the amount payable AFTER wallet
      // has been applied — not the full grand total ─────────────────────
      'CashAmount':        paymentMethod == 'COD' ? payableAmount.round() : 0,
      'UPIAmount':         isUpi ? payableAmount.round() : 0,
      'TakeawayAmount':    deliveryCharge.round(),

      if (screenshotBase64 != null && screenshotBase64.isNotEmpty)
        'UPIImage': screenshotBase64,

      // ── UPI transaction proof from EasyUpiPaymentService — read by
      // PHP addorder() into $transaction_id / $transaction_ref_id /
      // $approval_ref_no / $upi_response_code and saved on order_invoice.
      if (transactionId.isNotEmpty)    'TransactionId':    transactionId,
      if (transactionRefId.isNotEmpty) 'TransactionRefId': transactionRefId,
      if (approvalRefNo.isNotEmpty)    'ApprovalRefNo':    approvalRefNo,
      if (responseCode.isNotEmpty)     'UPIResponseCode':  responseCode,
      if (paymentAmount > 0)           'UPIPaymentAmount': paymentAmount.round(),

      if (utrNumber.isNotEmpty) 'UTRNumber': utrNumber,

      // ── Wallet — backend reads this exact key as "AdvanceUsed" to
      // determine how much to debit from the customer's wallet balance ──
      'AdvanceUsed': walletApplied.round(),

      'TotalReceivedAmount':     payableAmount.round(),
      'PendingAmount':           0,
      'ReturnableBalance':       0,
      'SaveReturnableAsAdvance': false,
      'DueAmountUsed':           false,
      'DueAmountValue':          0,
      'CreditPointsUsed':        0,
      'redeem_points_status':    false,
      'previousOrderId':         0,
      'activeQuoteId':           0,
      'previourseditorderid':    0,
      'SellerId':                0,
      'Note':                    '',

      // ── Tracking (Google Maps URL) — read as $tracking in PHP ─────────
      'tracking': address.tracking ?? '',

      'CartProducts': cartProducts,
      'InvoiceInfo':  invoiceInfo,
    };

    final body     = {'orderDetails': orderDetails};
    final jsonBody = jsonEncode(body);

    final uri = Uri.parse('$_baseUrl?route=$_route&token=${token ?? ''}');

    if (kDebugMode) {
      // TEMP: verify exactly what's being sent before it leaves the device
      print('placeOrder → Payment_address_1: ${address.addressLine1}');
      print('placeOrder → Payment_city: ${address.city}');
      print('placeOrder → tracking: ${address.tracking}');
      print('placeOrder → walletApplied: $walletApplied, payableAmount: $payableAmount');
      if (isUpi) {
        print('placeOrder → transactionId: $transactionId, responseCode: $responseCode, '
            'approvalRefNo: $approvalRefNo, paymentAmount: $paymentAmount');
      }
      print('placeOrder → full body: $jsonBody');
    }

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body:    jsonBody,
      ).timeout(const Duration(seconds: 30));

      final rawBody = response.body.trim();

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
          if (kDebugMode) print('placeOrder → JSON parse failed: $e');
          return {'status': 'error', 'message': 'Failed to parse server response.'};
        }
      } else {
        return {
          'status':  'error',
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) print('placeOrder → ClientException: ${e.message}');
      return {'status': 'error', 'message': 'Network error: ${e.message}'};
    } catch (e) {
      if (kDebugMode) print('placeOrder → Unexpected error: $e');
      return {'status': 'error', 'message': 'Unexpected error: $e'};
    }
  }
}