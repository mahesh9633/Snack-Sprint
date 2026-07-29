

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
      .fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.values.fold(
    0.0,
        (sum, item) => sum + item.product.price * item.quantity,
  );

  int getQuantity(Product product) => _items[product.id]?.quantity ?? 0;

  int getPieceQuantity(String productId) {
    return _items.entries
        .where(
          (entry) =>
      entry.key == productId ||
          entry.key.startsWith('${productId}_piece_'),
    )
        .fold(0, (sum, entry) => sum + entry.value.quantity);
  }

  bool contains(Product product) => _items.containsKey(product.id);

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

  void updateItemStock(String productId, int newStock) {
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
          final prefs = await SharedPreferences.getInstance();

          final encoded = jsonEncode(
            _items.values.map((item) => item.toJson()).toList(),
          );

          await prefs.setString(_cartKey, encoded);
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
    final stock =
    product.quantity > 0 ? product.quantity : product.posQuantity;

    final currentQty = _items[product.id]?.quantity ?? 0;

    if (stock <= 0) {
      onStockLimitReached?.call(
        'Product is currently out of stock',
      );
      return;
    }

    if (currentQty >= stock) {
      onStockLimitReached?.call(
        'Only $stock item${stock == 1 ? '' : 's'} available in stock',
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
      _items[product.id] = CartItem(product: product);
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
        'Product is currently out of stock',
      );
      return;
    }

    if (item.quantity >= stock) {
      onStockLimitReached?.call(
        'Only $stock item${stock == 1 ? '' : 's'} available in stock',
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

  void setQuantity(Product product, int qty) {
    if (qty <= 0) {
      _items.remove(product.id);
      notifyListeners();
      _saveCart();
      return;
    }

    final stock =
    product.quantity > 0 ? product.quantity : product.posQuantity;

    if (stock > 0 && qty > stock) {
      onStockLimitReached?.call(
        'Only $stock item${stock == 1 ? '' : 's'} available in stock',
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
