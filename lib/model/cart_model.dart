

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/address_model.dart';
import '../model/product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  Map<String, dynamic> toJson() => {
    'product':  product.toJson(),
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product:  Product.fromJson(json['product'] as Map<String, dynamic>),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}

class CartModel extends ChangeNotifier {

  // callback to notify UI when stock limit is reached
  void Function(String message)? onStockLimitReached;

  // ── Per-user key (set on login, reset on logout) ───────────────────────────
  String _cartKey = 'mtl_cart_items_guest';

  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);

  // ── Only count items that are CURRENTLY in stock. A cart item's stored
  // stock is a snapshot from whenever it was added/last touched — it can
  // go stale if that piece goes out of stock while the customer is
  // browsing elsewhere. Screens that silently poll for fresh stock (e.g.
  // Product Detail's 5-second refresh) call updateItemStock() below to
  // keep this current. Until then, this simply reflects the last known
  // stock for each item. ──
  int get totalQuantity => _items.values
      .where((item) =>
  item.product.quantity > 0 || item.product.posQuantity > 0)
      .fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.values
      .fold(0.0, (sum, item) => sum + item.product.price * item.quantity);

  int getQuantity(Product product) => _items[product.id]?.quantity ?? 0;

  /// Total quantity across all piece variants for a base product id
  int getPieceQuantity(String productId) {
    return _items.entries
        .where((e) => e.key == productId || e.key.startsWith('${productId}_piece_'))
        .fold(0, (sum, e) => sum + e.value.quantity);
  }

  bool contains(Product product) => _items.containsKey(product.id);

  /// Updates ONLY the stock fields on an item already in the cart, without
  /// touching the quantity the customer chose. Used by screens that
  /// silently poll for fresh stock (e.g. Product Detail's 5-second
  /// refresh) so cart-wide totals — like the floating cart badge via
  /// totalQuantity above — correctly stop counting an item the moment it
  /// goes out of stock, instead of staying frozen at whatever stock it
  /// had the moment it was originally added to the cart.
  void updateItemStock(String productId, int newStock) {
    final item = _items[productId];
    if (item == null) return;
    if (item.product.quantity == newStock &&
        item.product.posQuantity == newStock) {
      return; // no change — skip notifying listeners for nothing
    }
    final updatedProduct = item.product.copyWith(
      quantity:    newStock,
      posQuantity: newStock,
    );
    _items[productId] = CartItem(product: updatedProduct, quantity: item.quantity);
    notifyListeners();
    // Intentionally NOT calling _saveCart() here — this is a live stock
    // sync, not a customer action. Persisting on every 5-second poll
    // would be wasteful disk I/O. Actual customer actions (add/remove/
    // set quantity) still save normally, below.
  }

  // ── Load cart for a specific user (call after login & on app start) ─────────
  Future<void> loadForUser(String userId) async {
    _cartKey = 'mtl_cart_items_$userId';
    _items.clear();
    notifyListeners();
    await loadCart();
  }

  // ── Clear in-memory cart on logout (prefs data stays intact) ────────────────
  void clearForLogout() {
    _items.clear();
    _cartKey = 'mtl_cart_items_guest';
    notifyListeners();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_cartKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      _items.clear();
      for (final e in decoded) {
        final item = CartItem.fromJson(e as Map<String, dynamic>);
        _items[item.product.id] = item;
      }
      notifyListeners();
    } catch (e, stack) {
    }
  }

  void refreshCart() {
    notifyListeners();
  }
  Timer? _saveDebounce;

  Future<void> _saveCart() async {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final prefs   = await SharedPreferences.getInstance();
        final encoded = jsonEncode(
            _items.values.map((i) => i.toJson()).toList());
        await prefs.setString(_cartKey, encoded);
      } catch (e) {
      }
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ── Cart operations ──────────────────────────────────────────────────────────
  void addItem(Product product) {
    final stock = product.quantity > 0 ? product.quantity : product.posQuantity;
    final currentQty = _items[product.id]?.quantity ?? 0;

    if (stock <= 0) {
      onStockLimitReached?.call('Product is currently out of stock');
      return;
    }

    if (currentQty >= stock) {
      onStockLimitReached?.call(
        'Only $stock item${stock == 1 ? '' : 's'} available in stock',
      );
      return;
    }

    if (_items.containsKey(product.id)) {
      // ✅ replace stored product too, so price/stock stay fresh
      // instead of just bumping quantity on the stale cached product
      final newQty = _items[product.id]!.quantity + 1;
      _items[product.id] = CartItem(product: product, quantity: newQty);
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
    if (_items.containsKey(productId)) {
      final item  = _items[productId]!;
      final stock = item.product.quantity > 0
          ? item.product.quantity
          : item.product.posQuantity;

      if (stock <= 0) {
        onStockLimitReached?.call('Product is currently out of stock');
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
  }

  void decrementQuantity(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity <= 1) {
      _items.remove(productId);
    } else {
      _items[productId]!.quantity--;
    }
    notifyListeners();
    _saveCart();
  }

  // void clearCart() {
  void setQuantity(Product product, int qty) {
    if (qty <= 0) {
      _items.remove(product.id);
      notifyListeners();
      _saveCart();
      return;
    }
    // Always use the freshly-passed product's stock (not the stale stored one)
    final stock = product.quantity > 0 ? product.quantity : product.posQuantity;
    if (stock > 0 && qty > stock) {
      onStockLimitReached?.call(
        'Only $stock item${stock == 1 ? '' : 's'} available in stock',
      );
      qty = stock; // clamp to max stock
    }
    // Replace the entire CartItem so stored product stock is always fresh
    _items[product.id] = CartItem(product: product, quantity: qty);
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
    // intentionally NOT calling _saveCart() — prefs data stays intact
  }

  // ── Address helpers ──────────────────────────────────────────────────────────

  Future<AddressModel?> getDefaultAddress() => AddressStorage.getDefault();

  Future<List<AddressModel>> getSavedAddresses() => AddressStorage.load();
}