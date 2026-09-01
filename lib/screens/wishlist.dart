import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/favorites_model.dart';
import '../model/cart_model.dart';
import '../model/product_model.dart';
import '../services/api_config_service.dart';
import '../products/product_detail_screen.dart';
import '../widgets/floating_cart.dart';
import '../widgets/piece_selector_sheet.dart';
import '../widgets/refreshable_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 0),
        child: FloatingCartBar(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Wishlist',
          style: TextStyle(
              color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Consumer<FavoritesModel>(
        builder: (context, favModel, _) {
          final items = favModel.favoriteList;

          if (items.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // ── count bar ───────────────────────────────────────────────────
              Container(
                width: double.infinity,
                color: AppColors.cardWhite,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'} saved',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500),
                ),
              ),

              // ── list ────────────────────────────────────────────────────────
              Expanded(
                child: RefreshableScreen(
                  onRefresh: () async {},// call your existing reload/fetch
                  color: AppColors.primaryBlue,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _WishlistCard(product: items[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border, size: 56, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your wishlist is empty',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap ♡ on any product to save it here.\nYour items stay saved even after logout.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textDark),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Browse Products',
              style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual card ──────────────────────────────────────────────────────────

class _WishlistCard extends StatelessWidget {
  final Product product;
  const _WishlistCard({required this.product});

  // ── Safe image URL builder ─────────────────────────────────────────────────
  String _buildUrl(String raw) {
    if (raw.isEmpty || raw == 'no_image.png') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiConfig.imageBase}$raw';
  }

  @override
  Widget build(BuildContext context) {
    final favModel = context.read<FavoritesModel>();

    // Resolve image URL safely
    String imageUrl = _buildUrl(product.imageUrl);
    if (imageUrl.isEmpty) imageUrl = _buildUrl(product.image);

    final bool hasDiscount = product.discountPercentage > 0 &&
        product.originalPrice > product.price;

    // Hide weight if it's a raw float like "0.00000000" or "0"
    final bool showWeight = product.weight.isNotEmpty &&
        product.weight != '0.00000000' &&
        product.weight != '0';

    return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Product image ────────────────────────────────────────────────
            GestureDetector(
            onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    ),
    child: Stack(
    children: [
    ClipRRect(
                  borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: SizedBox(
                    width: 105,
                    height: 110,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) =>
                      prog == null
                          ? child
                          : Container(color: AppColors.sidebarBg),
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                        : _placeholder(),
                  ),
                ),
                // Discount badge
                if (hasDiscount)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.freshGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                          style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Details ──────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showWeight) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.weight,
                        style:
                        const TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.freshGreen),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.originalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(
                          'Tap to view details',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Action buttons ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  // Remove from wishlist
                  Tooltip(
                    message: 'Remove from wishlist',
                    child: GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            title: const Text('Remove item?',
                                style:
                                TextStyle(fontWeight: FontWeight.bold)),
                            content: Text(
                                'Remove "${product.name}" from your wishlist?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color: Colors.grey[600])),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Remove',
                                    style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await favModel.removeById(product.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite,
                            color: AppColors.error, size: 18),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Consumer<CartModel>(
                    builder: (context, cart, _) {
                      if (!product.isInStock) {
                        return Container(
                          width: 90,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Not\nAvailable',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600)),
                        );
                      }

                      // ── Pieces product ──────────────────────────────────
                      if (product.pieces.isNotEmpty) {
                        int totalQty = 0;
                        double totalAmt = 0;

                        for (final piece in product.pieces) {
                          final pieceProduct = Product(
                            id:                 piece.cartId(product.id),
                            name:               '${product.name} – ${piece.label}',
                            price:              piece.effectivePrice,
                            originalPrice:      piece.hasDiscount ? piece.price : piece.effectivePrice,
                            image:              product.image,
                            imageUrl:           product.imageUrl,
                            category:           product.category,
                            weight:             piece.label,
                            sku:                product.sku,
                            discountPercentage: piece.discountPct.toDouble(),
                            quantity:           product.quantity,
                            posQuantity:        product.posQuantity,
                          );
                          final q = cart.getQuantity(pieceProduct);
                          totalQty += q;
                          totalAmt += q * piece.effectivePrice;
                        }

                        final hasItems = totalQty > 0;
                        final Color accent =
                        hasItems ? AppColors.freshGreen : AppColors.primaryBlue;
                        final Color accentBorder =
                        hasItems ? AppColors.freshGreen : AppColors.border;

                        return GestureDetector(
                          onTap: () => handleAddToCart(
                            context: context,
                            product: product,
                            pieces:  product.pieces,
                          ),
                          child: Container(
                            width: 90,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              border: Border.all(color: accentBorder, width: 1.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: hasItems
                                ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'ADD (${product.pieces.length} opp)',
                                  style: TextStyle(
                                      color:         accent,
                                      fontSize:      11,
                                      fontWeight:    FontWeight.bold,
                                      letterSpacing: 0.5),
                                ),
                                Text(
                                  '₹${totalAmt.toInt()}',
                                  style: TextStyle(
                                      color:      accent,
                                      fontSize:   9,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('ADD',
                                    style: TextStyle(
                                        color:         accent,
                                        fontSize:      11,
                                        fontWeight:    FontWeight.bold,
                                        letterSpacing: 0.5)),
                                Text(
                                  product.pieces.length == 1
                                      ? '1 option'
                                      : '${product.pieces.length} options',
                                  style: TextStyle(
                                      color:   accent,
                                      fontSize: 8),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final int qty = cart.getQuantity(product);
                      if (qty == 0) {
                        return GestureDetector(
                          onTap: () => cart.addItem(product),
                          child: Container(
                            width: 90,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              border: Border.all(
                                  color: AppColors.border, width: 1.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('ADD',
                                style: TextStyle(
                                    color:         AppColors.freshGreen,
                                    fontSize:      12,
                                    fontWeight:    FontWeight.bold,
                                    letterSpacing: 0.5)),
                          ),
                        );
                      }

                      // ── No pieces, qty > 0 → stepper ───────────────────
                      // ── No pieces, qty > 0 → handled by _WishlistCartBtn ──
                      return _WishlistCartBtn(product: product);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.cardWhite,
    child: const Center(
      child: Icon(Icons.image_not_supported_outlined,
          color: AppColors.primaryBlue, size: 32),
    ),
  );
}
  class _WishlistCartBtn extends StatefulWidget {
  final Product product;
  const _WishlistCartBtn({required this.product});

  @override
  State<_WishlistCartBtn> createState() => _WishlistCartBtnState();
  }

  class _WishlistCartBtnState extends State<_WishlistCartBtn> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
  super.initState();
  _ctrl  = TextEditingController();
  _focus = FocusNode();
  }

  @override
  void dispose() {
  _ctrl.dispose();
  _focus.dispose();
  super.dispose();
  }

  void _startEditing(int currentQty) {
  _ctrl.text = '$currentQty';
  _focus.requestFocus();
  setState(() => _editing = true);
  WidgetsBinding.instance.addPostFrameCallback((_) {
  _ctrl.selection = TextSelection(
  baseOffset:   0,
  extentOffset: _ctrl.text.length,
  );
  });
  }

  void _commitEdit(CartModel cart) {
  final val   = int.tryParse(_ctrl.text.trim()) ?? 0;
  final stock = widget.product.quantity > 0
  ? widget.product.quantity
      : widget.product.posQuantity;
  if (val <= 0) {
  cart.removeItem(widget.product);
  } else if (stock > 0 && val > stock) {
  cart.setQuantity(widget.product, stock);
  showDialog(
  context: context,
  barrierColor: Colors.black26,
  builder: (_) => Center(
  child: Container(
  margin: const EdgeInsets.symmetric(horizontal: 40),
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
  decoration: BoxDecoration(
  color: AppColors.cardWhite,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)],
  ),
  child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
  const Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 36),
  const SizedBox(height: 12),
   const Text(
  'Stock Limit Reached',
  textAlign: TextAlign.center,
  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
  ),
  const SizedBox(height: 16),
  GestureDetector(
  onTap: () => Navigator.pop(context),
  child: Container(
  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
  decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(8)),
  child: const Text('OK', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
  ),
  ),
  ],
  ),
  ),
  ),
  );
  } else {
  cart.setQuantity(widget.product, val);
  }
  setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
  final product = widget.product;

  if (!product.isInStock) {
  return Container(
  width: 90, height: 38,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
  child: Text('Not\nAvailable',
  textAlign: TextAlign.center,
  style: TextStyle(color: Colors.grey[500], fontSize: 9, fontWeight: FontWeight.w600)),
  );
  }

  if (product.pieces.isNotEmpty) {
  return Consumer<CartModel>(
  builder: (context, cart, _) {
  int totalQty = 0;
  double totalAmt = 0;
  for (final piece in product.pieces) {
  final pieceProduct = Product(
  id: piece.cartId(product.id), name: '${product.name} – ${piece.label}',
  price: piece.effectivePrice, originalPrice: piece.hasDiscount ? piece.price : piece.effectivePrice,
  image: product.image, imageUrl: product.imageUrl, category: product.category,
  weight: piece.label, sku: product.sku, discountPercentage: piece.discountPct.toDouble(),
  quantity: product.quantity, posQuantity: product.posQuantity,
  );
  final q = cart.getQuantity(pieceProduct);
  totalQty += q;
  totalAmt += q * piece.effectivePrice;
  }
  final hasItems = totalQty > 0;
  final Color accent = hasItems ? AppColors.freshGreen : AppColors.primaryBlue;
  return GestureDetector(
  onTap: () => handleAddToCart(context: context, product: product, pieces: product.pieces),
  child: Container(
  width: 90, height: 40,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: AppColors.cardWhite, border: Border.all(color: accent, width: 1.2), borderRadius: BorderRadius.circular(8)),
  child: hasItems
  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Text('ADD (${product.pieces.length} opp)',
  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  Text('₹${totalAmt.toInt()}', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w700)),
  ])
      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Text('ADD', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  Text(product.pieces.length == 1 ? '1 option' : '${product.pieces.length} options',
  style: TextStyle(color: accent, fontSize: 8)),
  ]),
  ),
  );
  },
  );
  }

  return Consumer<CartModel>(
  builder: (context, cart, _) {
  final qty = cart.getQuantity(product);
  if (qty == 0) {
  return GestureDetector(
  onTap: () => cart.addItem(product),
  child: Container(
  width: 90, height: 40,
  alignment: Alignment.center,
  decoration: BoxDecoration(
  color: AppColors.cardWhite,
    border: Border.all(color: AppColors.border, width: 1.2),
  borderRadius: BorderRadius.circular(8),
  ),
  child: const Text('ADD',
  style: TextStyle(color: AppColors.freshGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  ),
  );
  }
  final liveQty   = _editing ? (int.tryParse(_ctrl.text) ?? qty) : qty;
  final liveTotal = (liveQty * product.price).toInt();
  return Column(
  mainAxisSize: MainAxisSize.min,
  children: [
  Container(
  width: 90, height: 38,
  decoration: BoxDecoration(color: AppColors.freshGreen, borderRadius: BorderRadius.circular(8)),
  child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
  GestureDetector(
  onTap: () => cart.decrementQuantity(product.id),
  child: const SizedBox(width: 22, height: 32, child: Icon(Icons.remove, color: AppColors.textLight, size: 14)),
  ),
  if (_editing)
  SizedBox(
  width: 36,
  child: TextField(
  controller:   _ctrl,
  focusNode:    _focus,
  keyboardType: TextInputType.number,
  textAlign:    TextAlign.center,
  style: const TextStyle(color: AppColors.textLight, fontSize: 11, fontWeight: FontWeight.bold),
  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
  onChanged:    (_) => setState(() {}),
  onSubmitted:  (_) => _commitEdit(cart),
  onTapOutside: (_) => _commitEdit(cart),
  ),
  )
  else
  GestureDetector(
  onTapDown: (_) => _startEditing(qty),
  child: Text('$qty', style: const TextStyle(color: AppColors.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
  ),
  GestureDetector(
  onTap: () {
  final stock = product.quantity > 0 ? product.quantity : product.posQuantity;
  if (stock > 0 && qty >= stock) {
  showDialog(
  context: context,
  barrierColor: Colors.black26,
  builder: (_) => Center(
  child: Container(
  margin: const EdgeInsets.symmetric(horizontal: 40),
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
  decoration: BoxDecoration(
  color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16),
  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)],
  ),
  child: Column(mainAxisSize: MainAxisSize.min, children: [
  const Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 36),
  const SizedBox(height: 12),
  const Text('Stock Limit Reached',
  textAlign: TextAlign.center,
  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
  const SizedBox(height: 16),
  GestureDetector(
  onTap: () => Navigator.pop(context),
  child: Container(
  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
  decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(8)),
  child: const Text('OK', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
  ),
  ),
  ]),
  ),
  ),
  );
  return;
  }
  cart.addItem(product);
  },
  child: const SizedBox(width: 22, height: 32, child: Icon(Icons.add, color: AppColors.textLight, size: 14)),
  ),
  ],
  ),
  ),
  const SizedBox(height: 3),
  Text('₹$liveTotal', style: const TextStyle(color: AppColors.freshGreen, fontSize: 10, fontWeight: FontWeight.bold)),
  ],
  );
  },
  );
  }
  }