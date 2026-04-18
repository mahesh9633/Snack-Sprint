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

  // ── Per-user key (set on login, reset on logout) ───────────────────────────
  String _cartKey = 'mtl_cart_items_guest';

  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => Map.unmodifiable(_items);

  int get totalQuantity =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.values
      .fold(0.0, (sum, item) => sum + item.product.price * item.quantity);

  int getQuantity(Product product) => _items[product.id]?.quantity ?? 0;

  bool contains(Product product) => _items.containsKey(product.id);

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

  Future<void> _saveCart() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
          _items.values.map((i) => i.toJson()).toList());
      await prefs.setString(_cartKey, encoded);
    } catch (e) {
    }
  }

  // ── Cart operations ──────────────────────────────────────────────────────────

  void addItem(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity++;
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
      _items[productId]!.quantity++;
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
