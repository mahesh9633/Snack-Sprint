import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../model/product_model.dart';
import '../widgets/piece_selector_sheet.dart' show handleAddToCart, ProductPiece;

/// Single gateway for "add product to cart" across the whole app.
///
/// Every ADD button (simple product or piece product) should call one of
/// the two functions below instead of calling `cart.addItem(...)` or
/// `handleAddToCart(...)` directly. This is where the "one
/// category/subcategory per cart" popup is shown — nowhere else.

/// For products WITHOUT pieces (plain ADD tap, or stepper "+").
Future<bool> addProductWithCategoryCheck({
  required BuildContext context,
  required Product product,
  int quantity = 1,
}) async {
  final cart = context.read<CartModel>();

  // Temporary debug logs
  debugPrint('========== CATEGORY CHECK ==========');
  debugPrint('NEW PRODUCT      : ${product.name}');
  debugPrint('NEW PRODUCT ID   : ${product.id}');
  debugPrint('NEW CATEGORY     : ${product.category}');
  debugPrint('NEW SUBCATEGORY  : ${product.subCategory}');
  debugPrint('CART ITEM COUNT  : ${cart.items.length}');

  for (final item in cart.items.values) {
    debugPrint('------------------------------------');
    debugPrint('CART PRODUCT     : ${item.product.name}');
    debugPrint('CART PRODUCT ID  : ${item.product.id}');
    debugPrint('CART CATEGORY    : ${item.product.category}');
    debugPrint('CART SUBCATEGORY : ${item.product.subCategory}');
  }

  debugPrint(
    'HAS CONFLICT     : ${cart.hasCategoryConflict(product)}',
  );
  debugPrint('====================================');

  // Product is already present, so increase its quantity normally
  if (cart.items.containsKey(product.id)) {
    cart.addItem(product);
    return true;
  }

  // Empty cart or same category
  if (!cart.hasCategoryConflict(product)) {
    cart.addItem(product);
    return true;
  }

  // Different category
  final replaceItems = await _showCategoryConflictDialog(context);

  if (!replaceItems || !context.mounted) {
    return false;
  }

  await cart.replaceCartWithProduct(
    product,
    quantity: quantity,
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Previous cart items removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  return true;
}

/// For products WITH pieces — wraps the existing piece-selector flow
/// (`handleAddToCart`) with the same category-conflict check.
///
/// NOTE: `handleAddToCart` returns `void` (it either adds directly or
/// opens a bottom sheet without waiting for it), so it must be called
/// WITHOUT `await`.
Future<bool> addPieceProductWithCategoryCheck({
  required BuildContext context,
  required Product product,
  required List<ProductPiece> pieces,
}) async {
  final cart = context.read<CartModel>();

  final alreadyInCart = cart.items.keys.any(
        (id) => id == product.id || id.startsWith('${product.id}_piece_'),
  );

  if (alreadyInCart || !cart.hasCategoryConflict(product)) {
    handleAddToCart(context: context, product: product, pieces: pieces);
    return true;
  }

  final replaceItems = await _showCategoryConflictDialog(context);

  if (!replaceItems || !context.mounted) {
    return false;
  }

  cart.clearCart();
  if (!context.mounted) return false;

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(const SnackBar(
      content: Text('Previous cart items removed.'),
      behavior: SnackBarBehavior.floating,
    ));

  handleAddToCart(context: context, product: product, pieces: pieces);
  return true;
}

Future<bool> _showCategoryConflictDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              color: AppColors.primaryOrange,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Replace Cart Items?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
              'Adding this product will remove the existing cart items.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}