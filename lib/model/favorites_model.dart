import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_model.dart';
import '../services/api_config_service.dart';

class FavoritesModel extends ChangeNotifier {

  String _prefsKey = 'user_favorites_guest';

  final List<Product> _favorites = [];

  FavoritesModel();

  List<Product> get favoriteList => List.unmodifiable(_favorites);
  int           get count        => _favorites.length;

  bool isFavorite(String productId) =>
      _favorites.any((p) => p.id == productId);


  Future<void> loadForUser(String userId) async {
    final newKey = 'user_favorites_$userId';

    _favorites.clear();
    _prefsKey = newKey;

    await _loadFromPrefs();
  }

  void onLogout() {
    _favorites.clear();
    _prefsKey = 'user_favorites_guest';
    notifyListeners();
  }

  void clear() {
    _favorites.clear();
    _prefsKey = 'user_favorites_guest';
    notifyListeners();
  }

  void toggleFavorite(Product product) {
    final idx = _favorites.indexWhere((p) => p.id == product.id);
    if (idx >= 0) {
      _favorites.removeAt(idx);
    } else {
      final needsUrl = product.imageUrl.isEmpty &&
          product.image.isNotEmpty &&
          product.image != 'no_image.png';
      final resolved = needsUrl
          ? product.copyWith(imageUrl: '${ApiConfig.imageBase}${product.image}')
          : product;
      _favorites.add(resolved);
    }
    notifyListeners();
    _saveToPrefs();
  }

  Future<void> removeById(String productId) async {
    _favorites.removeWhere((p) => p.id == productId);
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> syncWithBackend(List<String> liveProductIds, {List<Product>? liveProducts}) async {
    // Never remove favourites automatically — only update stock status
    if (liveProducts != null) {
      bool changed = false;
      for (int i = 0; i < _favorites.length; i++) {
        final live = liveProducts.where((p) => p.id == _favorites[i].id).toList();
        if (live.isNotEmpty) {
          _favorites[i] = _favorites[i].copyWith(
            quantity:    live.first.quantity,
            posQuantity: live.first.posQuantity,
            price:              live.first.price,
            originalPrice:      live.first.originalPrice,
            discountPercentage: live.first.discountPercentage,
            weight:             live.first.weight,
          );
          changed = true;
        }
      }
      if (changed) {
        notifyListeners();
        await _saveToPrefs();
      }
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _favorites.map((p) => _productToJson(p)).toList(),
      );
      await prefs.setString(_prefsKey, encoded);
    } catch (e) { }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .map((e) => _productFromJson(e as Map<String, dynamic>))
          .toList();

      for (final p in loaded) {
        if (!_favorites.any((f) => f.id == p.id)) {
          _favorites.add(p);
        }
      }
      notifyListeners();
    } catch (e) { }
  }

  Map<String, dynamic> _productToJson(Product p) => {
    'id':                 p.id,
    'name':               p.name,
    'price':              p.price,
    'originalPrice':      p.originalPrice,
    'image':              p.image,
    'imageUrl':           p.imageUrl,
    'category':           p.category,
    'weight':             p.weight,
    'discountPercentage': p.discountPercentage,
    'quantity':           p.quantity,        // ← ADD THIS
    'posQuantity':        p.posQuantity,   // ← ADD THIS
  };

  Product _productFromJson(Map<String, dynamic> j) {
    final raw      = j['image']    as String? ?? '';
    final savedUrl = j['imageUrl'] as String? ?? '';

    final bool urlIsValid = savedUrl.startsWith('http://') ||
        savedUrl.startsWith('https://');

    final String imageUrl = urlIsValid
        ? savedUrl
        : (raw.isNotEmpty && raw != 'no_image.png')
        ? '${ApiConfig.imageBase}$raw'
        : '';

    return Product(
      id:                 j['id']                  as String,
      name:               j['name']                as String,
      price:              (j['price']              as num).toDouble(),
      originalPrice:      (j['originalPrice']      as num).toDouble(),
      image:              raw,
      imageUrl:           imageUrl,
      category:           j['category']            as String? ?? '',
      weight:             j['weight']              as String? ?? '',
      discountPercentage: (j['discountPercentage'] as num).toDouble(),
      quantity:           (j['quantity']           as num?)?.toInt() ?? 1,  // ← ADD THIS
      posQuantity:        (j['posQuantity']        as num?)?.toInt() ?? 0,  // ← ADD THIS
    );
  }
}