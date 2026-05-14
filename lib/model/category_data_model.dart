class CategoryDataProduct {
  final String productId;
  final String categoryId;
  final String name;
  final String image;
  final double price;
  final double wholesalePrice;
  final double additionalPrice;
  final String quantity;
  final String sku;
  final String parentId;
  final String piece;   // ← ADD THIS
  final List<Map<String, dynamic>> pieces;

  CategoryDataProduct({
    required this.productId,
    required this.categoryId,
    required this.name,
    required this.image,
    required this.price,
    required this.wholesalePrice,
    required this.additionalPrice,
    required this.quantity,
    required this.sku,
    required this.parentId,
    required this.piece,  // ← ADD THIS
    this.pieces = const [],
  });

  // ── Convenience getters ──────────────────────────────────────────────────
  String get imageUrl    => image;
  double get retailPrice => price;

  /// In stock when qty != 0
  bool get isInStock {
    final qty = int.tryParse(quantity.trim()) ?? 1;
    return qty > 0;
  }

  /// Discount % = (MRP - selling) / MRP * 100
  int get discountPercent {
    if (wholesalePrice <= 0 || wholesalePrice <= price) return 0;
    return ((wholesalePrice - price) / wholesalePrice * 100)
        .round()
        .clamp(0, 100);
  }

  factory CategoryDataProduct.fromJson(Map<String, dynamic> json) {
    final String resolvedQty = () {
      for (final key in ['pos_quentity', 'pos_quantity', 'quantity']) {
        final v = json[key]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return '0';
    }();

    // ── Find default piece (piece_default == 1, else highest price piece) ──
    final rawPiecesList = (json['pieces'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    Map<String, dynamic>? defaultPieceMap;
    for (final p in rawPiecesList) {
      if (p['piece_default']?.toString() == '1') {
        defaultPieceMap = p;
        break;
      }
    }
    // No piece_default flag → pick piece with highest price
    if (defaultPieceMap == null && rawPiecesList.isNotEmpty) {
      defaultPieceMap = rawPiecesList.reduce((a, b) {
        final aPrice = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final bPrice = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return aPrice >= bPrice ? a : b;
      });
    }

    final double piecePrice = double.tryParse(defaultPieceMap?['price']?.toString()         ?? '0') ?? 0;
    final double pieceSp    = double.tryParse(defaultPieceMap?['special_price']?.toString() ?? '0') ?? 0;
    final bool   pieceHasOffer = pieceSp > 0 && pieceSp < piecePrice;

    // ── Product-level price ──────────────────────────────────────────
    final double rawPrice     = double.tryParse(json['price']?.toString()         ?? '0') ?? 0;
    final double specialPrice = double.tryParse(json['special_price']?.toString() ?? '0') ?? 0;
    final bool   productHasOffer = specialPrice > 0 && specialPrice < rawPrice;

    // ── Resolve final display price and original price ───────────────
    final double finalPrice;
    final double finalWholesale;

    if (pieceHasOffer) {
      // Default piece has valid offer — use it
      finalPrice     = pieceSp;
      finalWholesale = piecePrice;
    } else if (piecePrice > 0 && productHasOffer) {
      // Piece exists but no piece offer; product-level has offer
      finalPrice     = specialPrice;
      finalWholesale = rawPrice;
    } else if (piecePrice > 0) {
      // Piece exists, no offer anywhere
      finalPrice     = piecePrice;
      finalWholesale = 0;
    } else if (productHasOffer) {
      // No piece, product-level offer
      finalPrice     = specialPrice;
      finalWholesale = rawPrice;
    } else {
      // No offer anywhere
      finalPrice     = rawPrice;
      finalWholesale = 0;
    }

    // ── Weight label from default piece ─────────────────────────────
    final String pieceLabel = defaultPieceMap?['piece']?.toString() ?? '';

    return CategoryDataProduct(
      productId:       json['product_id']?.toString() ?? '',
      categoryId:      json['category_id']?.toString() ?? '',
      name:            json['name']?.toString() ?? '',
      image:           json['image']?.toString() ?? '',
      price:           finalPrice,
      wholesalePrice:  finalWholesale,
      additionalPrice: double.tryParse(json['additional_price']?.toString() ?? '0') ?? 0,
      quantity:        resolvedQty,
      sku:             json['sku']?.toString() ?? '',
      parentId:        json['parent_id']?.toString() ?? '',
      piece:           pieceLabel.isNotEmpty
          ? pieceLabel
          : (json['piece']?.toString().isNotEmpty == true
          ? json['piece'].toString()
          : json['barcode_type']?.toString() ?? ''),
      pieces:          rawPiecesList,
    );
  }

  @override
  String toString() =>
      'CategoryDataProduct(id=$productId, name="$name", qty=$quantity, price=$price, mrp=$wholesalePrice)';
}

// ─────────────────────────────────────────────────────────────────────────────

class CategoryDataSubcategory {
  final String categoryId;
  final String parentId;
  final String name;
  final String image;
  final List<CategoryDataProduct> products;

  CategoryDataSubcategory({
    required this.categoryId,
    required this.parentId,
    required this.name,
    required this.image,
    required this.products,
  });

  String get imageUrl     => image;
  bool   get hasProducts  => products.isNotEmpty;
  int    get productCount => products.length;

  factory CategoryDataSubcategory.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = (rawProducts is List)
        ? rawProducts
        .map((p) => CategoryDataProduct.fromJson(p as Map<String, dynamic>))
        .toList()
        : <CategoryDataProduct>[];

    return CategoryDataSubcategory(
      categoryId: json['category_id']?.toString() ?? '',
      parentId:   json['parent_id']?.toString()   ?? '',
      name:       json['name']?.toString()         ?? '',
      image:      json['image']?.toString()        ?? '',
      products:   products,
    );
  }

  get subcategories => null;

  @override
  String toString() =>
      'CategoryDataSubcategory(id=$categoryId, name="$name", products=${products.length})';
}

// ─────────────────────────────────────────────────────────────────────────────

class CategoryDataModel {
  final List<CategoryDataProduct>     parentProducts;
  final List<CategoryDataSubcategory> subcategories;

  CategoryDataModel({
    required this.parentProducts,
    required this.subcategories,
  });

  factory CategoryDataModel.fromJson(Map<String, dynamic> json) {
    return CategoryDataModel(
      parentProducts: (json['products'] as List? ?? [])
          .map((p) => CategoryDataProduct.fromJson(p as Map<String, dynamic>))
          .toList(),
      subcategories: (json['subcategories'] as List? ?? [])
          .map((s) => CategoryDataSubcategory.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}