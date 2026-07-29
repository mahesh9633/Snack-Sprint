

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../screens/cart_screen.dart';
import '../services/store_profile_cache.dart';

class FloatingCartBar extends StatefulWidget {
  final String token;
  final String customerId;
  final VoidCallback? onGoToHome;

  const FloatingCartBar({
    super.key,
    this.token = '',
    this.customerId = '',
    this.onGoToHome,
  });

  @override
  State<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends State<FloatingCartBar> {
  bool _isOpeningCart = false;

  Future<void> _openCart() async {
    if (_isOpeningCart) return;

    setState(() => _isOpeningCart = true);

    try {
      // Normally SplashScreen has already completed this preload.
      // This remains as a safety fallback for newly logged-in customers
      // or any navigation flow that bypasses the splash screen.
      if (!StoreProfileCache.hasLoaded) {
        await StoreProfileCache.preload();
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartScreen(
            token: widget.token,
            customerId: widget.customerId,
            onGoToHome: widget.onGoToHome ??
                    () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningCart = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartModel>(
      builder: (context, cart, _) {
        final totalQty = cart.totalQuantity;

        return IgnorePointer(
          ignoring: totalQty == 0 || _isOpeningCart,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            offset: totalQty == 0
                ? const Offset(0, 1.5)
                : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: totalQty == 0 ? 0.0 : 1.0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: totalQty == 0 ? null : _openCart,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
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
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_bag,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          _isOpeningCart
                              ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            '$totalQty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
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
