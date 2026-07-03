import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/session_manager.dart';
import 'api_config_service.dart';

class OrderProduct {
  final String orderProductId;
  final String orderId;
  final String productId;
  final String name;
  final String model;
  final String quantity;
  final String price;
  final String total;
  final String gst;
  final String tax;
  final String image;
  final String comment;

  const OrderProduct({
    required this.orderProductId,
    required this.orderId,
    required this.productId,
    required this.name,
    required this.model,
    required this.quantity,
    required this.price,
    required this.total,
    required this.gst,
    required this.tax,
    required this.image,
    required this.comment,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) => OrderProduct(
    orderProductId: json['order_product_id']?.toString() ?? '',
    orderId:        json['order_id']?.toString() ?? '',
    productId:      json['product_id']?.toString() ?? '',
    name:           json['name']?.toString() ?? '',
    model:          json['model']?.toString() ?? '',
    quantity:       json['quantity']?.toString() ?? '0',
    price:          json['price']?.toString() ?? '0.00',
    total:          json['total']?.toString() ?? '0.00',
    gst:            json['gst']?.toString() ?? '0',
    tax:            json['tax']?.toString() ?? '0.00',
    image:          json['image']?.toString() ?? '',
    comment: json['comment']?.toString() ?? '',
  );
}

class OrderInvoice {
  final String id;
  final String orderId;
  final String cashAmount;
  final String upiAmount;
  final String? upiRef;
  final String balance;
  final String discount;
  final String subTotal;
  final String totalTax;
  final String amountThrough;
  final String pendingAmount;
  final String returnableBalance;
  final String totalReceived;
  final String dateAdded;
  final String coupon;
  final String takeawayAmount;
  final String deliveryTime;

  const OrderInvoice({
    required this.id,
    required this.orderId,
    required this.cashAmount,
    required this.upiAmount,
    this.upiRef,
    required this.balance,
    required this.discount,
    required this.subTotal,
    required this.totalTax,
    required this.amountThrough,
    required this.pendingAmount,
    required this.returnableBalance,
    required this.totalReceived,
    required this.dateAdded,
    required this.coupon,
    required this.takeawayAmount,
    required this.deliveryTime,
  });

  factory OrderInvoice.fromJson(Map<String, dynamic> json) => OrderInvoice(
    id:                json['id']?.toString() ?? '',
    orderId:           json['order_id']?.toString() ?? '',
    cashAmount:        json['cash_amount']?.toString() ?? '0.00',
    upiAmount:         json['upi_amount']?.toString() ?? '0.00',
    upiRef:            json['upi_ref']?.toString(),
    balance:           json['balance']?.toString() ?? '0',
    discount:          json['discount']?.toString() ?? '0.00',
    subTotal:          json['sub_total']?.toString() ?? '0.00',
    totalTax:          json['total_tax']?.toString() ?? '0.00',
    amountThrough:     json['amount_through']?.toString() ?? '',
    pendingAmount:     json['pending_amount']?.toString() ?? '0.00',
    returnableBalance: json['returnable_balance']?.toString() ?? '0.00',
    totalReceived:     json['total_received']?.toString() ?? '0.00',
    dateAdded:         json['date_added']?.toString() ?? '',
    coupon:            json['coupon']?.toString() ?? '',
    takeawayAmount:    json['takeaway_amount']?.toString() ?? '0.00',
    deliveryTime:      json['delivary_time']?.toString() ?? '',
  );
}

class OrderHistory {
  final String orderHistoryId;
  final String orderId;
  final String orderStatusId;
  final String comment;
  final String dateAdded;
  final String statusName;

  const OrderHistory({
    required this.orderHistoryId,
    required this.orderId,
    required this.orderStatusId,
    required this.comment,
    required this.dateAdded,
    required this.statusName,
  });

  factory OrderHistory.fromJson(Map<String, dynamic> json) => OrderHistory(
    orderHistoryId: json['order_history_id']?.toString() ?? '',
    orderId:        json['order_id']?.toString() ?? '',
    orderStatusId:  json['order_status_id']?.toString() ?? '',
    comment:        json['comment']?.toString() ?? '',
    dateAdded:      json['date_added']?.toString() ?? '',
    statusName:     json['status_name']?.toString() ?? '',
  );
}

class TrackingStep {
  final String trackStatusId;
  final String name;
  final bool isCompleted;

  const TrackingStep({
    required this.trackStatusId,
    required this.name,
    required this.isCompleted,
  });

  factory TrackingStep.fromJson(Map<String, dynamic> json) => TrackingStep(
    trackStatusId: json['track_status_id']?.toString() ?? '',
    name:          json['name']?.toString() ?? '',
    isCompleted:   json['status']?.toString() == '1',
  );
}

class OrderInfo {
  final String orderId;
  final String invoiceNo;
  final String invoicePrefix;
  final String customerId;
  final String firstname;
  final String lastname;
  final String email;
  final String telephone;
  final String paymentMethod;
  final String total;
  final String orderStatusId;
  final String orderStatus;
  final String dateAdded;
  final String dateModified;
  final String currencyCode;
  final String takeaway_amount;
  final String comment;

  const OrderInfo({
    required this.orderId,
    required this.invoiceNo,
    required this.invoicePrefix,
    required this.customerId,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.telephone,
    required this.paymentMethod,
    required this.total,
    required this.orderStatusId,
    required this.orderStatus,
    required this.dateAdded,
    required this.dateModified,
    required this.currencyCode,
    required this.takeaway_amount,
    required this.comment,
  });

  String get fullName => '$firstname $lastname'.trim();

  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    String paymentMethod = '';
    final raw = json['payment_method'];
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
        paymentMethod = decoded['name']?.toString() ?? raw.toString();
      } catch (_) {
        paymentMethod = raw.toString();
      }
    }

    return OrderInfo(
      orderId:       json['order_id']?.toString() ?? '',
      invoiceNo:     json['invoice_no']?.toString() ?? '',
      invoicePrefix: json['invoice_prefix']?.toString() ?? '',
      customerId:    json['customer_id']?.toString() ?? '',
      firstname:     json['firstname']?.toString() ?? '',
      lastname:      json['lastname']?.toString() ?? '',
      email:         json['email']?.toString() ?? '',
      telephone:     json['telephone']?.toString() ?? '',
      paymentMethod: paymentMethod,
      total:         json['total']?.toString() ?? '0.00',
      orderStatusId: json['order_status_id']?.toString() ?? '',
      orderStatus:   json['order_status']?.toString() ?? '',
      dateAdded:     json['date_added']?.toString() ?? '',
      dateModified:  json['date_modified']?.toString() ?? '',
      currencyCode:  json['currency_code']?.toString() ?? 'INR',
      takeaway_amount:  json['takeaway_amount']?.toString() ?? '0.00',
      comment:       json['comment']?.toString() ?? '',
    );
  }
}

class Order {
  final OrderInfo info;
  final List<OrderProduct> products;
  final OrderInvoice? invoice;
  final List<OrderHistory> history;
  final List<TrackingStep> tracking;

  const Order({
    required this.info,
    required this.products,
    this.invoice,
    required this.history,
    required this.tracking,
  });

  String get effectiveStatus {
    final rawStatus = info.orderStatus.toLowerCase();
    if (rawStatus.contains('cancel') || rawStatus.contains('return')) {
      return info.orderStatus;
    }
    final completed = tracking.where((t) => t.isCompleted).toList();
    if (completed.isEmpty) return info.orderStatus;
    return completed.last.name;
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    info:     OrderInfo.fromJson(json['order_info'] as Map<String, dynamic>),
    products: (json['products'] as List<dynamic>? ?? [])
        .map((p) => OrderProduct.fromJson(p as Map<String, dynamic>))
        .toList(),
    invoice:  json['invoice'] != null
        ? OrderInvoice.fromJson(json['invoice'] as Map<String, dynamic>)
        : null,
    history:  (json['history'] as List<dynamic>? ?? [])
        .map((h) => OrderHistory.fromJson(h as Map<String, dynamic>))
        .toList(),
    tracking: (json['tracking'] as List<dynamic>? ?? [])
        .map((t) => TrackingStep.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

class OrderTotals {
  final String totalCash;
  final String totalUpi;
  final String totalReturnable;
  final String balance;
  final String totalSubtotal;
  final String totalReceived;

  const OrderTotals({
    required this.totalCash,
    required this.totalUpi,
    required this.totalReturnable,
    required this.balance,
    required this.totalSubtotal,
    required this.totalReceived,
  });

  factory OrderTotals.fromJson(Map<String, dynamic> json) => OrderTotals(
    totalCash:       json['total_cash']?.toString() ?? '0.00',
    totalUpi:        json['total_upi']?.toString() ?? '0.00',
    totalReturnable: json['total_returnable']?.toString() ?? '0.00',
    balance:         json['balance']?.toString() ?? '0',
    totalSubtotal:   json['total_subtotal']?.toString() ?? '0.00',
    totalReceived:   json['total_received']?.toString() ?? '0.00',
  );
}

class OrdersResponse {
  final String status;
  final int totalOrders;
  final OrderTotals totals;
  final List<Order> orders;

  const OrdersResponse({
    required this.status,
    required this.totalOrders,
    required this.totals,
    required this.orders,
  });

  factory OrdersResponse.fromJson(Map<String, dynamic> json) => OrdersResponse(
    status:      json['status']?.toString() ?? '',
    totalOrders: int.tryParse(json['total_orders']?.toString() ?? '0') ?? 0,
    totals:      OrderTotals.fromJson(json['totals'] as Map<String, dynamic>),
    orders:      (json['data'] as List<dynamic>? ?? [])
        .map((o) => Order.fromJson(o as Map<String, dynamic>))
        .toList(),
  );
}

class OrdersService {
  static final String _baseUrl =
      '${ApiConfig.indexPhp}?route=groceries/categories.getOrdersforMonths';

  static Future<OrdersResponse> getOrders({
    String? fromDate,
    String? toDate,
  }) async {
    final customerId = await SessionManager.getCustomerId();
    final telephone  = await SessionManager.getTelephone();
    final token      = await SessionManager.getToken();

    final params = <String, String>{};
    if (customerId != null && customerId.isNotEmpty) {
      params['customer_id'] = customerId;
    }
    if (telephone != null && telephone.isNotEmpty) {
      params['telephone'] = telephone;
    }
    if (token != null && token.isNotEmpty) {
      params['token']     = token;
      params['api_token'] = token;
    }
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate   != null) params['to_date']   = toDate;

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        ...Uri.parse(_baseUrl).queryParameters,
        ...params,
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final rawBody = response.body.trim();

        if (!rawBody.startsWith('{') && !rawBody.startsWith('[')) {
          throw const OrdersException(
            'Server returned an invalid response. Please try again later.',
          );
        }

        late Map<String, dynamic> json;
        try {
          json = jsonDecode(rawBody) as Map<String, dynamic>;
        } on FormatException catch (e) {
          throw const OrdersException(
            'Failed to parse server response. Please try again.',
          );
        }

        if (json['status'] == 'success') {
          return OrdersResponse.fromJson(json);
        } else {
          throw OrdersException(
            json['message']?.toString() ?? 'API returned non-success status',
          );
        }
      } else {
        throw OrdersException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on OrdersException {
      rethrow;
    } catch (e) {
      throw OrdersException('Failed to fetch orders: $e');
    }
  }
}

class OrdersException implements Exception {
  final String message;
  const OrdersException(this.message);

  @override
  String toString() => 'OrdersException: $message';
}