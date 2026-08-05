// import 'package:flutter/material.dart';
// import '../config/app_color.dart';
// import '../model/cart_model.dart';
// import '../model/product_model.dart';
// import '../widgets/piece_selector_sheet.dart';
//
// /// Shared cart add/stepper button — used by ProductCard and Similar Product cards.
// class CartActionButton extends StatelessWidget {
//   final Product product;
//   final CartModel cart;
//
//   const CartActionButton({
//     super.key,
//     required this.product,
//     required this.cart,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     if (product.pieces.isNotEmpty) {
//       final qty = cart.getPieceQuantity(product.id);
//       final inCart = qty > 0;
//       return GestureDetector(
//         onTap: () => handleAddToCart(
//           context: context,
//           product: product,
//           pieces: product.pieces,
//         ),
//         child: _box(
//           filled: inCart,
//           child: inCart
//               ? Center(child: _qtyText(qty))
//               : const Icon(Icons.add, color: AppColors.addBtnGreen, size: 18),
//         ),
//       );
//     }
//
//     final qty = cart.getQuantity(product);
//     if (qty == 0) {
//       return GestureDetector(
//         onTap: () => cart.addItem(product),
//         child: _box(
//           filled: false,
//           child: const Icon(Icons.add, color: AppColors.addBtnGreen, size: 18),
//         ),
//       );
//     }
//
//     return _stepper(qty);
//   }
//
//   Widget _box({required bool filled, required Widget child}) => Container(
//     width: 30,
//     height: 30,
//     decoration: BoxDecoration(
//       color: filled ? AppColors.addBtnGreen : AppColors.cardWhite,
//       borderRadius: BorderRadius.circular(10),
//       border: filled ? null : Border.all(color: AppColors.addBtnGreen, width: 1.8),
//       boxShadow: [
//         BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 6, offset: const Offset(0, 2)),
//       ],
//     ),
//     child: child,
//   );
//
//   Widget _qtyText(int qty) => Text(
//     '$qty',
//     style: const TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.bold),
//   );
//
//   Widget _stepper(int qty) {
//     final stock = product.quantity > 0 ? product.quantity : product.posQuantity;
//     return Container(
//       height: 30,
//       decoration: BoxDecoration(
//         color: AppColors.addBtnGreen,
//         borderRadius: BorderRadius.circular(10),
//         boxShadow: [
//           BoxShadow(color: AppColors.addBtnGreen.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3)),
//         ],
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           GestureDetector(
//             onTap: () => cart.decrementQuantity(product.id),
//             child: const SizedBox(
//                 width: 30, height: 30,
//                 child: Icon(Icons.remove, color: AppColors.textLight, size: 15)),
//           ),
//           Container(
//             constraints: const BoxConstraints(minWidth: 22),
//             alignment: Alignment.center,
//             child: _qtyText(qty),
//           ),
//           GestureDetector(
//             onTap: () {
//               if (stock > 0 && qty >= stock) return;
//               cart.addItem(product);
//             },
//             child: const SizedBox(
//                 width: 30, height: 30,
//                 child: Icon(Icons.add, color: AppColors.textLight, size: 15)),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../model/product_model.dart';
import '../utils/cart_add_helper.dart';
import '../widgets/piece_selector_sheet.dart';

/// Shared cart add/stepper button — used by ProductCard
/// and Similar Product cards.
class CartActionButton extends StatelessWidget {
  final Product product;
  final CartModel cart;

  const CartActionButton({
    super.key,
    required this.product,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    if (product.pieces.isNotEmpty) {
      final qty = cart.getPieceQuantity(product.id);
      final inCart = qty > 0;

      return GestureDetector(
        onTap: () => handleAddToCart(
          context: context,
          product: product,
          pieces: product.pieces,
        ),
        child: _box(
          filled: inCart,
          child: inCart
              ? Center(
            child: _qtyText(qty),
          )
              : const Icon(
            Icons.add,
            color: AppColors.addBtnGreen,
            size: 18,
          ),
        ),
      );
    }

    final qty = cart.getQuantity(product);

    if (qty == 0) {
      return GestureDetector(
        onTap: () async {
          await addProductWithCategoryCheck(
            context: context,
            product: product,
          );
        },
        child: _box(
          filled: false,
          child: const Icon(
            Icons.add,
            color: AppColors.addBtnGreen,
            size: 18,
          ),
        ),
      );
    }

    return _stepper(
      context,
      qty,
    );
  }

  Widget _box({
    required bool filled,
    required Widget child,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: filled
            ? AppColors.addBtnGreen
            : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: filled
            ? null
            : Border.all(
          color: AppColors.addBtnGreen,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _qtyText(int qty) {
    return Text(
      '$qty',
      style: const TextStyle(
        color: AppColors.textLight,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _stepper(
      BuildContext context,
      int qty,
      ) {
    final stock = product.quantity > 0
        ? product.quantity
        : product.posQuantity;

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.addBtnGreen,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.addBtnGreen.withValues(
              alpha: 0.30,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              cart.decrementQuantity(product.id);
            },
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Icon(
                Icons.remove,
                color: AppColors.textLight,
                size: 15,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              minWidth: 22,
            ),
            alignment: Alignment.center,
            child: _qtyText(qty),
          ),
          GestureDetector(
            onTap: () async {
              if (stock > 0 && qty >= stock) {
                return;
              }

              await addProductWithCategoryCheck(
                context: context,
                product: product,
              );
            },
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Icon(
                Icons.add,
                color: AppColors.textLight,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}