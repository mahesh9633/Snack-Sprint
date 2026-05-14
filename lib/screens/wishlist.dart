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
      backgroundColor: AppColors.white,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 0),
        child: FloatingCartBar(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.appBarIcon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Wishlist',
          style: TextStyle(
              color: AppColors.appBarText, fontWeight: FontWeight.bold, fontSize: 18),
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
                color: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'} saved',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                ),
              ),

              // ── list ────────────────────────────────────────────────────────
              Expanded(
                child: RefreshableScreen(
                  onRefresh: () async {},// call your existing reload/fetch
                  color: AppColors.textAccent,
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
            child: Icon(Icons.favorite_border, size: 56, color:Colors.pink),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your wishlist is empty',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.buttonPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap ♡ on any product to save it here.\nYour items stay saved even after logout.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Browse Products',
              style: TextStyle(
                  color: Colors.white,
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
                          : Container(color: const Color(0xFFF0E9DC)),
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
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(
                            color: Colors.white,
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
                          color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showWeight) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.weight,
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                              color: AppColors.priceGreen),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
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
                                        color: Colors.red,
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
                          color: Colors.red.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite,
                            color: Colors.red, size: 18),
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
                          child: Text('Out of\nStock',
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
                        hasItems ? AppColors.priceGreen : AppColors.buttonPrimary;

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
                              color: Colors.white,
                              border: Border.all(color: accent, width: 1.2),
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

                      // ── No pieces, qty == 0 → plain ADD ────────────────
                      final int qty = cart.getQuantity(product);
                      if (qty == 0) {
                        return GestureDetector(
                          onTap: () => cart.addItem(product),
                          child: Container(
                            width: 90,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: AppColors.buttonPrimary, width: 1.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('ADD',
                                style: TextStyle(
                                    color:         AppColors.buttonPrimary,
                                    fontSize:      12,
                                    fontWeight:    FontWeight.bold,
                                    letterSpacing: 0.5)),
                          ),
                        );
                      }

                      // ── No pieces, qty > 0 → stepper ───────────────────
                      return Container(
                        width: 90,
                        height: 38,
                        decoration: BoxDecoration(
                            color: AppColors.buttonPrimary,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => cart.decrementQuantity(product.id),
                              child: const SizedBox(
                                  width: 22, height: 32,
                                  child: Icon(Icons.remove,
                                      color: Colors.white, size: 14)),
                            ),
                            Text('$qty',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => cart.addItem(product),
                              child: const SizedBox(
                                  width: 22, height: 32,
                                  child: Icon(Icons.add,
                                      color: Colors.white, size: 14)),
                            ),
                          ],
                        ),
                      );
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
    color: AppColors.sidebarBg,
    child: const Center(
      child: Icon(Icons.image_not_supported_outlined,
          color: AppColors.buttonPrimary, size: 32),
    ),
  );
}