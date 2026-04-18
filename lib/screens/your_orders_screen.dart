import 'package:flutter/material.dart';
import '../services/your_orders_service.dart';
import '../services/api_config_service.dart';
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
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _retry() => _load();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Orders',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),

      body: RefreshableScreen(
        onRefresh: _retry,
        color: const Color(0xFF8B3A0F),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B3A0F)))
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
                        backgroundColor: const Color(0xFF8B3A0F),
                        foregroundColor: Colors.white),
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
            _SummaryBanner(totalOrders: _response!.totalOrders, totals: _response!.totals),
            const SizedBox(height: 12),
            ..._response!.orders.map((order) => _OrderCard(order: order, token: _token, onCancelled: _retry)),
          ],
        ),
      ),
    );
  }
}

// ── Summary Banner ──────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final int totalOrders;
  final OrderTotals totals;
  const _SummaryBanner({required this.totalOrders, required this.totals});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          // colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)],
          colors: [Color(0xFF8B3A0F), Color(0xFFB5541A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Total Orders', '$totalOrders', Icons.receipt_long),
          _vDivider(),
          _stat('Total Received', '\u20b9${totals.totalReceived}',
              Icons.account_balance_wallet_outlined),
          _vDivider(),
          _stat('Balance', '\u20b9${totals.balance}', Icons.savings_outlined),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white70, size: 18),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ],
  );

  Widget _vDivider() => Container(width: 1, height: 44, color: Colors.white30);
}

// ── Order Card ──────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Order order;
  final String token;
  final VoidCallback onCancelled;
  const _OrderCard({required this.order, required this.token, required this.onCancelled});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'complete':   return Colors.green;
      case 'canceled':
      case 'cancelled':  return Colors.red;
      case 'processing': return Colors.orange;
      case 'pending':    return Colors.amber;
      case 'returned':   return Colors.indigo;
      default:           return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'complete':   return Icons.check_circle;
      case 'canceled':
      case 'cancelled':  return Icons.cancel;
      case 'processing': return Icons.hourglass_bottom;
      case 'pending':    return Icons.access_time;
      case 'returned':   return Icons.assignment_return;
      default:           return Icons.info_outline;
    }
  }
  // ✅ Check if this order was returned by inspecting history
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

    // Build productDetails including invoice totals + coupon
    final productDetails = order.products.isNotEmpty
        ? {
      'price':         order.products.first.price,
      'special_price': '0',
      'quantity':      order.products.first.quantity,
      'gst':           order.products.first.gst,
      // ✅ Invoice fields for totals display
      'sub_total':     order.invoice?.subTotal ?? '0',
      'discount':      order.invoice?.discount ?? '0',
      'coupon':        order.invoice?.coupon   ?? '',
      'total_tax':     order.invoice?.totalTax ?? '0',
      'grand_total':   order.invoice?.totalReceived ?? '0',
    }
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(
          orderId:           info.orderId,
          productName:       productName,
          productImageUrl:   null,
          productDetails:    productDetails,
          estimatedDelivery: 'To be updated',
          token:             token,
          orderDate:         info.dateAdded,
          productId:         order.products.isNotEmpty
              ? order.products.first.productId
              : '',
          // ✅ NEW — pass all products as a list of maps
          products: order.products.map((p) => {
            'product_id':    p.productId,
            'name':          p.name,
            'image':         p.image,
            'price':         p.price,
            'special_price': '0',
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
    final status  = info.orderStatus;
    final color   = _statusColor(status);

    final invoiceLabel = info.invoiceNo.trim().isNotEmpty
        ? '${info.invoicePrefix}${info.invoiceNo}'
        : 'Order #${info.orderId}';

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
                    Icon(_statusIcon(status), color: color, size: 16),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(status,
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
                        size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(info.dateAdded.split(' ').first,
                        style:
                        TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  const SizedBox(height: 5),
                  Text(invoiceLabel,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
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
                          // color: Color(0xFF7C3AED)),
                          color: Color(0xFF8B3A0F)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(p.name,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87))),
                    Text('\u00d7 ${p.quantity}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.payment,
                          size: 14, color: Color(0xFF8B3A0F)),
                      const SizedBox(width: 4),
                      Text(
                        invoice?.amountThrough ?? info.paymentMethod,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B3A0F),
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                            text: 'Total  ',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12)),
                        TextSpan(
                            text: '\u20b9${info.total}',
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(children: [
                  // ── Track Order button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openTracking(context, invoiceLabel, token),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFFF0080), width: 1.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                size: 14, color: Color(0xFFFF0080)),
                            SizedBox(width: 5),
                            Text('Track Order',
                                style: TextStyle(
                                    color: Color(0xFFFF0080),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── View Details button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  OrderDetailScreen(orderId: info.orderId))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0080),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 14, color: Colors.white),
                            SizedBox(width: 5),
                            Text('View Details',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}