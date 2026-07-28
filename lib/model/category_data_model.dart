

import '../utils/stock_resolver.dart';

class CategoryDataProduct {
  final String productId;
  final String categoryId;
  final String name;
  final String image;
  final String defaultImage;   // ← NEW: default piece image or product image
  final double price;
  final double wholesalePrice;
  final double additionalPrice;
  final String quantity;
  final String sku;
  final String parentId;
  final String piece;
  final List<Map<String, dynamic>> pieces;
  final bool   isCombo;

  CategoryDataProduct({
    required this.productId,
    required this.categoryId,
    required this.name,
    required this.image,
    required this.defaultImage,
    required this.price,
    required this.wholesalePrice,
    required this.additionalPrice,
    required this.quantity,
    required this.sku,
    required this.parentId,
    required this.piece,
    this.pieces  = const [],
    this.isCombo = false,
  });

  // ── Convenience getters ──────────────────────────────────────────────────
  String get imageUrl    => image;
  double get retailPrice => price;

  /// In stock when qty != 0.
  /// `quantity` is already fully resolved (via the shared resolver) at
  /// parse time — it reflects stock_status/subtract/quantity together,
  /// the same way Home, Product Detail, and every other screen do.
  bool get isInStock {
    final qty = int.tryParse(quantity.trim()) ?? 0;
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
    // ── SHARED resolver — same function Home and Product Detail use.
    //    Checks stock_status → subtract → quantity (both field spellings),
    //    and defaults to IN STOCK (1) only when data is genuinely ambiguous,
    //    matching every other screen instead of defaulting to 0 here. ──
    final int resolvedQtyInt = resolveProductQuantity(json);
    final String resolvedQty = resolvedQtyInt.toString();
    final bool   productIsCombo = resolveIsCombo(json);

    // ── Find default piece (piece_default == 1, else highest price piece) ──
    final rawPiecesList = (json['pieces'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // ── Resolve and NORMALIZE piece-level stock right here, at parse time.
    //    We write the resolved value back into a standard 'pos_quantity' key
    //    on each piece map, so whatever downstream code reads that key
    //    (e.g. ProductPiece.fromJson) always gets the correctly-resolved
    //    number — regardless of which spelling the backend originally used,
    //    and with the same combo fallback rule as every other screen. ──
    for (final p in rawPiecesList) {
      final resolvedPieceStock = resolvePieceStock(
        p,
        productIsCombo: productIsCombo,
        productLevelQty: resolvedQtyInt,
      );
      p['pos_quantity'] = resolvedPieceStock.toString();
    }

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

    // Resolve display image: prefer default piece image, fall back to product image
    final String productRawImage = json['image']?.toString() ?? '';
    final String pieceRawImage   = defaultPieceMap?['image']?.toString() ?? '';
    final String resolvedImage   = (pieceRawImage.isNotEmpty &&
        pieceRawImage != 'no_image.png')
        ? pieceRawImage
        : productRawImage;

    return CategoryDataProduct(
      productId:       json['product_id']?.toString() ?? '',
      categoryId:      json['category_id']?.toString() ?? '',
      name:            json['name']?.toString() ?? '',
      image:           productRawImage,
      defaultImage:    resolvedImage,
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
      isCombo:         productIsCombo,
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