import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/cart_model.dart';
import '../model/product_model.dart';
import '../products/product_detail_screen.dart';
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
  final int    minQuantity;   // <-- new
  final bool   isCombo;       // <-- new
  final int    stock;         // piece-level stock

  const ProductPiece({
    required this.pieceId,
    required this.label,
    required this.price,
    required this.specialPrice,
    this.image       = '',
    this.minQuantity = 0,
    this.isCombo     = false,
    this.stock       = 0,
  });

  factory ProductPiece.fromJson(Map<String, dynamic> j) {
    final price      = double.tryParse(j['price']?.toString()         ?? '0') ?? 0;
    final special    = double.tryParse(j['special_price']?.toString() ?? '0') ?? 0;
    final pieceName  = j['piece']?.toString() ?? '';
    final minQtyInt  = int.tryParse(j['min_quantity']?.toString() ?? '0') ?? 0;
    final isCombo    = (j['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes';
    final stockInt   = int.tryParse(j['pos_quantity']?.toString() ?? '0') ?? 0;
    final label      = (minQtyInt > 1 && pieceName.isNotEmpty)
        ? '$pieceName × $minQtyInt'
        : pieceName;
    return ProductPiece(
      pieceId:      j['id']?.toString() ?? '',
      label:        label,
      price:        price,
      specialPrice: special,
      image:        j['image']?.toString() ?? '',
      minQuantity:  minQtyInt,
      isCombo:      isCombo,
      stock:        stockInt,
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
    originalPrice:      piece.hasDiscount? piece.price : piece.effectivePrice,
    image:              base.image,
    imageUrl:           base.imageUrl,
    category:           base.category,
    weight:             piece.label,
    sku:                base.sku,
    discountPercentage: piece.discountPct.toDouble(),
    quantity:           base.quantity,
    posQuantity:        base.posQuantity,
    isCombo:            piece.isCombo,
    pieces:             [piece],
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
      initialChildSize: 0.75,
      minChildSize:     0.50,
      maxChildSize:     0.92,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close,
                              size: 22, color: Colors.black54),
                        ),
                      ]),
                      if (product.isCombo || pieces.any((p) => p.isCombo)) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.card_giftcard,
                                  size: 13, color: Color(0xFFFF6B00)),
                              SizedBox(width: 4),
                              Text('Combo Deal',
                                  style: TextStyle(
                                      color: Color(0xFFFF6B00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Scrollable piece list ───────────────────────────
                Expanded(
                  child: ListView.separated(
                    controller:  scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount:   pieces.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _PieceRow(product: product, piece: pieces[i]),
                  ),
                ),
              ],
            ),
          ),

          // ── Floating cart bar pinned at bottom of sheet ────────────
          const Positioned(
            bottom: 16,
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
    // Prefer the piece's own image; fall back to the product image
    final pieceImg = piece.image;
    final img = (pieceImg.isNotEmpty && pieceImg != 'no_image.png')
        ? pieceImg
        : product.imageUrl;
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
        border: Border.all(
          color: piece.isCombo
              ? const Color(0xFFFF6B00).withOpacity(0.5)
              : Colors.grey[200]!,
          width: piece.isCombo ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // ── Thumbnail ───────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            final pieceProduct = Product(
              id:           piece.cartId(product.id),
              name:         '${product.name} – ${piece.label}',
              price:        piece.effectivePrice,
              originalPrice: piece.hasDiscount ? piece.price : piece.effectivePrice,
              image:        piece.image.isNotEmpty ? piece.image : product.image,
              imageUrl:     url,
              category:     product.category,
              weight:       piece.label,
              sku:          product.sku,
              discountPercentage: piece.discountPct.toDouble(),
              quantity:     piece.stock > 0 ? piece.stock : product.quantity,
              posQuantity:  product.posQuantity,
              isCombo:      piece.isCombo,
              pieces:       [piece],
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: pieceProduct),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64, height: 64,
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgPlaceholder())
                  : _imgPlaceholder(),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ── Label + pricing ──────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(piece.label,
              //     style: const TextStyle(
              //         fontSize: 14, fontWeight: FontWeight.w600)),
              // const SizedBox(height: 4),
              // Column(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   children: [
              //     if (piece.hasDiscount)
              //       Container(
              //         margin: const EdgeInsets.only(bottom: 4),
              //         padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              //         decoration: BoxDecoration(
              //             color:        const Color(0xFF388E3C),
              //             borderRadius: BorderRadius.circular(4)),
              //         child: Text('${piece.discountPct}% off',
              //             style: const TextStyle(
              //                 color:      Colors.white,
              //                 fontSize:   9,
              //                 fontWeight: FontWeight.bold)),
              //       ),
              //     Row(children: [
              //       Text('₹${piece.effectivePrice.toInt()}',
              //           style: const TextStyle(
              //               fontSize: 15, fontWeight: FontWeight.bold)),
              //       if (piece.hasDiscount) ...[
              //         const SizedBox(width: 6),
              //         Text('₹${piece.price.toInt()}',
              //             style: TextStyle(
              //                 fontSize:   12,
              //                 color:      Colors.grey[500],
              //                 decoration: TextDecoration.lineThrough)),
              //       ],
              //     ]),
              //   ],
              // ),
              if (piece.hasDiscount)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color:        const Color(0xFF388E3C),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('${piece.discountPct}% off',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   9,
                          fontWeight: FontWeight.bold)),
                ),
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
// class _PieceCartBtn extends StatelessWidget {
//   final Product      product;
//   final ProductPiece piece;
//
//   const _PieceCartBtn({required this.product, required this.piece});
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<CartModel>(
class _PieceCartBtn extends StatefulWidget {
  final Product      product;
  final ProductPiece piece;

  const _PieceCartBtn({required this.product, required this.piece});

  @override
  State<_PieceCartBtn> createState() => _PieceCartBtnState();
}

class _PieceCartBtnState extends State<_PieceCartBtn> {
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

  // void _startEditing(int currentQty) {
  //   _ctrl.text = '$currentQty';
  //   setState(() => _editing = true);
  //   Future.microtask(() {
  //     _focus.requestFocus();
  //     _ctrl.selectAll();
  //   });
  // }
  // void _startEditing(int currentQty) {
  //   _ctrl.text = '$currentQty';
  //   setState(() => _editing = true);
  //   Future.microtask(() {
  //     _focus.requestFocus();
  //     _ctrl.selection = TextSelection(
  //       baseOffset:  0,
  //       extentOffset: _ctrl.text.length,
  //     );
  //   });
  // }
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
  void _commitEdit(CartModel cart, Product tempProduct, int effectiveStock) {
    final val = int.tryParse(_ctrl.text.trim()) ?? 0;
    final stock = effectiveStock;

    if (val <= 0) {
      cart.removeItem(tempProduct);
    } else if (stock > 0 && val > stock) {
      cart.setQuantity(tempProduct, stock);
      showDialog(
        context: context,
        barrierColor: Colors.black26,
        builder: (_) => Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFF0080), size: 36),
                const SizedBox(height: 12),
                Text(
                  'Only $stock item${stock == 1 ? '' : 's'} available',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0080),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('OK',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      cart.setQuantity(tempProduct, val);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartModel>(

      builder: (ctx, cart, _) {;
      final pieceId    = widget.piece.cartId(widget.product.id);
      final pieceStock = widget.piece.stock;

      // ── For combo: compute shared remaining stock ──────────────────
      final bool isComboProduct = widget.product.isCombo ||
          widget.product.pieces.any((p) => p.isCombo);
      int effectiveStock = pieceStock;
      if (isComboProduct && pieceStock > 0) {
        int otherPiecesQty = 0;
        for (final otherPiece in widget.product.pieces) {
          if (otherPiece.pieceId == widget.piece.pieceId) continue;
          final otherId = otherPiece.cartId(widget.product.id);
          final otherTemp = Product(
            id: otherId, name: '', price: 0, originalPrice: 0,
            category: '', quantity: 0, posQuantity: 0,
          );
          otherPiecesQty += cart.getQuantity(otherTemp);
        }
        effectiveStock = (pieceStock - otherPiecesQty).clamp(0, pieceStock);
      }

      final tempProduct = Product(
        id:                 pieceId,
        name:               '${widget.product.name} – ${widget.piece.label}',
        price:              widget.piece.effectivePrice,
        originalPrice:      widget.piece.hasDiscount ? widget.piece.price : widget.piece.effectivePrice,
        image:              widget.product.image,
        imageUrl:           widget.product.imageUrl,
        category:           widget.product.category,
        weight:             widget.piece.label,
        sku:                widget.product.sku,
        discountPercentage: widget.piece.discountPct.toDouble(),
        quantity:           effectiveStock,
        posQuantity:        effectiveStock,
        isCombo:            widget.piece.isCombo,
        pieces:             [widget.piece],
      );
      final qty = cart.getQuantity(tempProduct);

      if (qty == 0) {
        final isOutOfStock = effectiveStock == 0;
        return GestureDetector(
          onTap: isOutOfStock ? null : () => _addPiece(ctx, widget.product, widget.piece),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color:        isOutOfStock ? Colors.grey[100] : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isOutOfStock ? Colors.grey[300]! : Colors.grey[300]!, width: 1.5),
            ),
            child: Text(
                isOutOfStock ? 'Out of Stock' : 'ADD',
                style: TextStyle(
                    color:         isOutOfStock ? Colors.red : const Color(0xFFFF0080),
                    fontSize:      13,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 0.5)),
          ),
        );
      }

      // Live price: updates as user types, before committing
      final liveQty   = _editing
          ? (int.tryParse(_ctrl.text) ?? qty)
          : qty;
      final liveTotal = (liveQty * widget.piece.effectivePrice).toInt();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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

              // ── Tappable qty / inline editor ──────────────────
              if (_editing)
                SizedBox(
                  width: 42,
                  child: TextField(
                    controller:   _ctrl,
                    focusNode:    _focus,
                    keyboardType: TextInputType.number,
                    textAlign:    TextAlign.center,
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   14,
                        fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                        border:      InputBorder.none,
                        isDense:     true,
                        contentPadding: EdgeInsets.zero),
                    onChanged: (_) => setState(() {}), // live price refresh
                    onSubmitted: (_) =>
                        _commitEdit(cart, tempProduct, effectiveStock),
                    onTapOutside: (_) =>
                        _commitEdit(cart, tempProduct, effectiveStock),
                  ),
                )
              else
                GestureDetector(
                  onTapDown: (_) => _startEditing(qty),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('$qty',
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),

              GestureDetector(
                onTap: () {
                  final stock = effectiveStock;
                  if (stock > 0 && qty >= stock) {
                    showDialog(
                      context: ctx,
                      barrierColor: Colors.black26,
                      builder: (_) => Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFFF0080), size: 36),
                              const SizedBox(height: 12),
                              Text(
                                'Only $stock item${stock == 1 ? '' : 's'} available',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF0080),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('OK',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                  _addPiece(ctx, widget.product, widget.piece);
                },
                child: const SizedBox(
                    width: 34, height: 36,
                    child: Icon(Icons.add,
                        color: Colors.white, size: 16)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(
            '₹$liveTotal',
            style: const TextStyle(
                color:      Color(0xFFFF0080),
                fontSize:   11,
                fontWeight: FontWeight.bold),
          ),
        ],
      );
      },
    );
  }
}