import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/cart_model.dart';
import '../screens/cart_screen.dart';

class FloatingCartBar extends StatelessWidget {
  final String token;
  final String customerId;

  const FloatingCartBar({
    super.key,
    this.token      = '',
    this.customerId = '',
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartModel>(
      builder: (context, cart, _) {
        final totalQty   = cart.totalQuantity;
        final totalPrice = cart.totalPrice;

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
                      onGoToHome: () => Navigator.pop(context),
                    ),
                  ),
                );
              },
              child: Container(
                height: 62,
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
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
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

                    // ── Centre label ───────────────────────────────────────
                    const Expanded(
                      child: Text(
                        'View Cart',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:         Colors.white,
                          fontSize:      16,
                          fontWeight:    FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
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