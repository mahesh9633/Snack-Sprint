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
  });

  // ── Convenience getters ──────────────────────────────────────────────────
  String get imageUrl    => image;
  double get retailPrice => price;

  /// In stock when qty != 0
  bool get isInStock {
    final qty = int.tryParse(quantity) ?? 0;
    return qty != 0;
  }

  /// Discount % = (MRP - selling) / MRP * 100
  int get discountPercent {
    if (wholesalePrice <= 0 || wholesalePrice <= price) return 0;
    return ((wholesalePrice - price) / wholesalePrice * 100)
        .round()
        .clamp(0, 100);
  }

  factory CategoryDataProduct.fromJson(Map<String, dynamic> json) {
    // quantity field name varies — handle all variants (API has typo "pos_quentity")
    final String resolvedQty =
    json['pos_quentity']?.toString().isNotEmpty == true
        ? json['pos_quentity'].toString()
        : json['pos_quantity']?.toString().isNotEmpty == true
        ? json['pos_quantity'].toString()
        : json['quantity']?.toString().isNotEmpty == true
        ? json['quantity'].toString()
        : '1';

    // API sends: "price" = MRP,  "special_price" = offer price
    final double rawPrice     = double.tryParse(json['price']?.toString()         ?? '0') ?? 0;
    final double specialPrice = double.tryParse(json['special_price']?.toString() ?? '0') ?? 0;
    final bool   hasOffer     = specialPrice > 0 && specialPrice < rawPrice;

    return CategoryDataProduct(
      productId:       json['product_id']?.toString() ?? '',
      categoryId:      json['category_id']?.toString() ?? '',
      name:            json['name']?.toString() ?? '',
      image:           json['image']?.toString() ?? '',
      price:           hasOffer ? specialPrice : rawPrice,  // ← offer price as selling price
      wholesalePrice:  hasOffer ? rawPrice     : 0,          // ← MRP shown as strikethrough
      additionalPrice: double.tryParse(json['additional_price']?.toString() ?? '0') ?? 0,
      quantity:        resolvedQty,
      sku:             json['sku']?.toString() ?? '',
      parentId:        json['parent_id']?.toString() ?? '',
      piece:           (json['piece']?.toString().isNotEmpty == true
          ? json['piece'].toString()
          : json['barcode_type']?.toString() ?? ''),
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