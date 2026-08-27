import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:mtl_groceriesapp/model/cart_model.dart';

import '../config/app_color.dart';
import '../model/product_model.dart';
import '../products/product_detail_screen.dart';
import '../services/api_config_service.dart';
import '../services/get_profile_service.dart';
import '../services/session_manager.dart';
import '../services/store_profile_cache.dart';
import '../utils/stock_resolver.dart';
import '../widgets/piece_selector_sheet.dart';
import 'address_selection_page.dart';

final String _kImgBase = ApiConfig.imageBase;

Widget _safeProductImage(String image, String imageUrl) {
  String url = '';
  if (imageUrl.isNotEmpty && imageUrl != 'no_image.png') {
    url = imageUrl.startsWith('http') ? imageUrl : '$_kImgBase$imageUrl';
  } else if (image.isNotEmpty && image != 'no_image.png') {
    url = image.startsWith('http') ? image : '$_kImgBase$image';
  }

  if (url.isNotEmpty) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, prog) =>
      prog == null ? child : Container(color: AppColors.sidebarBg),
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
    );
  }
  return _imgPlaceholder();
}

Widget _imgPlaceholder() => Container(
  color: AppColors.sidebarBg,
  child: const Center(
    child: Icon(Icons.image_not_supported,
        color: Colors.grey, size: 30),
  ),
);

Future<Map<String, dynamic>?> _fetchProductDetailsRaw(
    String productId, String? token) async {
  try {
    final uri = Uri.parse(
      '${ApiConfig.route('groceries/categories.getProductDetails', token: token)}&product_id=$productId',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 || response.body.isEmpty) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['status']?.toString() != 'success' || decoded['product'] == null) {
      return null;
    }

    final rawProduct = decoded['product'];
    if (rawProduct is List) {
      return rawProduct.isNotEmpty
          ? Map<String, dynamic>.from(rawProduct.first as Map)
          : null;
    } else if (rawProduct is Map) {
      return Map<String, dynamic>.from(rawProduct);
    }
    return null;
  } catch (_) {
    return null;
  }
}

Product _freshProductFromApiMap(
    Map<String, dynamic> apiProduct, {
      required String overrideId,
      String? pieceId,
    }) {
  final int productLevelQty = resolveProductQuantity(apiProduct);
  final bool productIsCombo = resolveIsCombo(apiProduct);

  final double rawPrice     = double.tryParse(apiProduct['price']?.toString() ?? '0') ?? 0;
  final double specialPrice = double.tryParse(apiProduct['special_price']?.toString() ?? '0') ?? 0;

  double displayPrice  = (specialPrice > 0 && specialPrice < rawPrice) ? specialPrice : rawPrice;
  double originalPrice = rawPrice;
  String weight        = apiProduct['piece']?.toString() ?? '';
  int    stock         = productLevelQty;

  List<ProductPiece> pieces = [];
  final rawPieces = apiProduct['pieces'];
  if (rawPieces is List) {
    for (final p in rawPieces) {
      if (p is Map<String, dynamic>) {
        final pp     = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
        final ps     = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0;
        final minQty = int.tryParse(p['min_quantity']?.toString() ?? '0') ?? 0;
        final pName  = p['piece']?.toString() ?? '';
        final label  = (minQty > 1 && pName.isNotEmpty) ? '$pName × $minQty' : pName;
        final pStock = resolvePieceStock(
          p,
          productIsCombo: productIsCombo,
          productLevelQty: productLevelQty,
        );
        pieces.add(ProductPiece(
          rowId:        p['id']?.toString() ?? '',
          pieceId:      p['piece_id']?.toString() ?? '',
          label:        label,
          price:        pp,
          specialPrice: ps,
          image:        p['image']?.toString() ?? '',
          minQuantity:  minQty,
          isCombo:      productIsCombo,
          stock:        pStock,
        ));
      }
    }
  }

  if (pieceId != null && pieceId.isNotEmpty) {
    final matches = pieces.where((pc) => pc.pieceId == pieceId);
    if (matches.isNotEmpty) {
      final m       = matches.first;
      displayPrice  = m.effectivePrice;
      originalPrice = m.hasDiscount ? m.price : m.effectivePrice;
      weight        = m.label;
      stock         = m.stock;
      pieces        = [m];
    } else {
      stock = 0;
    }
  }

  return Product(
    id:                 overrideId,
    name:               apiProduct['name']?.toString() ?? '',
    price:              displayPrice,
    originalPrice:      originalPrice,
    category:           apiProduct['category']?.toString() ?? '',
    weight:             weight,
    discountPercentage: 0,
    quantity:           stock,
    posQuantity:        stock,
    pieces:             pieces,
    isCombo:            productIsCombo,
  );
}

class CartScreen extends StatefulWidget {
  final VoidCallback? onGoToHome;
  final VoidCallback? onRefresh;
  final String token;
  final String customerId;

  const CartScreen({
    super.key,
    this.onGoToHome,
    this.onRefresh,
    required this.token,
    required this.customerId,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double _minOrderValue = StoreProfileCache.minOrderValue;
  double _storeDeliveryFee = StoreProfileCache.deliveryFee;
  double _deliveryOrderValue = StoreProfileCache.deliveryOrderValue;
  double _deliveryFee = 0;
  double _finalTotal = 0;

  Timer? _autoRefreshTimer;
  static const Duration _kCartRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cart = Provider.of<CartModel>(context, listen: false);
      _recalculateTotals(cart.totalPrice);
    });
    _fetchMinOrderValue();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_kCartRefreshInterval, (_) {
      _refreshCartItemPrices();
      _fetchMinOrderValue();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshCartItemPrices() async {
    if (!mounted) return;
    final cart = Provider.of<CartModel>(context, listen: false);
    if (cart.items.isEmpty) return;

    try {
      final token = await SessionManager.getString('token') ?? widget.token;

      final Map<String, List<String>> baseIdToCartIds = {};
      for (final cartId in cart.items.keys) {
        final baseId = cartId.contains('_piece_')
            ? cartId.split('_piece_').first
            : cartId;
        baseIdToCartIds.putIfAbsent(baseId, () => []).add(cartId);
      }

      for (final baseId in baseIdToCartIds.keys) {
        if (!mounted) return;

        final apiProduct = await _fetchProductDetailsRaw(baseId, token);
        if (apiProduct == null) continue;

        for (final cartId in baseIdToCartIds[baseId]!) {
          final isPieceVariant = cartId.contains('_piece_');
          final pieceId = isPieceVariant ? cartId.split('_piece_').last : null;

          final freshProduct = _freshProductFromApiMap(
            apiProduct,
            overrideId: cartId,
            pieceId: pieceId,
          );

          final entryNow = cart.items[cartId];
          if (entryNow == null) continue;
          final stored = entryNow.product;

          if (freshProduct.quantity <= 0) {
            cart.removeItem(stored);
            if (mounted) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  content: Text(
                      '${freshProduct.name} is not available and was removed from your cart'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
            }
            continue;
          }

          int newQty = entryNow.quantity;
          bool qtyClamped = false;
          if (newQty > freshProduct.quantity) {
            newQty = freshProduct.quantity;
            qtyClamped = true;
          }

          final changed = stored.price != freshProduct.price ||
              stored.originalPrice != freshProduct.originalPrice ||
              stored.quantity != freshProduct.quantity ||
              qtyClamped;

          if (changed) {
            cart.setQuantity(freshProduct, newQty);
            if (qtyClamped && mounted) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(const SnackBar(
                  content: Text('Stock Limit Reached'),
                  duration: Duration(seconds: 3),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
            }
          }
        }
      }
    } catch (_) {}
  }

  void _recalculateTotals(double cartTotal) {
    final bool qualifiesForFreeDelivery = _deliveryOrderValue > 0 &&
        cartTotal >= _deliveryOrderValue;
    final fee = qualifiesForFreeDelivery ? 0.0 : _storeDeliveryFee;
    setState(() {
      _deliveryFee = fee;
      _finalTotal = cartTotal + fee;
    });
  }

  Future<void> _fetchMinOrderValue() async {
    try {
      final result = await ProfileGetApiService.getProfile();
      if (result['success'] == true) {
        final rawData = result['data'];
        Map<String, dynamic>? data;
        if (rawData is List && rawData.isNotEmpty) {
          data = Map<String, dynamic>.from(rawData.first as Map);
        } else if (rawData is Map) {
          data = Map<String, dynamic>.from(rawData);
        }
        if (data == null) return;

        final minStr          = data['min_order_value']?.toString() ?? '0';
        final feeStr          = data['delivery_fee']?.toString() ?? '0';
        final deliveryOrderStr = data['delivery_order_value']?.toString() ?? '0';

        final freshMinOrder      = double.tryParse(minStr) ?? 0;
        final freshDeliveryFee   = double.tryParse(feeStr) ?? 0;
        final freshDeliveryOrder = double.tryParse(deliveryOrderStr) ?? 0;

        StoreProfileCache.minOrderValue      = freshMinOrder;
        StoreProfileCache.deliveryFee        = freshDeliveryFee;
        StoreProfileCache.deliveryOrderValue = freshDeliveryOrder;
        StoreProfileCache.hasLoaded          = true;

        if (mounted) {
          setState(() {
            _minOrderValue      = freshMinOrder;
            _storeDeliveryFee   = freshDeliveryFee;
            _deliveryOrderValue = freshDeliveryOrder;
          });
          final cart = Provider.of<CartModel>(context, listen: false);
          _recalculateTotals(cart.totalPrice);
        }
      }
    } catch (_) {}
  }
  void _showClearCartDialog(BuildContext context, CartModel cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear Cart',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.buttonPrimary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('No',
                style: TextStyle(color: AppColors.buttonPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Yes, Clear',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goToHome(BuildContext context) {
    if (widget.onGoToHome != null) {
      widget.onGoToHome!();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _handleProceed(
      BuildContext context, double totalPrice) async {
    if (_minOrderValue > 0 && totalPrice < _minOrderValue) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.buttonPrimary),
              SizedBox(width: 8),
              Text('Minimum Order',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Your order total is ₹${totalPrice.toStringAsFixed(0)}, but the minimum order value is ₹${_minOrderValue.toStringAsFixed(0)}.\n\nPlease add more items to proceed.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK',
                  style: TextStyle(color: AppColors.buttonPrimaryText)),
            ),
          ],
        ),
      );
      return;
    }

    final token =
        await SessionManager.getString('token') ?? widget.token;
    final customerId =
        await SessionManager.getString('customer_id') ?? widget.customerId;

    if (token.isEmpty) return;

    _recalculateTotals(totalPrice);

    final deliveryFee = _deliveryFee;
    final finalTotal = _finalTotal;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddressSelectionScreen(
          token: token,
          customerId: customerId,
          // deliveryFee: deliveryFee,
          // finalTotal: finalTotal,
        ),
      ),
    );
    if (widget.onRefresh != null) widget.onRefresh!();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Cart',
          style: TextStyle(
              color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Consumer<CartModel>(
              builder: (context, cart, _) {
                final totalItems = cart.items.values
                    .fold(0, (sum, item) => sum + item.quantity);
                return Center(
                  child: Text(
                    '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                        color: AppColors.primaryBlue, fontSize: 13),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer<CartModel>(
        builder: (context, cart, child) {
          if (_finalTotal != cart.totalPrice + _deliveryFee) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _recalculateTotals(cart.totalPrice);
            });
          }

          // ── Empty state ──────────────────────────────────────────────
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: screenW * 0.35,
                    height: screenW * 0.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:AppColors.floatingCartBg,
                          width: 1.5),
                    ),
                    child: Center(
                      child: Icon(Icons.shopping_cart_outlined,
                          size: screenW * 0.18,
                          color:AppColors.floatingCartBg),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Nothing here yet!',
                      style: TextStyle(
                          fontSize: screenW * 0.05,
                          color: AppColors.buttonPrimary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Your cart is waiting to be filled',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: screenW * 0.035,
                          color: AppColors.textMuted)),
                  SizedBox(height: screenH * 0.03),
                  ElevatedButton(
                    onPressed: () => _goToHome(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: EdgeInsets.symmetric(
                          horizontal: screenW * 0.1,
                          vertical: screenH * 0.015),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Start Shopping',
                        style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: screenW * 0.04,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          // ── Cart list ────────────────────────────────────────────────
          return Column(
            children: [
              // Free delivery banner
              if (_minOrderValue > 0 &&
                  cart.totalPrice >= _minOrderValue &&
                  _deliveryFee == 0 &&
                  _finalTotal > 0)
                Container(
                  width: double.infinity,
                  color: AppColors.success,
                  padding: EdgeInsets.symmetric(
                      vertical: screenH * 0.01,
                      horizontal: screenW * 0.04),
                  child: const Row(
                    children: [
                      Icon(Icons.local_shipping,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Free delivery on this order! 🎉',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),

              // Minimum order progress bar
              if (_minOrderValue > 0 &&
                  cart.totalPrice < _minOrderValue)
                Container(
                  width: double.infinity,
                  color: AppColors.warningLight,
                  padding: EdgeInsets.symmetric(
                      vertical: screenH * 0.012,
                      horizontal: screenW * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined,
                              color: AppColors.buttonPrimary, size: 15),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Add ₹${(_minOrderValue - cart.totalPrice).toStringAsFixed(0)} more to meet minimum order value',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.buttonPrimary,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cart.totalPrice / _minOrderValue)
                              .clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: AppColors.accentLight,
                          valueColor:
                          const AlwaysStoppedAnimation<Color>(
                              AppColors.buttonPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  color: AppColors.loader,
                  onRefresh: _fetchMinOrderValue,
                  child: ListView(
                    padding: EdgeInsets.all(screenW * 0.03),
                    children: [
                      // Cart items card
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                screenW * 0.04,
                                screenH * 0.018,
                                screenW * 0.04,
                                screenH * 0.005),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Items in your cart',
                                    style: TextStyle(
                                        fontSize: screenW * 0.04,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                                GestureDetector(
                                  onTap: () => _showClearCartDialog(context, cart),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: screenW * 0.03,
                                        vertical: screenH * 0.005),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade300, width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Clear All',
                                            style: TextStyle(
                                                fontSize: screenW * 0.032,
                                                color: Colors.red.shade600,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...cart.items.values.toList().map((item) {
                            return Column(
                              children: [
                                Divider(
                                    height: 1,
                                    color: AppColors.divider),
                                Padding(
                                  padding: EdgeInsets.all(
                                      screenW * 0.03),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductDetailScreen(
                                                      product: item.product),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: screenW * 0.16,
                                          height: screenW * 0.16,
                                          decoration: BoxDecoration(
                                            color: AppColors.sidebarBg,
                                            borderRadius:
                                            BorderRadius.circular(
                                                8),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(
                                                8),
                                            child: _safeProductImage(
                                              item.product.image,
                                              item.product.imageUrl,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                          width: screenW * 0.03),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                          children: [
                                            Text(item.product.name,
                                                maxLines: 2,
                                                overflow: TextOverflow
                                                    .ellipsis,
                                                style: TextStyle(
                                                    fontSize:
                                                    screenW *
                                                        0.036,
                                                    fontWeight:
                                                    FontWeight
                                                        .w600,
                                                    color: AppColors
                                                        .textPrimary)),
                                            if (item.product.weight
                                                .isNotEmpty) ...[
                                              SizedBox(
                                                  height:
                                                  screenH * 0.003),
                                              Text(
                                                  item.product.weight,
                                                  style: TextStyle(
                                                      fontSize:
                                                      screenW *
                                                          0.03,
                                                      color: AppColors
                                                          .appBarText)),
                                            ],
                                            if (item.product.id.contains('_piece_') &&
                                                item.product.pieces.isNotEmpty &&
                                                (item.product.pieces.first.minQuantity ?? 0) > 1) ...[
                                              SizedBox(height: screenH * 0.003),
                                              Builder(builder: (_) {
                                                final minQty = item.product.pieces.first.minQuantity;
                                                final totalUnits = minQty * item.quantity;
                                                return Text(
                                                  'Qty: $totalUnits units (${item.quantity} × $minQty)',
                                                  style: TextStyle(
                                                      fontSize: screenW * 0.028,
                                                      color: AppColors.primaryOrange,
                                                      fontWeight: FontWeight.w500),
                                                );
                                              }),
                                            ],
                                            SizedBox(
                                                height:
                                                screenH * 0.006),
                                            Row(
                                              children: [
                                                Text(
                                                  '₹${item.product.price.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                      fontSize:
                                                      screenW *
                                                          0.038,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                      color: AppColors
                                                          .priceGreen),
                                                ),
                                                if (item.product
                                                    .originalPrice >
                                                    item.product
                                                        .price) ...[
                                                  SizedBox(
                                                      width: screenW *
                                                          0.015),
                                                  Text(
                                                    '₹${item.product.originalPrice.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                        fontSize:
                                                        screenW *
                                                            0.03,
                                                        color: AppColors
                                                            .strikethrough,
                                                        decoration:
                                                        TextDecoration
                                                            .lineThrough),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(
                                                height:
                                                screenH * 0.004),
                                            Row(
                                              children: [
                                                Icon(
                                                    Icons.info_outline,
                                                    size: 11,
                                                    color: AppColors
                                                        .appBarText),
                                                const SizedBox(
                                                    width: 3),
                                                Text(
                                                    'Tap image to view details',
                                                    style: TextStyle(
                                                        fontSize:
                                                        screenW *
                                                            0.028,
                                                        color: AppColors
                                                            .appBarText)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Delete button on top
                                          GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16)),
                                                  content: const Text(
                                                    'Are you sure you want to remove this item?',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  actionsAlignment: MainAxisAlignment.spaceEvenly,
                                                  actions: [
                                                    OutlinedButton(
                                                      style: OutlinedButton.styleFrom(
                                                        side: BorderSide(color: Colors.grey.shade400),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8)),
                                                      ),
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('Cancel',
                                                          style: TextStyle(color: Colors.black87)),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8)),
                                                      ),
                                                      onPressed: () {
                                                        cart.removeItem(item.product);
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text('OK',
                                                          style: TextStyle(color: Colors.white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(screenW * 0.018),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.red.shade200),
                                              ),
                                              child: Icon(Icons.delete_outline,
                                                  color: Colors.red.shade600, size: 18),
                                            ),
                                          ),
                                          SizedBox(height: screenH * 0.008),
                                          // Quantity control below
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {},
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  color: AppColors.freshGreen,
                                                  borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    onTap: () => cart.decrementQuantity(item.product.id),
                                                    child: Padding(
                                                      padding: EdgeInsets.symmetric(
                                                          horizontal: screenW * 0.02,
                                                          vertical: screenH * 0.008),
                                                      child: const Icon(Icons.remove,
                                                          color: AppColors.textLight, size: 18),
                                                    ),
                                                  ),
                                                  Text('${item.quantity}',
                                                      style: TextStyle(
                                                          color: AppColors.textLight,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: screenW * 0.04)),
                                                  InkWell(
                                                    onTap: () {
                                                      final stock = item.product.quantity > 0
                                                          ? item.product.quantity
                                                          : item.product.posQuantity;
                                                      if (stock > 0 && item.quantity >= stock) {
                                                        ScaffoldMessenger.of(context)
                                                          ..clearSnackBars()
                                                          ..showSnackBar(const SnackBar(
                                                            content: Text('Stock Limit Reached'),
                                                            duration: Duration(seconds: 2),
                                                            backgroundColor: AppColors.error,
                                                            behavior: SnackBarBehavior.floating,
                                                          ));
                                                        return;
                                                      }
                                                      cart.addItem(item.product);
                                                    },
                                                    child: Padding(
                                                      padding: EdgeInsets.symmetric(
                                                          horizontal: screenW * 0.02,
                                                          vertical: screenH * 0.008),
                                                      child: const Icon(Icons.add,
                                                          color: AppColors.textLight, size: 18),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),

                      SizedBox(height: screenH * 0.015),

                      // Bill details
                      Container(
                        decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.all(screenW * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bill Details',
                                style: TextStyle(
                                    fontSize: screenW * 0.04,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            SizedBox(height: screenH * 0.015),
                            _BillRow(
                                label: 'Items total',
                                value:
                                '₹${cart.totalPrice.toStringAsFixed(0)}'),
                            // _BillRow(
                            //     label: 'Delivery fee',
                            //     value:
                            //     '₹${_deliveryFee.toStringAsFixed(0)}',
                            //     valueColor: _deliveryFee == 0
                            //         ? AppColors.priceGreen
                            //         : null),
                            // const _BillRow(
                            //     label: 'Handling fee',
                            //     value: '₹0',
                            //     valueColor: AppColors.priceGreen),
                            Divider(
                                color: AppColors.divider, height: 20),
                            _BillRow(
                                label: 'Grand Total',
                                value:
                                '₹${_finalTotal.toStringAsFixed(0)}',
                                isBold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Checkout bar
              Container(
                padding: EdgeInsets.fromLTRB(
                    screenW * 0.04,
                    screenH * 0.015,
                    screenW * 0.04,
                    MediaQuery.of(context).padding.bottom +
                        screenH * 0.015),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2))
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${_finalTotal.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: screenW * 0.05,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary),
                        ),
                        Text('Total bill',
                            style: TextStyle(
                                fontSize: screenW * 0.03,
                                color: AppColors.textMuted)),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () =>
                          _handleProceed(context, cart.totalPrice),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: EdgeInsets.symmetric(
                            horizontal: screenW * 0.08,
                            vertical: screenH * 0.018),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('PROCEED',
                          style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: screenW * 0.042,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _BillRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: screenW * 0.035,
                  color: isBold
                      ? AppColors.textPrimary
                      : AppColors.appBarText,
                  fontWeight: isBold
                      ? FontWeight.bold
                      : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: screenW * 0.035,
                  fontWeight:
                  isBold ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ??
                      (isBold
                          ? AppColors.textPrimary
                          : AppColors.textPrimary))),
        ],
      ),
    );
  }
}