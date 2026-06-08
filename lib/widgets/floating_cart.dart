import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/cart_model.dart';
import '../screens/cart_screen.dart';

class FloatingCartBar extends StatelessWidget {
  final String token;
  final String customerId;
  final VoidCallback? onGoToHome;

  const FloatingCartBar({
    super.key,
    this.token      = '',
    this.customerId = '',
    this.onGoToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartModel>(
      builder: (context, cart, _) {
        // final totalQty   = cart.totalQuantity;
        // final totalPrice = cart.totalPrice;
        //
        // return AnimatedSlide(
        final totalQty     = cart.totalQuantity;
        final totalPrice   = cart.totalPrice;

        // Build combo summary e.g. "1KG × 2  ·  1KG × 4 ×2"
        final comboItems = cart.items.values.where((item) =>
            item.product.id.contains('_piece_')).toList();
        final comboSummary = comboItems.isEmpty ? '' :
        comboItems.map((item) {
          final label = item.product.weight.isNotEmpty
              ? item.product.weight : item.product.name;
          final matchedPiece = item.product.pieces.isNotEmpty
              ? item.product.pieces.first : null;
          final minQty = matchedPiece?.minQuantity ?? 0;
          final totalUnits = minQty > 0 ? minQty * item.quantity : item.quantity;
          return '$label × $totalUnits units';
        }).join('  ·  ');
        final hasCombo = comboSummary.isNotEmpty;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeInOut,
          offset:   totalQty == 0
              ? const Offset(0, 1.5)
              : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity:  totalQty == 0 ? 0.0 : 1.0,
            child: GestureDetector(
              onTap: totalQty == 0 ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartScreen(
                      token:      token,
                      customerId: customerId,
                      onGoToHome: onGoToHome ?? () => Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                  ),
                );
              },
              child: Container(
                // height: 62,
                height: hasCombo ? 72 : 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0080), Color(0xFFFF0080)],
                    begin:  Alignment.centerLeft,
                    end:    Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:      const Color(0xFFFF0080).withOpacity(0.4),
                      blurRadius: 16,
                      offset:     const Offset(0, 6),
                    ),
                  ],
                ),
                // padding: const EdgeInsets.symmetric(horizontal: 18),
                // child: Row(
                //   children: [
                //     // ── Item count badge ───────────────────────────────────
                //     Container(
                //       padding: const EdgeInsets.symmetric(
                //           horizontal: 10, vertical: 5),
                //       decoration: BoxDecoration(
                //         color:        Colors.white.withOpacity(0.22),
                //         borderRadius: BorderRadius.circular(10),
                //       ),
                //       child: Text(
                //         '$totalQty ${totalQty == 1 ? 'item' : 'items'}',
                //         style: const TextStyle(
                //           color:      Colors.white,
                //           fontSize:   13,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //     ),
                //
                //     // ── Centre label ───────────────────────────────────────
                //     const Expanded(
                //       child: Text(
                //         'View Cart',
                //         textAlign: TextAlign.center,
                //         style: TextStyle(
                //           color:         Colors.white,
                //           fontSize:      16,
                //           fontWeight:    FontWeight.bold,
                //           letterSpacing: 0.5,
                //         ),
                //       ),
                //     ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Item count badge ───────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalQty ${totalQty == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ── Centre: "View Cart" + optional combo line ──────────
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'View Cart',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:         Colors.white,
                              fontSize:      16,
                              fontWeight:    FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (hasCombo) ...[
                            const SizedBox(height: 3),
                            Text(
                              comboSummary,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:      Colors.white.withOpacity(0.85),
                                fontSize:   11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Total + chevron ────────────────────────────────────
                    Text(
                      '₹${totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}