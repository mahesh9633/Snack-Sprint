import '../services/api_config_service.dart';
import '../services/api_server.dart';

final String base = ApiConfig.imageBase;

// ─── ApiProduct ───────────────────────────────────────────────────────────────
class ApiProduct {
  final String productId;
  final String name;
  final String sku;
  final String image;
  final String category;
  final String unit;
  final double retailPrice;
  final double wholesalePrice;
  final double specialPrice;
  final int    quantity;

  const ApiProduct({
    required this.productId,
    required this.name,
    required this.sku,
    required this.image,
    required this.category,
    required this.unit,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.specialPrice,
    required this.quantity,
  });

  String get imageUrl {
    if (image.isEmpty || image == 'no_image.png') return '';
    if (image.startsWith('http')) return image;
    return '$kImgBase$image';
  }

  bool get inStock => quantity > 0;

  double get discountPercent {
    final effectivePrice = (specialPrice > 0 && specialPrice < retailPrice)
        ? specialPrice
        : retailPrice;
    if (retailPrice > effectivePrice && retailPrice > 0) {
      return ((retailPrice - effectivePrice) / retailPrice * 100)
          .clamp(0.0, 100.0);
    }
    return 0;
  }

  factory ApiProduct.fromJson(Map<String, dynamic> j) => ApiProduct(
    productId:      j['product_id']?.toString()         ?? '',
    name:           j['name']?.toString()                ?? '',
    sku:            j['sku']?.toString()                 ?? '',
    image:          j['image']?.toString()               ?? '',
    category:       j['category']?.toString() ?? '',
    // unit:           j['unit']?.toString() ?? '',
    unit: (() {
      for (final key in ['piece', 'unit', 'weight', 'net_qty', 'barcode_type']) {
        final val = j[key]?.toString() ?? '';
        if (val.isNotEmpty && val != '0' && val != '0.000' && val != 'null') return val;
      }
      return '';
    })(),
    retailPrice:    double.tryParse(j['price']?.toString()           ?? '') ?? 0.0,
    wholesalePrice: double.tryParse(j['wholesale_price']?.toString() ?? '') ?? 0.0,
    specialPrice:   double.tryParse(j['special_price']?.toString()   ?? '') ?? 0.0,
    quantity: int.tryParse(
        (j['pos_quentity']?.toString().isNotEmpty == true
            ? j['pos_quentity']
            : j['pos_quantity']?.toString().isNotEmpty == true
            ? j['pos_quantity']
            : j['quantity'])?.toString() ?? '') ?? 0,
  );
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
  final List<ApiCategory> categories;
  final List<ApiOffer>    offers;

  const InitialDataModel({
    required this.randomProducts,
    required this.categories,
    required this.offers,
  });

  factory InitialDataModel.fromJson(Map<String, dynamic> j) =>
      InitialDataModel(
        randomProducts: (j['random_products'] as List? ?? [])
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