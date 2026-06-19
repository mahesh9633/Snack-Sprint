import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_color.dart';
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
        final totalQty   = cart.totalQuantity;
        final totalPrice = cart.totalPrice;

        return IgnorePointer(
            ignoring: totalQty == 0,
            child: AnimatedSlide(
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
              // ── FIX: Row shrink-wraps its height regardless of how much
              // vertical space the parent offers, unlike Align — so this
              // pill no longer gets stretched + centered in the full
              // screen height when used as a Scaffold FAB.
              child: Row(
                mainAxisSize:      MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.floatingCartBg,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.floatingCartBg.withOpacity(0.35),
                          blurRadius: 12,
                          offset:     const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$totalQty',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      },
    );
  }
}