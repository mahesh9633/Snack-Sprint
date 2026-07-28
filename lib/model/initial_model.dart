

import 'dart:convert';

import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../widgets/piece_selector_sheet.dart';
import '../utils/stock_resolver.dart';

final String base = ApiConfig.imageBase;

// ─── ApiProduct ───────────────────────────────────────────────────────────────
class ApiProduct {
  final String productId;
  final String name;
  final String sku;
  final String image;
  final String defaultImage;
  final String category;
  final String unit;
  final double retailPrice;
  final double wholesalePrice;
  final double specialPrice;
  final int    quantity;
  final bool   isCombo;
  final List<ProductPiece> pieces;

  const ApiProduct({
    required this.productId,
    required this.name,
    required this.sku,
    required this.image,
    required this.defaultImage,  // ← NEW
    required this.category,
    required this.unit,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.specialPrice,
    required this.quantity,
    this.isCombo = false,
    this.pieces  = const <ProductPiece>[],
  });

  String get imageUrl {
    // Use default piece image if available, else fall back to product image
    final src = defaultImage.isNotEmpty ? defaultImage : image;
    if (src.isEmpty || src == 'no_image.png') return '';
    if (src.startsWith('http')) return src;
    return '$kImgBase$src';
  }

  bool get inStock => quantity > 0;

  double get discountPercent {
    if (wholesalePrice <= 0 || wholesalePrice <= retailPrice) return 0;
    return ((wholesalePrice - retailPrice) / wholesalePrice * 100)
        .clamp(0.0, 100.0);
  }

  factory ApiProduct.fromJson(Map<String, dynamic> j) {
    final rawPieces = (j['pieces'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // ── SHARED resolver — same functions CategoryDataProduct uses.
    //    Computed ONCE here, then reused for both product-level quantity
    //    and every piece's stock, so Home and Trending/Category always agree. ──
    final int  quantity       = resolveProductQuantity(j);
    final bool productIsCombo = resolveIsCombo(j) ||
        rawPieces.any((p) => (p['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes');

    // ── Convert to ProductPiece objects (carries minQuantity + isCombo) ──
    final List<ProductPiece> parsedPieces = rawPieces.map((p) {
      final piecePrice = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
      final pieceSp    = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0.0;
      final minQtyInt  = int.tryParse(p['min_quantity']?.toString() ?? '0') ?? 0;
      final pieceName  = p['piece']?.toString() ?? '';
      final isCombo    = productIsCombo ||
          (p['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes';
      final label      = (minQtyInt > 1 && pieceName.isNotEmpty)
          ? '$pieceName × $minQtyInt'
          : pieceName;

      final stock = resolvePieceStock(
        p,
        productIsCombo:  productIsCombo,
        productLevelQty: quantity,
      );

      return ProductPiece(
        rowId: p['id']?.toString() ?? '',
        pieceId: p['piece_id']?.toString() ?? '',
        label: label,
        price: piecePrice,
        specialPrice: pieceSp,
        image: p['image']?.toString() ?? '',
        minQuantity: minQtyInt,
        isCombo: isCombo,
        stock: stock,
      );
    }).toList();

    // ── Find default piece (piece_default == 1, else highest price piece) ──
    Map<String, dynamic>? defaultPiece;
    for (final p in rawPieces) {
      if (p['piece_default']?.toString() == '1') {
        defaultPiece = p;
        break;
      }
    }
    // No piece_default flag → pick piece with highest price (same as category)
    if (defaultPiece == null && rawPieces.isNotEmpty) {
      defaultPiece = rawPieces.reduce((a, b) {
        final aP = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
        final bP = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
        return aP >= bP ? a : b;
      });
    }

    final double piecePrice = double.tryParse(defaultPiece?['price']?.toString()         ?? '0') ?? 0;
    final double pieceSp    = double.tryParse(defaultPiece?['special_price']?.toString() ?? '0') ?? 0;
    final bool   pieceHasOffer = pieceSp > 0 && pieceSp < piecePrice;

    final double rawPrice     = double.tryParse(j['price']?.toString()         ?? '0') ?? 0;
    final double specialPrice = double.tryParse(j['special_price']?.toString() ?? '0') ?? 0;
    final bool   productHasOffer = specialPrice > 0 && specialPrice < rawPrice;

    // ── Resolve price — IDENTICAL to CategoryDataProduct.fromJson ────────
    final double resolvedRetailPrice;
    final double resolvedWholesalePrice;

    if (pieceHasOffer) {
      resolvedRetailPrice    = pieceSp;
      resolvedWholesalePrice = piecePrice;
    } else if (piecePrice > 0 && productHasOffer) {
      resolvedRetailPrice    = specialPrice;
      resolvedWholesalePrice = rawPrice;
    } else if (piecePrice > 0) {
      resolvedRetailPrice    = piecePrice;
      resolvedWholesalePrice = 0;
    } else if (productHasOffer) {
      resolvedRetailPrice    = specialPrice;
      resolvedWholesalePrice = rawPrice;
    } else {
      resolvedRetailPrice    = rawPrice;
      resolvedWholesalePrice = 0;
    }

    // ── Unit label — MUST come from the same defaultPiece used for price ──
    final String pieceLabel = defaultPiece?['piece']?.toString() ?? '';
    final String unit = pieceLabel.isNotEmpty && pieceLabel != 'null'
        ? pieceLabel
        : (j['piece']?.toString()?.isNotEmpty == true
        ? j['piece'].toString()
        : j['barcode_type']?.toString() ?? '');

    // Resolve display image: prefer default piece image, fall back to product image
    final String productRawImage = j['image']?.toString() ?? '';
    final String pieceRawImage   = defaultPiece?['image']?.toString() ?? '';
    final String resolvedImage   = (pieceRawImage.isNotEmpty &&
        pieceRawImage != 'no_image.png')
        ? pieceRawImage
        : productRawImage;

    return ApiProduct(
      productId:      j['product_id']?.toString() ?? '',
      name:           j['name']?.toString()        ?? '',
      sku:            j['sku']?.toString()          ?? '',
      image:          productRawImage,              // ← keep original
      defaultImage:   resolvedImage,                // ← piece image or product image
      category:       j['category']?.toString()     ?? '',
      unit:           unit,
      specialPrice:   specialPrice,
      retailPrice:    resolvedRetailPrice,
      wholesalePrice: resolvedWholesalePrice,
      quantity:       quantity,
      isCombo:        productIsCombo,
      pieces:         parsedPieces,
    );
  }
}

// ─── ApiSubcategory ──────────────────────────────────────────────────────────
class ApiSubcategory {
  final String categoryId;
  final String parentId;
  final String name;
  final String image;

  const ApiSubcategory({
    required this.categoryId,
    required this.parentId,
    required this.name,
    required this.image,
  });

  String get imageUrl {
    if (image.isEmpty || image == 'no_image.png') return '';
    if (image.startsWith('http')) return image;
    return '$kImgBase$image';
  }

  factory ApiSubcategory.fromJson(Map<String, dynamic> j) => ApiSubcategory(
    categoryId: j['category_id']?.toString() ?? '',
    parentId:   j['parent_id']?.toString()   ?? '',
    name:       j['name']?.toString()         ?? '',
    image:      j['image']?.toString()        ?? '',
  );
}

// ─── ApiCategory ─────────────────────────────────────────────────────────────
class ApiCategory {
  final String categoryId;
  final String name;
  final String image;
  final List<ApiSubcategory> subcategories;

  const ApiCategory({
    required this.categoryId,
    required this.name,
    required this.image,
    this.subcategories = const [],
  });

  String get imageUrl {
    if (image.isEmpty || image == 'no_image.png') return '';
    if (image.startsWith('http')) return image;
    return '$kImgBase$image';
  }

  factory ApiCategory.fromJson(Map<String, dynamic> j) => ApiCategory(
    categoryId: j['category_id']?.toString() ?? '',
    name:       j['name']?.toString()         ?? '',
    image:      j['image']?.toString()        ?? '',
    subcategories: (j['subcategories'] as List? ?? [])
        .map((s) => ApiSubcategory.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

// ─── ApiOffer ─────────────────────────────────────────────────────────────────
class ApiOffer {
  final String categoryId;
  final String name;
  final List<ApiProduct> products;

  const ApiOffer({
    required this.categoryId,
    required this.name,
    required this.products,
  });

  factory ApiOffer.fromJson(Map<String, dynamic> j) => ApiOffer(
    categoryId: j['category_id']?.toString() ?? '',
    name:       j['name']?.toString()         ?? '',
    products: (j['products'] as List? ?? [])
        .map((p) => ApiProduct.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

// ─── InitialDataModel ─────────────────────────────────────────────────────────
class InitialDataModel {
  final List<ApiProduct>  randomProducts;
  final List<ApiProduct>  comboProducts;
  final List<ApiCategory> categories;
  final List<ApiOffer>    offers;

  const InitialDataModel({
    required this.randomProducts,
    required this.comboProducts,
    required this.categories,
    required this.offers,
  });

  factory InitialDataModel.fromJson(Map<String, dynamic> j) =>
      InitialDataModel(
        randomProducts: (j['random_products'] as List? ?? [])
            .map((p) => ApiProduct.fromJson(p as Map<String, dynamic>))
            .toList(),
        comboProducts: (j['combo_products'] as List? ?? [])
            .map((p) => ApiProduct.fromJson(p as Map<String, dynamic>))
            .toList(),
        categories: (j['categories'] as List? ?? [])
            .map((c) => ApiCategory.fromJson(c as Map<String, dynamic>))
            .toList(),
        offers: (j['offers'] as List? ?? [])
            .map((o) => ApiOffer.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}