

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_color.dart';
import '../model/address_model.dart';
import '../model/product_model.dart';
import '../products/product_detail_screen.dart';
import '../services/api_config_service.dart';
import '../services/edit_address_service.dart';
import '../services/get_address_service.dart';
import '../services/cancel_order_service.dart';
import '../services/get_profile_service.dart';
import '../services/track_order_service.dart';
import '../services/return_order_service.dart';

import 'package:url_launcher/url_launcher.dart';

// ── Main Screen ──────────────────────────────────────────────────────────────
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String productName;
  final String? productImageUrl;
  final String estimatedDelivery;
  final String token;
  final String orderDate;
  final Map<String, dynamic>? productDetails;
  final String productId;
  final List<Map<String, dynamic>> products;
  final String invoiceNo;
  final String initialOrderStatus;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.productName,
    this.productImageUrl,
    required this.estimatedDelivery,
    required this.token,
    required this.orderDate,
    this.productDetails,
    this.productId = '',
    this.products = const [],
    this.invoiceNo = '',
    this.initialOrderStatus = '',
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  // ── Tracking state ──────────────────────────────────────────────────────
  List<TrackOrderStep> _trackSteps = [];
  bool _trackLoading = true;
  String? _trackError;

  bool _cancelling = false;
  bool _returning  = false;
  String? _fetchedImageUrl;
  String _orderStatus = '';
  final Map<String, String> _productImageCache = {};

  @override
  void initState() {
    super.initState();
    // Seed with the real order status passed from the caller (order list /
    // order detail screen) so cancellation is known immediately, instead of
    // waiting to infer it from tracking steps (which may never contain a
    // "Cancelled" step at all).
    _orderStatus = widget.initialOrderStatus.toLowerCase();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progressAnim = const AlwaysStoppedAnimation(0);

    _fetchTrackOrder();
    if (widget.productId.isNotEmpty) _fetchProductImage();
    _fetchAllProductImages();
  }

  // ── Fetch live tracking steps ───────────────────────────────────────────
  Future<void> _fetchTrackOrder() async {
    setState(() {
      _trackLoading = true;
      _trackError = null;
    });

    final result = await TrackOrderService.getTrackOrder(
      token: widget.token,
      orderId: widget.orderId,
    );

    if (!mounted) return;

    if (result.success) {
      final steps = result.steps;

      int activeStep = 0;
      for (int i = 0; i < steps.length; i++) {
        if (steps[i].isCompleted) activeStep = i;
      }

      _animController.reset();
      _progressAnim = Tween<double>(
        begin: 0,
        end: steps.isEmpty ? 0 : activeStep / (steps.length - 1).clamp(1, 9999),
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ));

      setState(() {
        _trackSteps = steps;
        _trackLoading = false;
        // Don't let tracking-step inference clobber a cancellation we
        // already know about from the real order status.
        final alreadyCancelled = _orderStatus == 'cancelled' || _orderStatus == 'canceled';
        if (!alreadyCancelled && steps.isNotEmpty) {
          for (int i = steps.length - 1; i >= 0; i--) {
            if (steps[i].isCompleted) {
              _orderStatus = steps[i].name.toLowerCase();
              break;
            }
          }
        }
      });

      _animController.forward();
    } else {
      setState(() {
        _trackError = result.message;
        _trackLoading = false;
      });
    }
  }

  // ── Fetch product image ─────────────────────────────────────────────────
  Future<void> _fetchProductImage() async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.route('groceries/categories.getProductDetails', token: widget.token)}'
            '&product_id=${widget.productId}',
      );
      final response =
      await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) return;
        final data = decoded;
        if (data['status'] == 'success' && data['product'] != null) {
          final rawProduct = data['product'];
          final Map<String, dynamic>? apiProduct;
          if (rawProduct is List) {
            apiProduct = rawProduct.isNotEmpty ? Map<String, dynamic>.from(rawProduct.first as Map) : null;
          } else if (rawProduct is Map) {
            apiProduct = Map<String, dynamic>.from(rawProduct);
          } else {
            apiProduct = null;
          }
          if (apiProduct == null) return;
          final rawImage = apiProduct['image']?.toString() ?? '';
          if (rawImage.isNotEmpty && mounted) {
            final fullUrl = rawImage.startsWith('http')
                ? rawImage
                : '${ApiConfig.imageBase}$rawImage';
            setState(() => _fetchedImageUrl = fullUrl);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchAllProductImages() async {
    for (final p in widget.products) {
      final productId = p['product_id']?.toString() ?? p['id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      try {
        final uri = Uri.parse(
          '${ApiConfig.route('groceries/categories.getProductDetails', token: widget.token)}'
              '&product_id=$productId',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) continue;
          final data = decoded;
          if (data['status'] == 'success' && data['product'] != null) {
            final rawProduct = data['product'];
            final Map<String, dynamic>? apiProduct;
            if (rawProduct is List) {
              apiProduct = rawProduct.isNotEmpty ? Map<String, dynamic>.from(rawProduct.first as Map) : null;
            } else if (rawProduct is Map) {
              apiProduct = Map<String, dynamic>.from(rawProduct);
            } else {
              apiProduct = null;
            }
            if (apiProduct == null) continue;
            final rawImage = apiProduct['image']?.toString() ?? '';
            if (rawImage.isNotEmpty && mounted) {
              final fullUrl = rawImage.startsWith('http')
                  ? rawImage
                  : '${ApiConfig.imageBase}$rawImage';
              setState(() => _productImageCache[productId] = fullUrl);
            }
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool get _isDelivered {
    return _trackSteps.any((s) =>
    (s.name.toLowerCase() == 'delivered' ||
        s.name.toLowerCase() == 'completed') &&
        s.isCompleted);
  }

  bool get _isCancelled {
    return _orderStatus == 'cancelled' || _orderStatus == 'canceled';
  }

  bool get _isShippedOrBeyond {
    const blockedStatuses = ['shipped', 'out for delivery', 'delivery', 'delivered', 'completed', 'cancelled', 'canceled'];
    return blockedStatuses.contains(_orderStatus);
  }

  int get _activeStep {
    int active = 0;
    for (int i = 0; i < _trackSteps.length; i++) {
      if (_trackSteps[i].isCompleted) active = i;
    }
    return active;
  }

  TrackStepStatus _stepStatus(int index) {
    if (_trackSteps[index].isCompleted) return TrackStepStatus.done;
    if (index == _activeStep + 1 || (index == 0 && !_trackSteps[0].isCompleted)) {
      return TrackStepStatus.active;
    }
    if (index == 0) return TrackStepStatus.active;
    return TrackStepStatus.pending;
  }

  IconData _iconForStep(String name) {
    switch (name.toLowerCase()) {
      case 'order placed': return Icons.receipt_long_outlined;
      case 'packed':       return Icons.inventory_2_outlined;
      case 'shipped':      return Icons.local_shipping_outlined;
      case 'out for delivery':
      case 'delivery':     return Icons.delivery_dining_outlined;
      case 'delivered':
      case 'completed':    return Icons.check_circle_outline;
      default:             return Icons.radio_button_unchecked;
    }
  }

  // ── Steps that actually completed before the order was cancelled ────────
  List<TrackOrderStep> _completedStepsBeforeCancel() {
    return _trackSteps.where((s) => s.isCompleted).toList();
  }

  // ── Open WhatsApp ────────────────────────────────────────────────────────
  Future<void> _openWhatsApp() async {
    try {
      final result = await ProfileGetApiService.getProfile();
      String phone = '';
      if (result['success'] == true) {
        final data = result['data'];
        phone = (data['contact'] ?? data['telephone'] ?? data['phone'] ?? data['mobile'] ?? '').toString().trim();
        phone = phone.replaceAll(RegExp(r'\D'), '');
      }
      if (phone.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Support number not available'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final uri = Uri.parse('https://wa.me/$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp is not installed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Cancel order ────────────────────────────────────────────────────────
  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel order #${widget.orderId}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);

    final result = await CancelOrderApi.cancelOrder(
      token: widget.token,
      orderId: widget.orderId,
    );

    if (!mounted) return;
    setState(() => _cancelling = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } else {
      final msg = result.message.toLowerCase();
      final alreadyCancelled = msg.contains('already cancel') ||
          msg.contains('already been cancel') ||
          msg.contains('invalid server response');

      if (alreadyCancelled) {
        setState(() => _orderStatus = 'cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This order is already cancelled.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty
                ? result.message
                : 'Failed to cancel order. Try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Return order ────────────────────────────────────────────────────────
  Future<void> _returnOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_return_outlined,
                color: Colors.blue, size: 22),
            SizedBox(width: 8),
            Text('Return Order'),
          ],
        ),
        content: Text(
          'Are you sure you want to return order #${widget.orderId}?\n\n'
              'Returns are accepted within 7 days of delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Return',
                style: TextStyle(
                    color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _returning = true);

    final result = await ReturnOrderApi.returnOrder(
      token:   widget.token,
      orderId: widget.orderId,
    );

    if (!mounted) return;
    setState(() => _returning = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isNotEmpty
              ? result.message
              : 'Order returned successfully'),
          backgroundColor: Colors.blue,
          behavior:        SnackBarBehavior.floating,
          duration:        const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message.isNotEmpty
              ? result.message
              : 'Failed to return order. Try again.'),
          backgroundColor: Colors.red,
          behavior:        SnackBarBehavior.floating,
          duration:        const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Open product detail sheet ───────────────────────────────────────────
  void _openProductDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(
        orderId: widget.orderId,
        productName: widget.productName,
        productImageUrl: _fetchedImageUrl ?? widget.productImageUrl,
        productDetails: widget.productDetails,
      ),
    );
  }

  void _openProductDetailForItem(Map<String, dynamic> p) {
    final productId = p['product_id']?.toString() ?? '';
    final name      = p['name']?.toString() ?? widget.productName;
    final rawImage  = (p['product_image'] ?? p['image'])?.toString().trim() ?? '';
    final imgUrl    = rawImage.startsWith('http')
        ? rawImage
        : rawImage.isNotEmpty && rawImage != 'no_image.png'
        ? '${ApiConfig.imageBase}$rawImage'
        : '';
    final specPrice = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0.0;
    final rawPrice  = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
    final price     = (specPrice > 0 && specPrice < rawPrice) ? specPrice : rawPrice;
    final product = Product(
      id:            productId,
      name:          name,
      price:         price,
      originalPrice: rawPrice,
      image:         rawImage,
      imageUrl:      imgUrl,
      category:      '',
      quantity:      (int.tryParse(p['quantity']?.toString() ?? '') ?? 0) > 0 ? int.tryParse(p['quantity'].toString())! : 1,
      posQuantity:   (int.tryParse(p['quantity']?.toString() ?? '') ?? 0) > 0 ? int.tryParse(p['quantity'].toString())! : 1,
      deliveryTime:  widget.estimatedDelivery,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  // ── Multi-product list ──────────────────────────────────────────────────
  Widget _buildProductList() {
    if (widget.products.isEmpty) {
      return GestureDetector(
        onTap: _openProductDetail,
        child: _buildProductCard(),
      );
    }

    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    color: AppColors.headerBanner, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${widget.products.length} item${widget.products.length > 1 ? 's' : ''} in this order',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.invoiceNo.isNotEmpty)
                      Text(
                        widget.invoiceNo,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    Text(
                      'Order #${widget.orderId}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...widget.products.asMap().entries.map((entry) {
            final isLast = entry.key == widget.products.length - 1;
            final p      = entry.value;
            return Column(
              children: [
                GestureDetector(
                  onTap: () => _openProductDetailForItem(p),
                  child: _buildProductCardForItem(p),
                ),
                if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            );
          }),
          if ((widget.productDetails ?? {}).containsKey('sub_total') ||
              (widget.productDetails ?? {}).containsKey('grand_total')) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: _buildOrderTotalsRow(widget.productDetails ?? {}),
            ),
          ],
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: () async {
          await _fetchTrackOrder();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildProductList(),
              const SizedBox(height: 16),
              _buildEtaBanner(),
              const SizedBox(height: 16),
              _buildCancellationBanner(),
              if (_isDelivered) ...[
                const SizedBox(height: 12),
                _buildReturnOrderBanner(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Track Order',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      actions: [
        TextButton.icon(
          onPressed: _openWhatsApp,
          icon: const Icon(Icons.headset_mic_outlined,
              color: AppColors.success, size: 18),
          label: const Text('HELP',
              style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[200]),
      ),
    );
  }

  Widget _buildProductCard() {
    final details   = widget.productDetails ?? {};
    final rawPrice  = double.tryParse(details['price']?.toString()         ?? '0') ?? 0.0;
    final specPrice = double.tryParse(details['special_price']?.toString() ?? '0') ?? 0.0;
    final hasOffer  = specPrice > 0 && specPrice < rawPrice;
    final sellPrice = hasOffer ? specPrice : rawPrice;
    final discount  = hasOffer
        ? (((rawPrice - specPrice) / rawPrice) * 100).round()
        : 0;
    final qty      = details['quantity']?.toString() ?? details['pos_quentity']?.toString() ?? '';
    final unit     = details['piece']?.toString()    ?? details['weight']?.toString() ?? '';
    final gst      = details['gst']?.toString()      ?? '';

    return Container(
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
          Builder(builder: (_) {
            final imgUrl = _fetchedImageUrl ?? widget.productImageUrl;
            return ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(14)),
              child: imgUrl != null && imgUrl.isNotEmpty
                  ? SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Image.network(imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: Colors.grey[100],
                          child: const Center(
                              child: Icon(Icons.inventory_2_outlined,
                                  color: AppColors.primaryOrange, size: 48)))))
                  : Container(
                  width: double.infinity,
                  height: 140,
                  color: Colors.grey[100],
                  child: const Center(
                      child: Icon(Icons.inventory_2_outlined,
                          color: AppColors.primaryOrange, size: 48))),
            );
          }),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(widget.productName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Order #${widget.orderId}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFF388E3C),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('₹${sellPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    if (hasOffer) ...[
                      Text('₹${rawPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('$discount% OFF',
                            style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),

                if (hasOffer) ...[
                  const SizedBox(height: 6),
                  Text('You save ₹${(rawPrice - specPrice).toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF388E3C),
                          fontWeight: FontWeight.w600)),
                ],

                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (unit.isNotEmpty)
                      _InfoChip(icon: Icons.scale_outlined, label: unit),
                    if (qty.isNotEmpty && qty != '0')
                      _InfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stock: $qty'),
                    if (gst.isNotEmpty && gst != '0' && gst != '0.00')
                      _InfoChip(
                          icon: Icons.receipt_outlined, label: 'GST $gst%'),
                  ],
                ),

                if (details.containsKey('sub_total') ||
                    details.containsKey('grand_total')) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _buildOrderTotalsRow(details),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCardForItem(Map<String, dynamic> p) {
    final name       = p['name']?.toString()          ?? widget.productName;
    final productId  = p['product_id']?.toString()    ?? p['id']?.toString() ?? '';

    final rawImage   = (p['product_image'] ?? p['image'])?.toString().trim() ?? '';
    final cachedImg  = _productImageCache[productId] ?? '';
    final imgUrl     = cachedImg.isNotEmpty
        ? cachedImg
        : rawImage.startsWith('http')
        ? rawImage
        : rawImage.isNotEmpty && rawImage != 'no_image.png'
        ? '${ApiConfig.imageBase}$rawImage'
        : '';
    final rawPrice   = double.tryParse(p['price']?.toString()         ?? '0') ?? 0.0;
    final specPrice  = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0.0;
    final hasOffer   = specPrice > 0 && specPrice < rawPrice;
    final sellPrice  = hasOffer ? specPrice : rawPrice;
    final discount   = hasOffer
        ? (((rawPrice - specPrice) / rawPrice) * 100).round()
        : 0;
    final unit       = p['piece']?.toString() ?? p['weight']?.toString() ?? '';
    final orderedQty = p['ordered_quantity']?.toString() ?? p['cart_quantity']?.toString() ?? '';

    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: imgUrl.isNotEmpty
                ? Image.network(
              imgUrl,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _productPlaceholder(),
            )
                : _productPlaceholder(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(unit,
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('₹${sellPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF388E3C))),
                      if (hasOffer) ...[
                        const SizedBox(width: 6),
                        Text('₹${rawPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('$discount% OFF',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  if (orderedQty.isNotEmpty && orderedQty != '0') ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFBF0EB),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('Qty: $orderedQty',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 44, right: 10),
            child: Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder() => Container(
    width: 110,
    height: 110,
    color: Colors.grey[100],
    child: const Center(
        child: Icon(Icons.inventory_2_outlined,
            color: AppColors.primaryOrange, size: 36)),
  );

  Widget _buildOrderTotalsRow(Map<String, dynamic> details) {
    final subTotal   = double.tryParse(details['sub_total']?.toString()   ?? '0') ?? 0;
    final discount   = double.tryParse(details['discount']?.toString()    ?? '0') ?? 0;
    final tax        = double.tryParse(details['total_tax']?.toString()   ?? '0') ?? 0;
    final grandTotal = double.tryParse(details['grand_total']?.toString() ?? '0') ?? 0;
    final coupon     = details['coupon']?.toString() ?? '';
    final delivery   = double.tryParse(details['takeaway_amount']?.toString() ?? '0') ?? 0.0;

    Widget row(String label, String value, {Color? color, IconData? icon}) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color ?? Colors.grey[600]),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(fontSize: 12, color: color ?? Colors.grey[600])),
          ]),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subTotal > 0) row('Subtotal', '₹${subTotal.toStringAsFixed(0)}'),
        if (tax > 0) row('Tax', '₹${tax.toStringAsFixed(0)}'),
        if (discount > 0)
          row(
            coupon.isNotEmpty ? 'Coupon ($coupon)' : 'Discount',
            '-₹${discount.toStringAsFixed(0)}',
            color: Colors.green[700],
          ),
        if (delivery > 0)
          row(
            'Delivery Charges',
            '+ ₹${delivery.toStringAsFixed(0)}',
            color: Colors.grey[700],
            icon: Icons.local_shipping_outlined,
          ),
        if (grandTotal > 0) ...[
          const Divider(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Paid',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              Text('₹${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF388E3C))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEtaBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.primaryOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estimated Delivery',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text(widget.estimatedDelivery,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.bolt, color: Colors.amber, size: 14),
                SizedBox(width: 8),
                Text('95% on time',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationBanner() {
    final isCancelled = _isCancelled;
    final isDisabled  = _isShippedOrBeyond;

    final bannerColor  = isCancelled ? Colors.red.shade50   : Colors.orange.shade50;
    final borderColor  = isCancelled ? Colors.red.shade200  : Colors.orange.shade200;
    final iconColor    = isCancelled ? Colors.red           : Colors.orange;
    final textColor    = isCancelled ? Colors.red.shade800  : Colors.orange.shade800;
    final bannerText   = isCancelled
        ? 'This order has been cancelled'
        : isDisabled
        ? 'Cancellation not available after Shipped'
        : 'This product is available for cancellation up to Shipped';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isCancelled ? Icons.cancel_outlined : Icons.info_outline,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bannerText,
              style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          if (_cancelling)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.red))
          else if (isCancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Cancelled',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            )
          else
            GestureDetector(
              onTap: isDisabled ? null : _cancelOrder,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: isDisabled ? Colors.grey.shade300 : AppColors.error,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Cancel',
                    style: TextStyle(
                        color: isDisabled ? Colors.grey : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnOrderBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_return_outlined,
              color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not satisfied? You can return this order within 7 days of delivery.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),

          _returning
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.blue),
          )
              : GestureDetector(
            onTap: _returnOrder,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Return',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

enum TrackStepStatus { done, active, pending }

// ── PUBLIC: Horizontal Stepper (used by both tracking and detail screens) ─────
class HorizontalStepper extends StatelessWidget {
  final List<TrackOrderStep> steps;
  final int activeStep;
  final Animation<double> progressAnim;
  final TrackStepStatus Function(int) stepStatus;
  final IconData Function(String) iconForStep;

  const HorizontalStepper({
    super.key,
    required this.steps,
    required this.activeStep,
    required this.progressAnim,
    required this.stepStatus,
    required this.iconForStep,
  });

  static const _orange = AppColors.primaryOrange;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalWidth = constraints.maxWidth;
      final segmentWidth =
      steps.length > 1 ? totalWidth / (steps.length - 1) : totalWidth;

      return SizedBox(
        height: 80,
        child: Stack(
          children: [
            // Grey background line
            Positioned(
              top: 18, left: 18, right: 18,
              child: Container(height: 3, color: Colors.grey[200]),
            ),
            // Animated fill line
            AnimatedBuilder(
              animation: progressAnim,
              builder: (_, __) => Positioned(
                top: 18,
                left: 18,
                child: Container(
                  height: 3,
                  width: (totalWidth - 36) * progressAnim.value,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_orange, AppColors.primaryOrange]),
                  ),
                ),
              ),
            ),
            // Step circles
            ...steps.asMap().entries.map((e) {
              final i = e.key;
              final step = e.value;
              final status = stepStatus(i);
              return Positioned(
                left: i * segmentWidth,
                top: 0,
                child: SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      StepCircle(
                          status: status,
                          icon: iconForStep(step.name)),
                      const SizedBox(height: 6),
                      Text(step.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: status == TrackStepStatus.active ||
                                status == TrackStepStatus.done
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: status == TrackStepStatus.pending
                                ? Colors.grey[400]
                                : Colors.black87,
                          )),
                    ],
                  ),
                ),
              );
            }),
            // Active tooltip
            if (steps.isNotEmpty)
              Positioned(
                top: -2,
                left: activeStep * segmentWidth - 20,
                child: _ShippingTooltip(label: steps[activeStep].name),
              ),
          ],
        ),
      );
    });
  }
}

// ── PUBLIC: Step Circle ───────────────────────────────────────────────────────
class StepCircle extends StatelessWidget {
  final TrackStepStatus status;
  final IconData icon;
  const StepCircle({super.key, required this.status, required this.icon});
  static const _blue = AppColors.primaryBlue;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TrackStepStatus.done:
        return Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: _blue),
          child: const Icon(Icons.check, color: Colors.white, size: 18),
        );
      case TrackStepStatus.active:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: _blue, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: _blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2)
            ],
          ),
          child: Icon(icon, color: _blue, size: 18),
        );
      case TrackStepStatus.pending:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[100],
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: Icon(icon, color: Colors.grey[400], size: 16),
        );
    }
  }
}

class _ShippingTooltip extends StatelessWidget {
  final String label;
  const _ShippingTooltip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        CustomPaint(
            size: const Size(10, 6), painter: _TrianglePainter()),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── PUBLIC: Vertical Timeline Row ─────────────────────────────────────────────
class TimelineRow extends StatelessWidget {
  final TrackOrderStep step;
  final TrackStepStatus status;
  final bool isLast;
  final String orderDate;

  const TimelineRow({
    super.key,
    required this.step,
    required this.status,
    required this.isLast,
    this.orderDate = '',
  });

  static const _blue = AppColors.primaryBlue;

  String _formattedDate() {
    if (orderDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(orderDate);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final hour = dt.hour > 12
          ? dt.hour - 12
          : dt.hour == 0
          ? 12
          : dt.hour;
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]}  $hour:$minute $amPm';
    } catch (_) {
      return orderDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone    = status == TrackStepStatus.done;
    final isActive  = status == TrackStepStatus.active;
    final isPending = status == TrackStepStatus.pending;
    final dateLabel = isDone || isActive ? _formattedDate() : '';
    final timeLabel = isPending ? 'Pending' : (isActive && orderDate.isEmpty ? 'In Progress' : '');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? _blue
                        : isActive
                        ? Colors.white
                        : Colors.grey[200],
                    border: isActive
                        ? Border.all(color: _blue, width: 2)
                        : null,
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : isActive
                      ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _blue),
                    ),
                  )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone
                          ? _blue.withOpacity(0.3)
                          : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(step.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive || isDone
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isPending
                                  ? Colors.grey[400]
                                  : Colors.black87)),
                      if (timeLabel.isNotEmpty)
                        Text(timeLabel,
                            style: TextStyle(
                                fontSize: 11,
                                color: isPending
                                    ? Colors.grey[300]
                                    : Colors.grey[500])),
                    ],
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(dateLabel,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDone
                                ? _blue
                                : isActive
                                ? _blue.withOpacity(0.7)
                                : Colors.grey[400])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── NEW: Red "Order Cancelled" terminal row for the vertical timeline ────────
class CancelledStepRow extends StatelessWidget {
  final String date;
  final String reason;
  const CancelledStepRow({super.key, required this.date, this.reason = ''});

  String _formattedDate() {
    if (date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min  = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]}  $hour:$min $ampm';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Cancelled',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                if (_formattedDate().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_formattedDate(),
                      style: TextStyle(fontSize: 12, color: Colors.red.shade300)),
                ],
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(reason,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primaryBlue.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.primaryBlue),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Product Detail Sheet ──────────────────────────────────────────────────────

class _ProductDetailSheet extends StatelessWidget {
  final String orderId;
  final String productName;
  final String? productImageUrl;
  final Map<String, dynamic>? productDetails;

  const _ProductDetailSheet({
    required this.orderId,
    required this.productName,
    this.productImageUrl,
    this.productDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            if (productImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(productImageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder()),
              )
            else
              _placeholder(),
            const SizedBox(height: 16),
            Text(productName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Text('Order #$orderId',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            if (productDetails != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ...productDetails!.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.key}: ',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    Expanded(
                        child: Text('${e.value}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87))),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: double.infinity,
    height: 200,
    decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.inventory_2_outlined,
        color: AppColors.primaryBlue, size: 64),
  );
}