import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config_service.dart';

class OrderDetailService {

  static final String _baseUrl = ApiConfig.indexPhp;

  static Future<OrderDetailResult> getOrderById({
    required String token,
    required String orderId,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl'
            '?route=groceries/categories.getOrdersbyId'
            '&token=$token'
            '&order_id=$orderId',
      );

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);

        if (json['status'] == 'success') {
          final data = json['data'] as Map<String, dynamic>;
          return OrderDetailResult.success(
            orderInfo:  _parseOrderInfo(data['order_info']),
            products:   _parseProducts(data['products']),
            invoice:    _parseInvoice(data['invoice']),
            taxDetails: _parseTaxDetails(data['tax_details']),
            history:    _parseHistory(data['history']),
          );
        } else {
          return OrderDetailResult.error(
              json['message']?.toString() ?? 'Unknown error from server');
        }
      } else {
        return OrderDetailResult.error(
            'Server returned status ${response.statusCode}');
      }
    } on Exception catch (e) {
      return OrderDetailResult.error('Network error: $e');
    }
  }

  // ── Private parsers ──────────────────────────────────────────────────────────

  static OrderInfo _parseOrderInfo(dynamic raw) {
    final m = (raw as Map?)?.cast<String, dynamic>() ?? {};

    String paymentMethodName = 'N/A';
    try {
      final pmRaw = m['payment_method']?.toString() ?? '';
      if (pmRaw.isNotEmpty) {
        final pm = jsonDecode(pmRaw);
        paymentMethodName = pm['name']?.toString() ?? 'N/A';
      }
    } catch (_) {}

    return OrderInfo(
      orderId:           m['order_id']?.toString()        ?? '',
      invoiceNo:         m['invoice_no']?.toString()       ?? '',
      invoicePrefix:     m['invoice_prefix']?.toString()   ?? '',
      firstName:         m['firstname']?.toString()        ?? '',
      lastName:          m['lastname']?.toString()         ?? '',
      email:             m['email']?.toString()            ?? '',
      telephone:         m['telephone']?.toString()        ?? '',
      total:             _toDouble(m['total']),
      orderStatus:       m['order_status']?.toString()     ?? '',
      orderStatusId:     m['order_status_id']?.toString()  ?? '',
      currencyCode:      m['currency_code']?.toString()    ?? 'INR',
      dateAdded:         m['date_added']?.toString()       ?? '',
      dateModified:      m['date_modified']?.toString()    ?? '',
      paymentMethodName: paymentMethodName,
      shippingMethod:    m['shipping_method']?.toString()  ?? '',
      comment:           m['comment']?.toString()          ?? '',
    );
  }

  static List<OrderProduct> _parseProducts(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return OrderProduct(
        orderProductId: m['order_product_id']?.toString() ?? '',
        productId:      m['product_id']?.toString()       ?? '',
        name:           m['name']?.toString()             ?? '',
        model:          m['model']?.toString()            ?? '',
        quantity:       int.tryParse(m['quantity'].toString()) ?? 1,
        price:          _toDouble(m['price']),
        total:          _toDouble(m['total']),
        gst:            m['gst']?.toString()              ?? '0',
        tax:            _toDouble(m['tax']),
      );
    }).toList();
  }

  static OrderInvoice? _parseInvoice(dynamic raw) {
    if (raw == null) return null;
    final m = (raw as Map).cast<String, dynamic>();
    return OrderInvoice(
      id:               m['id']?.toString()               ?? '',
      cashAmount:       _toDouble(m['cash_amount']),
      upiAmount:        _toDouble(m['upi_amount']),
      upiRef:           m['upi_ref']?.toString()          ?? '',
      coupon:           m['coupon']?.toString()            ?? '',
      creditPoints:     _toDouble(m['credit_points']),
      discount:         _toDouble(m['discount']),
      subTotal:         _toDouble(m['sub_total']),
      totalTax:         _toDouble(m['total_tax']),
      roundoffAmount:   _toDouble(m['roundoff_amount']),
      amountThrough:    m['amount_through']?.toString()   ?? '',
      pendingAmount:    _toDouble(m['pending_amount']),
      totalReceived:    _toDouble(m['total_received']),
      numberOfItems:    int.tryParse(m['number_of_items'].toString()) ?? 0,
      dateAdded:        m['date_added']?.toString()       ?? '',
    );
  }

  static List<TaxDetail> _parseTaxDetails(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return TaxDetail(
        id:    m['id']?.toString()   ?? '',
        name:  m['name']?.toString() ?? '',
        value: _toDouble(m['value']),
      );
    }).toList();
  }

  static List<OrderHistory> _parseHistory(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return OrderHistory(
        orderHistoryId: m['order_history_id']?.toString() ?? '',
        orderStatusId:  m['order_status_id']?.toString()  ?? '',
        statusName:     m['status_name']?.toString()      ?? '',
        comment:        m['comment']?.toString()          ?? '',
        dateAdded:      m['date_added']?.toString()       ?? '',
        notify:         m['notify']?.toString()           ?? '0',
      );
    }).toList();
  }

  static double _toDouble(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
}

// ── Result wrapper ─────────────────────────────────────────────────────────────

class OrderDetailResult {
  final bool         isSuccess;
  final String?      errorMessage;
  final OrderInfo?   orderInfo;
  final List<OrderProduct>  products;
  final OrderInvoice?       invoice;
  final List<TaxDetail>     taxDetails;
  final List<OrderHistory>  history;

  const OrderDetailResult._({
    required this.isSuccess,
    this.errorMessage,
    this.orderInfo,
    this.products   = const [],
    this.invoice,
    this.taxDetails = const [],
    this.history    = const [],
  });

  factory OrderDetailResult.success({
    required OrderInfo         orderInfo,
    required List<OrderProduct>  products,
    required OrderInvoice?       invoice,
    required List<TaxDetail>     taxDetails,
    required List<OrderHistory>  history,
  }) =>
      OrderDetailResult._(
        isSuccess:  true,
        orderInfo:  orderInfo,
        products:   products,
        invoice:    invoice,
        taxDetails: taxDetails,
        history:    history,
      );

  factory OrderDetailResult.error(String message) =>
      OrderDetailResult._(isSuccess: false, errorMessage: message);
}

// ── Data models ────────────────────────────────────────────────────────────────

class OrderInfo {
  final String orderId;
  final String invoiceNo;
  final String invoicePrefix;
  final String firstName;
  final String lastName;
  final String email;
  final String telephone;
  final double total;
  final String orderStatus;
  final String orderStatusId;
  final String currencyCode;
  final String dateAdded;
  final String dateModified;
  final String paymentMethodName;
  final String shippingMethod;
  final String comment;

  String get fullName => '$firstName $lastName'.trim();
  String get fullInvoice => '$invoicePrefix$invoiceNo';

  const OrderInfo({
    required this.orderId,
    required this.invoiceNo,
    required this.invoicePrefix,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.telephone,
    required this.total,
    required this.orderStatus,
    required this.orderStatusId,
    required this.currencyCode,
    required this.dateAdded,
    required this.dateModified,
    required this.paymentMethodName,
    required this.shippingMethod,
    required this.comment,
  });
}

class OrderProduct {
  final String orderProductId;
  final String productId;
  final String name;
  final String model;
  final int    quantity;
  final double price;
  final double total;
  final String gst;
  final double tax;

  const OrderProduct({
    required this.orderProductId,
    required this.productId,
    required this.name,
    required this.model,
    required this.quantity,
    required this.price,
    required this.total,
    required this.gst,
    required this.tax,
  });
}

class OrderInvoice {
  final String id;
  final double cashAmount;
  final double upiAmount;
  final String upiRef;
  final String coupon;
  final double creditPoints;
  final double discount;
  final double subTotal;
  final double totalTax;
  final double roundoffAmount;
  final String amountThrough;
  final double pendingAmount;
  final double totalReceived;
  final int    numberOfItems;
  final String dateAdded;

  const OrderInvoice({
    required this.id,
    required this.cashAmount,
    required this.upiAmount,
    required this.upiRef,
    required this.coupon,
    required this.creditPoints,
    required this.discount,
    required this.subTotal,
    required this.totalTax,
    required this.roundoffAmount,
    required this.amountThrough,
    required this.pendingAmount,
    required this.totalReceived,
    required this.numberOfItems,
    required this.dateAdded,
  });
}

class TaxDetail {
  final String id;
  final String name;
  final double value;

  const TaxDetail({
    required this.id,
    required this.name,
    required this.value,
  });
}

class OrderHistory {
  final String orderHistoryId;
  final String orderStatusId;
  final String statusName;
  final String comment;
  final String dateAdded;
  final String notify;

  const OrderHistory({
    required this.orderHistoryId,
    required this.orderStatusId,
    required this.statusName,
    required this.comment,
    required this.dateAdded,
    required this.notify,
  });
}