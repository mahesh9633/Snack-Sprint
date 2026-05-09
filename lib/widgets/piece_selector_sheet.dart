import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/cart_model.dart';
import '../model/product_model.dart';
import '../services/api_config_service.dart';
import '../widgets/floating_cart.dart';

final String _imgBase = ApiConfig.imageBase;

// ─── Data model for one piece/variant ────────────────────────────────────────
class ProductPiece {
  final String pieceId;
  final String label;
  final double price;
  final double specialPrice;
  final String image;

  const ProductPiece({
    required this.pieceId,
    required this.label,
    required this.price,
    required this.specialPrice,
    this.image = '',
  });

  factory ProductPiece.fromJson(Map<String, dynamic> j) {
    final price   = double.tryParse(j['price']?.toString()         ?? '0') ?? 0;
    final special = double.tryParse(j['special_price']?.toString() ?? '0') ?? 0;
    return ProductPiece(
      pieceId:      j['piece_id']?.toString() ?? '',
      label:        j['piece']?.toString()    ?? '',
      price:        price,
      specialPrice: special,
      image:        j['image']?.toString()    ?? '',
    );
  }

  double get effectivePrice => (specialPrice > 0 && specialPrice < price) ? specialPrice : price;
  bool   get hasDiscount    => specialPrice > 0 && specialPrice < price;
  int    get discountPct    => hasDiscount ? ((price - specialPrice) / price * 100).round() : 0;

  String cartId(String baseProductId) => '${baseProductId}_piece_$pieceId';
}

// ─── Public entry-point ───────────────────────────────────────────────────────
void handleAddToCart({
  required BuildContext       context,
  required Product            product,
  required List<ProductPiece> pieces,
}) {
  if (pieces.isEmpty) {
    context.read<CartModel>().addItem(product);
    return;
  }
  if (pieces.length == 1) {
    _addPiece(context, product, pieces.first);
    return;
  }
  showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder:            (_) => _PieceSelectorSheet(product: product, pieces: pieces),
  );
}

void _addPiece(BuildContext context, Product base, ProductPiece piece) {
  final pieceProduct = Product(
    id:                 piece.cartId(base.id),
    name:               '${base.name} – ${piece.label}',
    price:              piece.effectivePrice,
    originalPrice:      piece.hasDiscount ? piece.price : piece.effectivePrice,
    image:              base.image,
    imageUrl:           base.imageUrl,
    category:           base.category,
    weight:             piece.label,
    sku:                base.sku,
    discountPercentage: piece.discountPct.toDouble(),
    quantity:           base.quantity,
    posQuantity:        base.posQuantity,
  );
  context.read<CartModel>().addItem(pieceProduct);
}

// ─── Bottom sheet widget ──────────────────────────────────────────────────────
class _PieceSelectorSheet extends StatelessWidget {
  final Product            product;
  final List<ProductPiece> pieces;

  const _PieceSelectorSheet({required this.product, required this.pieces});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize:     0.52,
      maxChildSize:     0.52,
      expand:           false,
      snap:             false,
      builder: (_, scrollCtrl) => Stack(
        children: [
          // ── Main sheet container ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // ── Drag handle (fixed) ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color:        Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header (fixed, never scrolls) ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close,
                          size: 22, color: Colors.black54),
                    ),
                  ]),
                ),

                const Divider(height: 1),

                // ── Piece list (only this part scrolls) ─────────────
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) => true, // block scroll bubbling to sheet
                    child: ListView.separated(
                      controller:       scrollCtrl,
                      padding:          const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount:        pieces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder:      (ctx, i) =>
                          _PieceRow(product: product, piece: pieces[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Floating cart bar pinned at bottom of sheet ────────────
          const Positioned(
            bottom: 10,
            left:   16,
            right:  16,
            child:  FloatingCartBar(),
          ),
        ],
      ),
    );
  }
}

// ─── Single piece row ─────────────────────────────────────────────────────────
class _PieceRow extends StatelessWidget {
  final Product      product;
  final ProductPiece piece;

  const _PieceRow({required this.product, required this.piece});

  String _imageUrl() {
    final img = piece.image.isNotEmpty ? piece.image : product.imageUrl;
    if (img.isEmpty || img == 'no_image.png') return '';
    return img.startsWith('http') ? img : '$_imgBase$img';
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // ── Thumbnail ───────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64, height: 64,
            child: url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imgPlaceholder())
                : _imgPlaceholder(),
          ),
        ),
        const SizedBox(width: 12),

        // ── Label + pricing ──────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(piece.label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Text('₹${piece.effectivePrice.toInt()}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                if (piece.hasDiscount) ...[
                  const SizedBox(width: 6),
                  Text('₹${piece.price.toInt()}',
                      style: TextStyle(
                          fontSize:   12,
                          color:      Colors.grey[500],
                          decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color:        const Color(0xFF388E3C),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('${piece.discountPct}% off',
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   9,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ],
          ),
        ),

        // ── ADD / stepper ────────────────────────────────────────────
        _PieceCartBtn(product: product, piece: piece),
      ]),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: Colors.grey[100],
    child: const Icon(Icons.image_not_supported,
        color: Colors.grey, size: 28),
  );
}

// ─── ADD / stepper for a single piece ────────────────────────────────────────
class _PieceCartBtn extends StatelessWidget {
  final Product      product;
  final ProductPiece piece;

  const _PieceCartBtn({required this.product, required this.piece});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartModel>(
      builder: (ctx, cart, _) {
        final pieceId    = piece.cartId(product.id);
        final tempProduct = Product(
          id:                 pieceId,
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
        final qty = cart.getQuantity(tempProduct);

        if (qty == 0) {
          return GestureDetector(
            onTap: () => _addPiece(ctx, product, piece),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFF0080), width: 1.5),
              ),
              child: const Text('ADD',
                  style: TextStyle(
                      color:         Color(0xFFFF0080),
                      fontSize:      13,
                      fontWeight:    FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          );
        }

        return Container(
          height: 36,
          decoration: BoxDecoration(
              color:        const Color(0xFFFF0080),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => cart.decrementQuantity(pieceId),
              child: const SizedBox(
                  width: 34, height: 36,
                  child: Icon(Icons.remove,
                      color: Colors.white, size: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('$qty',
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   14,
                      fontWeight: FontWeight.bold)),
            ),
            GestureDetector(
              onTap: () => _addPiece(ctx, product, piece),
              child: const SizedBox(
                  width: 34, height: 36,
                  child: Icon(Icons.add,
                      color: Colors.white, size: 16)),
            ),
          ]),
        );
      },
    );
  }
}