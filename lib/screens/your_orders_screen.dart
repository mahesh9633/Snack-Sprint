// import 'package:flutter/material.dart';
// import '../config/app_color.dart';
// import '../services/api_config_service.dart';
// import '../services/your_orders_service.dart';
// import '../services/session_manager.dart';
// import '../widgets/refreshable_screen.dart';
// import 'order_details_screen.dart';
// import 'order_tracking_screen.dart';
//
// class YourOrdersScreen extends StatefulWidget {
//   const YourOrdersScreen({super.key});
//
//   @override
//   State<YourOrdersScreen> createState() => _YourOrdersScreenState();
// }
//
// class _YourOrdersScreenState extends State<YourOrdersScreen> {
//
//   OrdersResponse? _response;
//   bool _loading = true;
//   String _error = '';
//   String _token = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   Future<void> _load() async {
//     setState(() { _loading = true; _error = ''; });
//     try {
//       final token = await SessionManager.getToken();
//       _token = token ?? '';
//       final response = await OrdersService.getOrders();
//       if (mounted) setState(() { _response = response; _loading = false; });
//     } catch (e) {
//       if (mounted) setState(() { _error = e.toString(); _loading = false; });
//     }
//   }
//
//   Future<void> _retry() => _load();
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text('Your Orders',
//             style: TextStyle(
//                 color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18)),
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(1),
//           child: Container(height: 1, color: Colors.grey[200]),
//         ),
//       ),
//
//       body: RefreshableScreen(
//         onRefresh: _retry,
//         color: AppColors.primaryBlue,
//         child: _loading
//             ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
//             : _error.isNotEmpty
//             ? ListView(
//           children: [
//             Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(mainAxisSize: MainAxisSize.min, children: [
//                   const Icon(Icons.error_outline, size: 56, color: Colors.red),
//                   const SizedBox(height: 16),
//                   Text(_error,
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.grey[700], fontSize: 14)),
//                   const SizedBox(height: 20),
//                   ElevatedButton.icon(
//                     onPressed: _retry,
//                     icon: const Icon(Icons.refresh),
//                     label: const Text('Retry'),
//                     style: ElevatedButton.styleFrom(
//                         backgroundColor: AppColors.primaryOrange,
//                         foregroundColor: AppColors.textLight),
//                   ),
//                 ]),
//               ),
//             ),
//           ],
//         )
//             : _response == null || _response!.orders.isEmpty
//             ? ListView(
//           children: [
//             Center(
//               child: Column(mainAxisSize: MainAxisSize.min, children: [
//                 const SizedBox(height: 80),
//                 Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey[300]),
//                 const SizedBox(height: 16),
//                 Text('No orders yet',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
//                 const SizedBox(height: 8),
//                 Text('Your past orders will appear here.',
//                     style: TextStyle(color: Colors.grey[500])),
//               ]),
//             ),
//           ],
//         )
//             : ListView(
//           padding: const EdgeInsets.all(12),
//           children: [
//             ..._response!.orders.map((order) => _OrderCard(order: order, token: _token, onCancelled: _retry)),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ── Order Card ──────────────────────────────────────────────────────────────
// class _OrderCard extends StatelessWidget {
//   final Order order;
//   final String token;
//   final VoidCallback onCancelled;
//   const _OrderCard({required this.order, required this.token, required this.onCancelled});
//
//   Color _statusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'complete':
//       case 'completed':    return AppColors.success;
//       case 'canceled':
//       case 'cancelled':    return AppColors.error;
//       case 'processing':   return AppColors.warning;
//       case 'pending':      return AppColors.warning;
//       case 'returned':     return AppColors.primaryBlue;
//       case 'order placed': return AppColors.primaryBlue;
//       case 'packed':       return Colors.teal;
//       case 'shipped':      return AppColors.primaryBlue;
//       case 'delivered':    return AppColors.success;
//       default:             return Colors.blueGrey;
//     }
//   }
//
//   IconData _statusIcon(String status) {
//     switch (status.toLowerCase()) {
//       case 'complete':
//       case 'completed':    return Icons.check_circle;
//       case 'canceled':
//       case 'cancelled':    return Icons.cancel;
//       case 'processing':   return Icons.hourglass_bottom;
//       case 'pending':      return Icons.access_time;
//       case 'returned':     return Icons.assignment_return;
//       case 'order placed': return Icons.receipt_outlined;
//       case 'packed':       return Icons.inventory_2_outlined;
//       case 'shipped':      return Icons.local_shipping_outlined;
//       case 'delivered':    return Icons.done_all;
//       default:             return Icons.info_outline;
//     }
//   }
//
//   bool get _isReturned {
//     return order.history.any((h) =>
//     h.statusName.toLowerCase().contains('return') ||
//         h.comment.toLowerCase().contains('return'));
//   }
//
//   void _openTracking(BuildContext context, String invoiceLabel, String token) {
//     final info = order.info;
//
//     final productName = order.products.isNotEmpty
//         ? order.products.map((p) => p.name).join(', ')
//         : 'Order $invoiceLabel';
//
//     // Build productDetails including invoice totals + coupon
//     final productDetails = order.products.isNotEmpty
//         ? {
//       'price':         order.products.first.price,
//       'special_price': '0',
//       'quantity':      order.products.first.quantity,
//       'gst':           order.products.first.gst,
//       // ✅ Invoice fields for totals display
//       'sub_total':     order.invoice?.subTotal ?? '0',
//       'discount':      order.invoice?.discount ?? '0',
//       'coupon':        order.invoice?.coupon   ?? '',
//       'total_tax':     order.invoice?.totalTax ?? '0',
//       'grand_total':   order.invoice?.totalReceived ?? '0',
//       'takeaway_amount': order.invoice?.takeawayAmount ?? '0',
//       'advance_used':  order.invoice?.advanceUsed ?? '0',
//     }
//         : null;
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => OrderTrackingScreen(
//           orderId:           info.orderId,
//           productName:       productName,
//           productImageUrl:   null,
//           productDetails:    productDetails,
//           estimatedDelivery: 'To be updated',
//           token:             token,
//           orderDate:         info.dateAdded,
//           productId:         order.products.isNotEmpty
//               ? order.products.first.productId
//               : '',
//           invoiceNo: info.invoiceNo.trim().isNotEmpty
//               ? '${info.invoicePrefix}${info.invoiceNo}'
//               : 'Order #${info.orderId}',
//           // ✅ NEW — pass all products as a list of maps
//           products: order.products.map((p) => {
//             'product_id':       p.productId,
//             'name':             p.name,
//             'image':            p.image.isNotEmpty
//                 ? '${ApiConfig.imageBase}${p.image}'
//                 : '',
//             'price':            p.price,
//             'special_price':    '0',
//             'ordered_quantity': p.quantity,
//           }).toList(),
//         ),
//       ),
//     ).then((cancelled) {
//       if (cancelled == true) {
//         onCancelled();
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final info    = order.info;
//     final invoice = order.invoice;
//     final status  = order.effectiveStatus;
//     final color   = _statusColor(status);
//
//     final invoiceLabel = 'Order #${info.orderId}';
//
//     final showDeliveryTime =
//         invoice != null &&
//             invoice.deliveryTime.isNotEmpty &&
//             status.toLowerCase() != 'delivered' &&
//             status.toLowerCase() != 'complete' &&
//             status.toLowerCase() != 'completed';
//
//     return GestureDetector(
//       onTap: () => Navigator.push(context,
//           MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: info.orderId))),
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           boxShadow: [
//             BoxShadow(
//                 color: Colors.black.withOpacity(0.05),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2))
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//
//             // ── Header ─────────────────────────────────────────────────
//             Container(
//               padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.06),
//                 borderRadius:
//                 const BorderRadius.vertical(top: Radius.circular(14)),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(children: [
//                     Icon(_statusIcon(status), color: color, size: 16),
//                     const SizedBox(width: 5),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 9, vertical: 3),
//                       decoration: BoxDecoration(
//                           color: color,
//                           borderRadius: BorderRadius.circular(20)),
//                       child: Text(status,
//                           style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 11,
//                               fontWeight: FontWeight.bold)),
//                     ),
//                     // ✅ Show "Returned" badge if order was returned
//                     if (_isReturned) ...[
//                       const SizedBox(width: 6),
//                       const Icon(Icons.arrow_forward,
//                           size: 12, color: Colors.indigo),
//                       const SizedBox(width: 4),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 8, vertical: 3),
//                         decoration: BoxDecoration(
//                             color: Colors.indigo,
//                             borderRadius: BorderRadius.circular(20)),
//                         child: const Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(Icons.assignment_return,
//                                 size: 10, color: Colors.white),
//                             SizedBox(width: 3),
//                             Text('Returned',
//                                 style: TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 11,
//                                     fontWeight: FontWeight.bold)),
//                           ],
//                         ),
//                       ),
//                     ],
//                     const Spacer(),
//                     Icon(Icons.calendar_today_outlined,
//                         size: 12, color: Colors.black87),
//                     const SizedBox(width: 4),
//                     Text(info.dateAdded.split(' ').first,
//                         style:
//                         TextStyle(fontSize: 11, color: Colors.black87)),
//                   ]),
//                   const SizedBox(height: 5),
//                   Row(
//                     children: [
//                       Text(invoiceLabel,
//                         style: const TextStyle(
//                           fontSize: 15,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black87
//                         )
//                       ),
//                       if (showDeliveryTime) ...[
//                         const Spacer(),
//                         const Icon(Icons.schedule, size: 12, color: AppColors.primaryOrange),
//                         const SizedBox(width: 3),
//                         Text(
//                           'Delivery in ${invoice!.deliveryTime}',
//                           style: const TextStyle(
//                             fontSize: 11,
//                             color: AppColors.primaryOrange,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                   if (status.toLowerCase().contains('cancel') &&
//                       info.comment.trim().isNotEmpty) ...[
//                     const SizedBox(height: 6),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Colors.red.shade50,
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                       child: Row(children: [
//                         Icon(Icons.info_outline, size: 13, color: Colors.red.shade400),
//                         const SizedBox(width: 6),
//                         Expanded(
//                           child: Text(
//                             info.comment,
//                             style: TextStyle(fontSize: 11.5, color: Colors.red.shade700),
//                           ),
//                         ),
//                       ]),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//
//             // ── Products ───────────────────────────────────────────────
//             Padding(
//               padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: order.products
//                     .map((p) => Padding(
//                   padding: const EdgeInsets.only(bottom: 6),
//                   child: Row(children: [
//                     Container(
//                       width: 6, height: 6,
//                       decoration: const BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: AppColors.primaryOrange),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                         child: Text(p.name,
//                             style: const TextStyle(
//                                 fontSize: 15, color: Colors.black87))),
//                     Text('\u00d7 ${p.quantity}',
//                         style: TextStyle(
//                             fontSize: 12, color: Colors.black87)),
//                     const SizedBox(width: 8),
//                     Text('\u20b9${p.total}',
//                         style: const TextStyle(
//                             fontSize: 13, fontWeight: FontWeight.w600)),
//                   ]),
//                 ))
//                     .toList(),
//               ),
//             ),
//
//             const Divider(height: 18, indent: 14, endIndent: 14),
//
//             // ── Footer: Payment + Total + Buttons ──────────────────────
//             Padding(
//               padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
//               child: Column(children: [
//                 Builder(builder: (_) {
//                   final advanceUsed     = double.tryParse(invoice?.advanceUsed ?? '0') ?? 0.0;
//                   final cashAmt         = double.tryParse(invoice?.cashAmount ?? '0') ?? 0.0;
//                   final upiAmt          = double.tryParse(invoice?.upiAmount ?? '0') ?? 0.0;
//                   final rawGrandTotal   = double.tryParse(invoice?.totalReceived ?? info.total) ?? 0.0;
//                   // If nothing was received in cash/UPI but the wallet
//                   // covered the order, show the wallet amount as the
//                   // total instead of a misleading ₹0.
//                   final paidByWallet = rawGrandTotal <= 0 && advanceUsed > 0;
//                   final grandTotal   = paidByWallet ? advanceUsed : rawGrandTotal;
//                   final subTotal        = double.tryParse(invoice?.subTotal ?? '0') ?? 0.0;
//                   final totalTax        = double.tryParse(invoice?.totalTax ?? '0') ?? 0.0;
//                   final discount        = double.tryParse(invoice?.discount ?? '0') ?? 0.0;
//                   final delivery        = double.tryParse(invoice?.takeawayAmount ?? '0') ?? 0;
//                   final coupon          = invoice?.coupon ?? '';
//                   final paymentLabel = (cashAmt <= 0 && upiAmt <= 0 && advanceUsed > 0)
//                       ? 'Wallet'
//                       : (invoice?.amountThrough ?? info.paymentMethod);
//
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(children: [
//                             const Icon(Icons.payment,
//                                 size: 14, color: AppColors.primaryBlue),
//                             const SizedBox(width: 4),
//                             Text(paymentLabel,
//                                 style: const TextStyle(
//                                     fontSize: 12,
//                                     color: AppColors.primaryBlue,
//                                     fontWeight: FontWeight.w500)),
//                           ]),
//                           Text('₹${subTotal.toStringAsFixed(2)}',
//                               style: const TextStyle(
//                                   fontSize: 13,
//                                   color: Colors.black87,
//                                   fontWeight: FontWeight.w500)),
//                         ],
//                       ),
//                       if (advanceUsed > 0 && !paidByWallet) ...[
//                         const SizedBox(height: 4),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Row(children: [
//                               const Icon(Icons.account_balance_wallet,
//                                   size: 13, color: Color(0xFF6A1B9A)),
//                               const SizedBox(width: 4),
//                               const Text('Wallet Used',
//                                   style: TextStyle(
//                                       fontSize: 12, color: Color(0xFF6A1B9A))),
//                             ]),
//                             Text('₹${advanceUsed.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                     fontSize: 12, color: Color(0xFF6A1B9A))),
//                           ],
//                         ),
//                       ],
//                       if (discount > 0) ...[
//                         const SizedBox(height: 4),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Row(children: [
//                               const Icon(Icons.local_offer_outlined,
//                                   size: 13, color: AppColors.success),
//                               const SizedBox(width: 4),
//                               Text(
//                                 coupon.isNotEmpty ? 'Coupon ($coupon)' : 'Discount',
//                                 style: const TextStyle(
//                                     fontSize: 12, color: AppColors.success),
//                               ),
//                             ]),
//                             Text('- ₹${discount.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                     fontSize: 12, color: AppColors.success)),
//                           ],
//                         ),
//                       ],
//                       if (delivery > 0) ...[
//                         const SizedBox(height: 4),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Row(children: [
//                               const Icon(Icons.local_shipping_outlined,
//                                   size: 13, color: Colors.grey),
//                               const SizedBox(width: 4),
//                               const Text('Delivery Charges',
//                                   style: TextStyle(
//                                       fontSize: 12, color: Colors.grey)),
//                             ]),
//                             Text('+ ₹${delivery.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                     fontSize: 12, color: Colors.grey)),
//                           ],
//                         ),
//                       ],
//                       const Padding(
//                         padding: EdgeInsets.symmetric(vertical: 5),
//                         child: Divider(height: 1, color: AppColors.divider),
//                       ),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Text('Total',
//                               style: TextStyle(
//                                   fontSize: 12, color: Colors.black87)),
//                           Text('₹${grandTotal.toStringAsFixed(2)}',
//                               style: TextStyle(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.bold,
//                                   color: paidByWallet
//                                       ? const Color(0xFF6A1B9A)
//                                       : Colors.black)),
//                         ],
//                       ),
//                     ],
//                   );
//                 }),
//
//                 const SizedBox(height: 10),
//
//                 GestureDetector(
//                   onTap: () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (_) =>
//                               OrderDetailScreen(orderId: info.orderId))),
//                   child: Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.symmetric(vertical: 9),
//                     decoration: BoxDecoration(
//                       color: AppColors.primaryOrange,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.receipt_long_outlined,
//                             size: 16, color: AppColors.textLight),
//                         SizedBox(width: 5),
//                         Text('View Details',
//                             style: TextStyle(
//                                 color: AppColors.textLight,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold)),
//                       ],
//                     ),
//                   ),
//                 ),
//               ]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_color.dart';
import '../services/api_config_service.dart';
import '../services/your_orders_service.dart';
import '../services/session_manager.dart';
import '../widgets/refreshable_screen.dart';
import 'order_details_screen.dart';
import 'order_tracking_screen.dart';

class YourOrdersScreen extends StatefulWidget {
  const YourOrdersScreen({super.key});

  @override
  State<YourOrdersScreen> createState() => _YourOrdersScreenState();
}
class _YourOrdersScreenState extends State<YourOrdersScreen> {

  OrdersResponse? _response;
  bool _loading = true;
  String _error = '';
  String _token = '';

  // ── Local "just requested" fallback flags (per orderId), used only for
  // orders that don't yet have a `cancellation_request` field from the
  // server. Once your backend exposes that field, this map is ignored
  // for that order. ─────────────────────────────────────────────────────
  Map<String, bool> _localPendingFlags = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final token = await SessionManager.getToken();
      _token = token ?? '';
      final response = await OrdersService.getOrders();
      if (mounted) setState(() { _response = response; _loading = false; });
      await _syncLocalPendingFlags();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Read 'cancel_requested_<orderId>' flags. If the server now has a
  // cancellation_request for that order, OR the order is really cancelled,
  // clear the stale local flag — the server is authoritative from here. ──
  Future<void> _syncLocalPendingFlags() async {
    if (_response == null) return;
    final prefs = await SharedPreferences.getInstance();
    final flags = <String, bool>{};

    for (final order in _response!.orders) {
      final orderId = order.info.orderId;
      final key = 'cancel_requested_$orderId';
      final pending = prefs.getBool(key) ?? false;
      if (!pending) continue;

      final hasServerInfo = order.cancellationRequest != null;
      final isReallyCancelled = order.effectiveStatus.toLowerCase().contains('cancel');

      if (hasServerInfo || isReallyCancelled) {
        await prefs.remove(key);
      } else {
        flags[orderId] = true;
      }
    }

    if (mounted) setState(() => _localPendingFlags = flags);
  }

  Future<void> _retry() => _load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Orders',
            style: TextStyle(
                color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),

      body: RefreshableScreen(
        onRefresh: _retry,
        color: AppColors.primaryBlue,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
            : _error.isNotEmpty
            ? ListView(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: AppColors.textLight),
                  ),
                ]),
              ),
            ),
          ],
        )
            : _response == null || _response!.orders.isEmpty
            ? ListView(
          children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 80),
                Icon(Icons.shopping_bag_outlined, size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No orders yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                const SizedBox(height: 8),
                Text('Your past orders will appear here.',
                    style: TextStyle(color: Colors.grey[500])),
              ]),
            ),
          ],
        )
            : ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ..._response!.orders.map((order) => _OrderCard(
              order: order,
              token: _token,
              onCancelled: _retry,
              localPending: _localPendingFlags[order.info.orderId] ?? false,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Order Card ──────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final String token;
  final VoidCallback onCancelled;
  final bool localPending;
  const _OrderCard({
    required this.order,
    required this.token,
    required this.onCancelled,
    this.localPending = false,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
      case 'completed':    return AppColors.success;
      case 'canceled':
      case 'cancelled':    return AppColors.error;
      case 'processing':   return AppColors.warning;
      case 'pending':      return AppColors.warning;
      case 'returned':     return AppColors.primaryBlue;
      case 'order placed': return AppColors.primaryBlue;
      case 'packed':       return Colors.teal;
      case 'shipped':      return AppColors.primaryBlue;
      case 'delivered':    return AppColors.success;
      default:             return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
      case 'completed':    return Icons.check_circle;
      case 'canceled':
      case 'cancelled':    return Icons.cancel;
      case 'processing':   return Icons.hourglass_bottom;
      case 'pending':      return Icons.access_time;
      case 'returned':     return Icons.assignment_return;
      case 'order placed': return Icons.receipt_outlined;
      case 'packed':       return Icons.inventory_2_outlined;
      case 'shipped':      return Icons.local_shipping_outlined;
      case 'delivered':    return Icons.done_all;
      default:             return Icons.info_outline;
    }
  }

  bool get _isReturned {
    return order.history.any((h) =>
    h.statusName.toLowerCase().contains('return') ||
        h.comment.toLowerCase().contains('return'));
  }

  void _openTracking(BuildContext context, String invoiceLabel, String token) {
    final info = order.info;

    final productName = order.products.isNotEmpty
        ? order.products.map((p) => p.name).join(', ')
        : 'Order $invoiceLabel';

    final productDetails = order.products.isNotEmpty
        ? {
      'price':         order.products.first.price,
      'special_price': '0',
      'quantity':      order.products.first.quantity,
      'gst':           order.products.first.gst,
      'sub_total':     order.invoice?.subTotal ?? '0',
      'discount':      order.invoice?.discount ?? '0',
      'coupon':        order.invoice?.coupon   ?? '',
      'total_tax':     order.invoice?.totalTax ?? '0',
      'grand_total':   order.invoice?.totalReceived ?? '0',
      'takeaway_amount': order.invoice?.takeawayAmount ?? '0',
      'advance_used':  order.invoice?.advanceUsed ?? '0',
    }
        : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(
          orderId:              info.orderId,
          productName:          productName,
          productImageUrl:      null,
          productDetails:       productDetails,
          estimatedDelivery:    'To be updated',
          token:                token,
          orderDate:            info.dateAdded,
          cancellationStatus:   order.cancellationRequest?.status,
          cancellationComment:  order.cancellationRequest?.adminComment ?? '',
          productId:            order.products.isNotEmpty
              ? order.products.first.productId
              : '',
          invoiceNo: info.invoiceNo.trim().isNotEmpty
              ? '${info.invoicePrefix}${info.invoiceNo}'
              : 'Order #${info.orderId}',
          products: order.products.map((p) => {
            'product_id':       p.productId,
            'name':             p.name,
            'image':            p.image.isNotEmpty
                ? '${ApiConfig.imageBase}${p.image}'
                : '',
            'price':            p.price,
            'special_price':    '0',
            'ordered_quantity': p.quantity,
          }).toList(),
        ),
      ),
    ).then((cancelled) {
      if (cancelled == true) {
        onCancelled();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final info    = order.info;
    final invoice = order.invoice;
    final status  = order.effectiveStatus;
    final color   = _statusColor(status);

    final invoiceLabel = 'Order #${info.orderId}';

    final showDeliveryTime =
        invoice != null &&
            invoice.deliveryTime.isNotEmpty &&
            status.toLowerCase() != 'delivered' &&
            status.toLowerCase() != 'complete' &&
            status.toLowerCase() != 'completed';

    // ✅ Cancellation-request state — server field wins when present;
    // otherwise fall back to the local "just requested" flag (pending-only).
    final cr = order.cancellationRequest;
    final notActuallyCancelled = !status.toLowerCase().contains('cancel');
    final isPending  = cr != null
        ? (cr.isPending && notActuallyCancelled)
        : (localPending && notActuallyCancelled);
    final isRejected = cr != null && cr.isRejected && notActuallyCancelled;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: info.orderId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      isPending ? Icons.hourglass_top
                          : isRejected ? Icons.block
                          : _statusIcon(status),
                      color: isPending ? AppColors.info
                          : isRejected ? Colors.red
                          : color,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: isPending ? AppColors.info
                              : isRejected ? Colors.red
                              : color,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          isPending ? 'Pending Approval'
                              : isRejected ? 'Cancellation Rejected'
                              : status,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    // ✅ Show "Returned" badge if order was returned
                    if (_isReturned) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward,
                          size: 12, color: Colors.indigo),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_return,
                                size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Returned',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(info.dateAdded.split(' ').first,
                        style:
                        TextStyle(fontSize: 11, color: Colors.black87)),
                  ]),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(invoiceLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87
                          )
                      ),
                      if (showDeliveryTime) ...[
                        const Spacer(),
                        const Icon(Icons.schedule, size: 12, color: AppColors.primaryOrange),
                        const SizedBox(width: 3),
                        Text(
                          'Delivery in ${invoice!.deliveryTime}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Cancellation requested — waiting for admin approval',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (isRejected) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 13, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cr!.adminComment.isNotEmpty
                                ? 'Cancellation rejected: ${cr.adminComment}'
                                : 'Your cancellation request was rejected.',
                            style: TextStyle(fontSize: 11.5, color: Colors.red.shade700),
                          ),
                        ),
                      ]),
                    ),
                  ],
                  if (status.toLowerCase().contains('cancel') &&
                      info.comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 13, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            info.comment,
                            style: TextStyle(fontSize: 11.5, color: Colors.red.shade700),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),

            // ── Products ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: order.products
                    .map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryOrange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(p.name,
                            style: const TextStyle(
                                fontSize: 15, color: Colors.black87))),
                    Text('\u00d7 ${p.quantity}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black87)),
                    const SizedBox(width: 8),
                    Text('\u20b9${p.total}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ))
                    .toList(),
              ),
            ),

            const Divider(height: 18, indent: 14, endIndent: 14),

            // ── Footer: Payment + Total + Buttons ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(children: [
                Builder(builder: (_) {
                  final advanceUsed     = double.tryParse(invoice?.advanceUsed ?? '0') ?? 0.0;
                  final cashAmt         = double.tryParse(invoice?.cashAmount ?? '0') ?? 0.0;
                  final upiAmt          = double.tryParse(invoice?.upiAmount ?? '0') ?? 0.0;
                  final rawGrandTotal   = double.tryParse(invoice?.totalReceived ?? info.total) ?? 0.0;
                  final paidByWallet = rawGrandTotal <= 0 && advanceUsed > 0;
                  final grandTotal   = paidByWallet ? advanceUsed : rawGrandTotal;
                  final subTotal        = double.tryParse(invoice?.subTotal ?? '0') ?? 0.0;
                  final totalTax        = double.tryParse(invoice?.totalTax ?? '0') ?? 0.0;
                  final discount        = double.tryParse(invoice?.discount ?? '0') ?? 0.0;
                  final delivery        = double.tryParse(invoice?.takeawayAmount ?? '0') ?? 0;
                  final coupon          = invoice?.coupon ?? '';
                  final paymentLabel = (cashAmt <= 0 && upiAmt <= 0 && advanceUsed > 0)
                      ? 'Wallet'
                      : (invoice?.amountThrough ?? info.paymentMethod);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.payment,
                                size: 14, color: AppColors.primaryBlue),
                            const SizedBox(width: 4),
                            Text(paymentLabel,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w500)),
                          ]),
                          Text('₹${subTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      if (advanceUsed > 0 && !paidByWallet) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.account_balance_wallet,
                                  size: 13, color: Color(0xFF6A1B9A)),
                              const SizedBox(width: 4),
                              const Text('Wallet Used',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF6A1B9A))),
                            ]),
                            Text('₹${advanceUsed.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF6A1B9A))),
                          ],
                        ),
                      ],
                      if (discount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.local_offer_outlined,
                                  size: 13, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text(
                                coupon.isNotEmpty ? 'Coupon ($coupon)' : 'Discount',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.success),
                              ),
                            ]),
                            Text('- ₹${discount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.success)),
                          ],
                        ),
                      ],
                      if (delivery > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.local_shipping_outlined,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              const Text('Delivery Charges',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ]),
                            Text('+ ₹${delivery.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Divider(height: 1, color: AppColors.divider),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black87)),
                          Text('₹${grandTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: paidByWallet
                                      ? const Color(0xFF6A1B9A)
                                      : Colors.black)),
                        ],
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 10),

                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(orderId: info.orderId))),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 16, color: AppColors.textLight),
                        SizedBox(width: 5),
                        Text('View Details',
                            style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}