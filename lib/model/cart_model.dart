//
//
// import 'dart:async';
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../model/address_model.dart';
// import '../model/product_model.dart';
//
// class CartItem {
//   final Product product;
//   int quantity;
//
//   CartItem({
//     required this.product,
//     this.quantity = 1,
//   });
//
//   Map<String, dynamic> toJson() => {
//     'product': product.toJson(),
//     'quantity': quantity,
//   };
//
//   factory CartItem.fromJson(Map<String, dynamic> json) {
//     final rawProduct = json['product'];
//
//     return CartItem(
//       product: Product.fromJson(
//         rawProduct is Map
//             ? Map<String, dynamic>.from(rawProduct)
//             : <String, dynamic>{},
//       ),
//       quantity: (json['quantity'] as num?)?.toInt() ?? 1,
//     );
//   }
// }
//
// class CartModel extends ChangeNotifier {
//   void Function(String message)? onStockLimitReached;
//
//   String _cartKey = 'mtl_cart_items_guest';
//
//   final Map<String, CartItem> _items = {};
//
//   Map<String, CartItem> get items => Map.unmodifiable(_items);
//
//   int get totalQuantity => _items.values
//       .where(
//         (item) =>
//     item.product.quantity > 0 ||
//         item.product.posQuantity > 0,
//   )
//       .fold(
//     0,
//         (sum, item) => sum + item.quantity,
//   );
//
//   double get totalPrice => _items.values.fold(
//     0.0,
//         (sum, item) =>
//     sum + item.product.price * item.quantity,
//   );
//
//   int getQuantity(Product product) {
//     return _items[product.id]?.quantity ?? 0;
//   }
//
//   int getPieceQuantity(String productId) {
//     return _items.entries
//         .where(
//           (entry) =>
//       entry.key == productId ||
//           entry.key.startsWith('${productId}_piece_'),
//     )
//         .fold(
//       0,
//           (sum, entry) => sum + entry.value.quantity,
//     );
//   }
//
//   bool contains(Product product) {
//     return _items.containsKey(product.id);
//   }
//
//   bool _hasValidImage(String value) {
//     final image = value.trim();
//
//     return image.isNotEmpty &&
//         image.toLowerCase() != 'no_image.png' &&
//         image.toLowerCase() != 'null';
//   }
//
//   Product _mergeProductImage(
//       Product freshProduct,
//       Product oldProduct,
//       ) {
//     return freshProduct.copyWith(
//       image: _hasValidImage(freshProduct.image)
//           ? freshProduct.image
//           : oldProduct.image,
//       imageUrl: _hasValidImage(freshProduct.imageUrl)
//           ? freshProduct.imageUrl
//           : oldProduct.imageUrl,
//     );
//   }
//
//   void updateItemStock(
//       String productId,
//       int newStock,
//       ) {
//     final item = _items[productId];
//
//     if (item == null) return;
//
//     if (item.product.quantity == newStock &&
//         item.product.posQuantity == newStock) {
//       return;
//     }
//
//     final updatedProduct = item.product.copyWith(
//       quantity: newStock,
//       posQuantity: newStock,
//     );
//
//     _items[productId] = CartItem(
//       product: updatedProduct,
//       quantity: item.quantity,
//     );
//
//     notifyListeners();
//   }
//
//   /// Replaces the stored product data while preserving the customer's
//   /// cart quantity and preserving an existing valid image when the fresh
//   /// API response has no image.
//   ///
//   /// The refreshed product is saved to SharedPreferences so the next time
//   /// CartScreen opens, the image is already available immediately.
//   void updateItemProduct(
//       String productId,
//       Product freshProduct, {
//         int? quantity,
//         bool saveToStorage = true,
//       }) {
//     final existingItem = _items[productId];
//
//     if (existingItem == null) return;
//
//     final safeProduct = _mergeProductImage(
//       freshProduct,
//       existingItem.product,
//     );
//
//     _items[productId] = CartItem(
//       product: safeProduct,
//       quantity: quantity ?? existingItem.quantity,
//     );
//
//     notifyListeners();
//
//     if (saveToStorage) {
//       _saveCart();
//     }
//   }
//
//   Future<void> loadForUser(String userId) async {
//     _cartKey = 'mtl_cart_items_$userId';
//
//     _items.clear();
//     notifyListeners();
//
//     await loadCart();
//   }
//
//   void clearForLogout() {
//     _items.clear();
//     _cartKey = 'mtl_cart_items_guest';
//     notifyListeners();
//   }
//
//   Future<void> loadCart() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final raw = prefs.getString(_cartKey);
//
//       if (raw == null || raw.isEmpty) {
//         return;
//       }
//
//       final decoded = jsonDecode(raw);
//
//       if (decoded is! List) {
//         return;
//       }
//
//       _items.clear();
//
//       for (final rawItem in decoded) {
//         if (rawItem is! Map) continue;
//
//         final item = CartItem.fromJson(
//           Map<String, dynamic>.from(rawItem),
//         );
//
//         if (item.product.id.isEmpty) continue;
//
//         _items[item.product.id] = item;
//       }
//
//       notifyListeners();
//     } catch (_) {
//       // Do not crash the app for damaged old cart data.
//     }
//   }
//
//   void refreshCart() {
//     notifyListeners();
//   }
//
//   Timer? _saveDebounce;
//
//   Future<void> _saveCart() async {
//     _saveDebounce?.cancel();
//
//     _saveDebounce = Timer(
//       const Duration(milliseconds: 350),
//           () async {
//         try {
//           final prefs =
//           await SharedPreferences.getInstance();
//
//           final encoded = jsonEncode(
//             _items.values
//                 .map((item) => item.toJson())
//                 .toList(),
//           );
//
//           await prefs.setString(
//             _cartKey,
//             encoded,
//           );
//         } catch (_) {
//           // Ignore storage failures without crashing cart operations.
//         }
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     _saveDebounce?.cancel();
//     super.dispose();
//   }
//
//   void addItem(Product product) {
//     final stock = product.quantity > 0
//         ? product.quantity
//         : product.posQuantity;
//
//     final currentQty =
//         _items[product.id]?.quantity ?? 0;
//
//     if (stock <= 0) {
//       onStockLimitReached?.call(
//         'Product is currently not available',
//       );
//       return;
//     }
//
//     if (currentQty >= stock) {
//       onStockLimitReached?.call(
//         'Only $stock item${stock == 1 ? '' : 's'} '
//             'available in stock',
//       );
//       return;
//     }
//
//     final existingItem = _items[product.id];
//
//     if (existingItem != null) {
//       final safeProduct = _mergeProductImage(
//         product,
//         existingItem.product,
//       );
//
//       _items[product.id] = CartItem(
//         product: safeProduct,
//         quantity: existingItem.quantity + 1,
//       );
//     } else {
//       _items[product.id] = CartItem(
//         product: product,
//       );
//     }
//
//     notifyListeners();
//     _saveCart();
//   }
//
//   void removeItem(Product product) {
//     _items.remove(product.id);
//
//     notifyListeners();
//     _saveCart();
//   }
//
//   void incrementQuantity(String productId) {
//     final item = _items[productId];
//
//     if (item == null) return;
//
//     final stock = item.product.quantity > 0
//         ? item.product.quantity
//         : item.product.posQuantity;
//
//     if (stock <= 0) {
//       onStockLimitReached?.call(
//         'Product is currently not available',
//       );
//       return;
//     }
//
//     if (item.quantity >= stock) {
//       onStockLimitReached?.call(
//         'Only $stock item${stock == 1 ? '' : 's'} '
//             'available in stock',
//       );
//       return;
//     }
//
//     item.quantity++;
//
//     notifyListeners();
//     _saveCart();
//   }
//
//   void decrementQuantity(String productId) {
//     final item = _items[productId];
//
//     if (item == null) return;
//
//     if (item.quantity <= 1) {
//       _items.remove(productId);
//     } else {
//       item.quantity--;
//     }
//
//     notifyListeners();
//     _saveCart();
//   }
//
//   void setQuantity(
//       Product product,
//       int qty,
//       ) {
//     if (qty <= 0) {
//       _items.remove(product.id);
//
//       notifyListeners();
//       _saveCart();
//       return;
//     }
//
//     final stock = product.quantity > 0
//         ? product.quantity
//         : product.posQuantity;
//
//     if (stock > 0 && qty > stock) {
//       onStockLimitReached?.call(
//         'Only $stock item${stock == 1 ? '' : 's'} '
//             'available in stock',
//       );
//
//       qty = stock;
//     }
//
//     final existingItem = _items[product.id];
//
//     final safeProduct = existingItem == null
//         ? product
//         : _mergeProductImage(
//       product,
//       existingItem.product,
//     );
//
//     _items[product.id] = CartItem(
//       product: safeProduct,
//       quantity: qty,
//     );
//
//     notifyListeners();
//     _saveCart();
//   }
//
//   /// Checks whether the new product belongs to a different category
//   /// or subcategory from the products already available in the cart.
//   bool hasCategoryConflict(Product newProduct) {
//     if (_items.isEmpty) {
//       return false;
//     }
//
//     // Same product already exists: quantity can increase normally.
//     if (_items.containsKey(newProduct.id)) {
//       return false;
//     }
//
//     final newCategory = newProduct.category.trim();
//     final newSubCategory = newProduct.subCategory.trim();
//
//     debugPrint('===== CART MODEL CONFLICT CHECK =====');
//     debugPrint('NEW PRODUCT      : ${newProduct.name}');
//     debugPrint('NEW CATEGORY     : "$newCategory"');
//     debugPrint('NEW SUBCATEGORY  : "$newSubCategory"');
//
//     for (final cartItem in _items.values) {
//       final oldProduct = cartItem.product;
//
//       // Same product or same piece can increase normally.
//       if (oldProduct.id == newProduct.id) {
//         continue;
//       }
//
//       final oldCategory = oldProduct.category.trim();
//       final oldSubCategory = oldProduct.subCategory.trim();
//
//       debugPrint('OLD PRODUCT      : ${oldProduct.name}');
//       debugPrint('OLD CATEGORY     : "$oldCategory"');
//       debugPrint('OLD SUBCATEGORY  : "$oldSubCategory"');
//
//       /*
//      * Category data is missing.
//      *
//      * We cannot safely confirm that these products belong to the same
//      * category, so show the replacement popup instead of allowing two
//      * potentially different-category items into the cart.
//      */
//       if (newCategory.isEmpty || oldCategory.isEmpty) {
//         debugPrint('CONFLICT: Missing category information');
//         return true;
//       }
//
//       // Different parent categories.
//       if (newCategory != oldCategory) {
//         debugPrint('CONFLICT: Different parent category');
//         return true;
//       }
//
//       // Same parent category but different subcategories.
//       if (newSubCategory.isNotEmpty &&
//           oldSubCategory.isNotEmpty &&
//           newSubCategory != oldSubCategory) {
//         debugPrint('CONFLICT: Different subcategory');
//         return true;
//       }
//     }
//
//     debugPrint('NO CATEGORY CONFLICT');
//     return false;
//   }
//
//   /// Clears all existing cart items and adds the newly selected product.
//   Future<void> replaceCartWithProduct(
//       Product product, {
//         int quantity = 1,
//       }) async {
//     final stock = product.quantity > 0
//         ? product.quantity
//         : product.posQuantity;
//
//     if (stock <= 0) {
//       onStockLimitReached?.call(
//         'Product is currently not available',
//       );
//       return;
//     }
//
//     int safeQuantity = quantity;
//
//     if (safeQuantity <= 0) {
//       safeQuantity = 1;
//     }
//
//     if (safeQuantity > stock) {
//       safeQuantity = stock;
//
//       onStockLimitReached?.call(
//         'Only $stock item${stock == 1 ? '' : 's'} '
//             'available in stock',
//       );
//     }
//
//     _items.clear();
//
//     _items[product.id] = CartItem(
//       product: product,
//       quantity: safeQuantity,
//     );
//
//     notifyListeners();
//     await _saveCart();
//   }
//
//   void clearCart() {
//     _items.clear();
//
//     notifyListeners();
//     _saveCart();
//   }
//
//   void clearCartMemoryOnly() {
//     _items.clear();
//     notifyListeners();
//   }
//
//   Future<AddressModel?> getDefaultAddress() {
//     return AddressStorage.getDefault();
//   }
//
//   Future<List<AddressModel>> getSavedAddresses() {
//     return AddressStorage.load();
//   }
// }

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/address_model.dart';
import '../model/product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final rawProduct = json['product'];

    return CartItem(
      product: Product.fromJson(
        rawProduct is Map
            ? Map<String, dynamic>.from(rawProduct)
            : <String, dynamic>{},
      ),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class CartModel extends ChangeNotifier {
  void Function(String message)? onStockLimitReached;

  String _cartKey = 'mtl_cart_items_guest';

  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);

  int get totalQuantity => _items.values
      .where(
        (item) =>
    item.product.quantity > 0 ||
        item.product.posQuantity > 0,
  )
      .fold(
    0,
        (sum, item) => sum + item.quantity,
  );

  double get totalPrice => _items.values.fold(
    0.0,
        (sum, item) =>
    sum + item.product.price * item.quantity,
  );

  int getQuantity(Product product) {
    return _items[product.id]?.quantity ?? 0;
  }

  int getPieceQuantity(String productId) {
    return _items.entries
        .where(
          (entry) =>
      entry.key == productId ||
          entry.key.startsWith('${productId}_piece_'),
    )
        .fold(
      0,
          (sum, entry) => sum + entry.value.quantity,
    );
  }

  bool contains(Product product) {
    return _items.containsKey(product.id);
  }

  bool _hasValidImage(String value) {
    final image = value.trim();

    return image.isNotEmpty &&
        image.toLowerCase() != 'no_image.png' &&
        image.toLowerCase() != 'null';
  }

  Product _mergeProductImage(
      Product freshProduct,
      Product oldProduct,
      ) {
    return freshProduct.copyWith(
      image: _hasValidImage(freshProduct.image)
          ? freshProduct.image
          : oldProduct.image,
      imageUrl: _hasValidImage(freshProduct.imageUrl)
          ? freshProduct.imageUrl
          : oldProduct.imageUrl,
    );
  }

  void updateItemStock(
      String productId,
      int newStock,
      ) {
    final item = _items[productId];

    if (item == null) return;

    if (item.product.quantity == newStock &&
        item.product.posQuantity == newStock) {
      return;
    }

    final updatedProduct = item.product.copyWith(
      quantity: newStock,
      posQuantity: newStock,
    );

    _items[productId] = CartItem(
      product: updatedProduct,
      quantity: item.quantity,
    );

    notifyListeners();
  }

  /// Replaces the stored product data while preserving the customer's
  /// cart quantity and preserving an existing valid image when the fresh
  /// API response has no image.
  ///
  /// The refreshed product is saved to SharedPreferences so the next time
  /// CartScreen opens, the image is already available immediately.
  void updateItemProduct(
      String productId,
      Product freshProduct, {
        int? quantity,
        bool saveToStorage = true,
      }) {
    final existingItem = _items[productId];

    if (existingItem == null) return;

    final safeProduct = _mergeProductImage(
      freshProduct,
      existingItem.product,
    );

    _items[productId] = CartItem(
      product: safeProduct,
      quantity: quantity ?? existingItem.quantity,
    );

    notifyListeners();

    if (saveToStorage) {
      _saveCart();
    }
  }

  Future<void> loadForUser(String userId) async {
    _cartKey = 'mtl_cart_items_$userId';

    _items.clear();
    notifyListeners();

    await loadCart();
  }

  void clearForLogout() {
    _items.clear();
    _cartKey = 'mtl_cart_items_guest';
    notifyListeners();
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cartKey);

      if (raw == null || raw.isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return;
      }

      _items.clear();

      for (final rawItem in decoded) {
        if (rawItem is! Map) continue;

        final item = CartItem.fromJson(
          Map<String, dynamic>.from(rawItem),
        );

        if (item.product.id.isEmpty) continue;

        _items[item.product.id] = item;
      }

      notifyListeners();
    } catch (_) {
      // Do not crash the app for damaged old cart data.
    }
  }

  void refreshCart() {
    notifyListeners();
  }

  Timer? _saveDebounce;

  Future<void> _saveCart() async {
    _saveDebounce?.cancel();

    _saveDebounce = Timer(
      const Duration(milliseconds: 350),
          () async {
        try {
          final prefs =
          await SharedPreferences.getInstance();

          final encoded = jsonEncode(
            _items.values
                .map((item) => item.toJson())
                .toList(),
          );

          await prefs.setString(
            _cartKey,
            encoded,
          );
        } catch (_) {
          // Ignore storage failures without crashing cart operations.
        }
      },
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void addItem(Product product) {
    final stock = product.quantity > 0
        ? product.quantity
        : product.posQuantity;

    final currentQty =
        _items[product.id]?.quantity ?? 0;

    if (stock <= 0) {
      onStockLimitReached?.call(
        'Product is currently not available',
      );
      return;
    }

    if (currentQty >= stock) {
      onStockLimitReached?.call(
        'Stock Limit Reached',
      );
      return;
    }

    final existingItem = _items[product.id];

    if (existingItem != null) {
      final safeProduct = _mergeProductImage(
        product,
        existingItem.product,
      );

      _items[product.id] = CartItem(
        product: safeProduct,
        quantity: existingItem.quantity + 1,
      );
    } else {
      _items[product.id] = CartItem(
        product: product,
      );
    }

    notifyListeners();
    _saveCart();
  }

  void removeItem(Product product) {
    _items.remove(product.id);

    notifyListeners();
    _saveCart();
  }

  void incrementQuantity(String productId) {
    final item = _items[productId];

    if (item == null) return;

    final stock = item.product.quantity > 0
        ? item.product.quantity
        : item.product.posQuantity;

    if (stock <= 0) {
      onStockLimitReached?.call(
        'Product is currently not available',
      );
      return;
    }

    if (item.quantity >= stock) {
      onStockLimitReached?.call(
        'Stock Limit Reached',
      );
      return;
    }

    item.quantity++;

    notifyListeners();
    _saveCart();
  }

  void decrementQuantity(String productId) {
    final item = _items[productId];

    if (item == null) return;

    if (item.quantity <= 1) {
      _items.remove(productId);
    } else {
      item.quantity--;
    }

    notifyListeners();
    _saveCart();
  }

  void setQuantity(
      Product product,
      int qty,
      ) {
    if (qty <= 0) {
      _items.remove(product.id);

      notifyListeners();
      _saveCart();
      return;
    }

    final stock = product.quantity > 0
        ? product.quantity
        : product.posQuantity;

    if (stock > 0 && qty > stock) {
      onStockLimitReached?.call(
        'Stock Limit Reached',
      );

      qty = stock;
    }

    final existingItem = _items[product.id];

    final safeProduct = existingItem == null
        ? product
        : _mergeProductImage(
      product,
      existingItem.product,
    );

    _items[product.id] = CartItem(
      product: safeProduct,
      quantity: qty,
    );

    notifyListeners();
    _saveCart();
  }

  /// Checks whether the new product belongs to a different category from
  /// the products already in the cart.
  ///
  /// NOTE: Only `category` is compared (not `subCategory`). Different
  /// screens in this app populate `category` with different levels of
  /// specificity (top-level id vs leaf/subcategory id), so comparing a
  /// second field reliably isn't possible without touching every screen's
  /// product-mapping code. Every screen has been normalized to put the
  /// most specific category id it has into `category`, so comparing that
  /// single field is both simpler and consistent everywhere.
  ///
  /// Missing category data (empty string) on either side is treated as
  /// "cannot confirm a conflict", so the add is allowed rather than
  /// blocked — this is the safe default per the empty-value handling
  /// requirement.
  bool hasCategoryConflict(Product newProduct) {
    if (_items.isEmpty) {
      return false;
    }

    // Same product already exists: quantity can increase normally.
    if (_items.containsKey(newProduct.id)) {
      return false;
    }

    final newCategory = newProduct.category.trim();

    // Missing category data on the new product — can't safely compare,
    // so don't block the add.
    if (newCategory.isEmpty) {
      return false;
    }

    debugPrint('===== CART MODEL CONFLICT CHECK =====');
    debugPrint('NEW PRODUCT      : ${newProduct.name}');
    debugPrint('NEW CATEGORY     : "$newCategory"');

    for (final cartItem in _items.values) {
      final oldProduct = cartItem.product;

      // Same product or same piece can increase normally.
      if (oldProduct.id == newProduct.id) {
        continue;
      }

      final oldCategory = oldProduct.category.trim();

      debugPrint('OLD PRODUCT      : ${oldProduct.name}');
      debugPrint('OLD CATEGORY     : "$oldCategory"');

      // Missing category data on the existing item — skip this
      // comparison rather than blocking.
      if (oldCategory.isEmpty) {
        continue;
      }

      if (oldCategory != newCategory) {
        debugPrint('CONFLICT: Different category');
        return true;
      }
    }

    debugPrint('NO CATEGORY CONFLICT');
    return false;
  }

  /// Clears all existing cart items and adds the newly selected product.
  Future<void> replaceCartWithProduct(
      Product product, {
        int quantity = 1,
      }) async {
    final stock = product.quantity > 0
        ? product.quantity
        : product.posQuantity;

    if (stock <= 0) {
      onStockLimitReached?.call(
        'Product is currently not available',
      );
      return;
    }

    int safeQuantity = quantity;

    if (safeQuantity <= 0) {
      safeQuantity = 1;
    }

    if (safeQuantity > stock) {
      safeQuantity = stock;

      onStockLimitReached?.call(
        'Stock Limit Reached',
      );
    }

    _items.clear();

    _items[product.id] = CartItem(
      product: product,
      quantity: safeQuantity,
    );

    notifyListeners();
    await _saveCart();
  }

  void clearCart() {
    _items.clear();

    notifyListeners();
    _saveCart();
  }

  void clearCartMemoryOnly() {
    _items.clear();
    notifyListeners();
  }

  Future<AddressModel?> getDefaultAddress() {
    return AddressStorage.getDefault();
  }

  Future<List<AddressModel>> getSavedAddresses() {
    return AddressStorage.load();
  }
}
