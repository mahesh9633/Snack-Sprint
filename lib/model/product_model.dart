class Product {
  final String id;
  final String name;
  final double price;
  final double originalPrice;
  final String image;       // raw path from API
  final String imageUrl;    // full validated URL (may be '' if no valid image)
  final String category;
  final String subCategory;
  final String weight;
  final String sku;
  final String deliveryTime;
  final double discountPercentage;
  final bool   isVeg;
  final String tag;
  final String description;
  final List<String> highlights;
  final int    quantity;
  final int posQuantity;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.originalPrice,
    this.image              = '',
    this.imageUrl           = '',
    required this.category,
    this.subCategory        = '',
    this.weight             = '',
    this.sku                = '',
    this.deliveryTime       = '',
    this.discountPercentage = 0,
    this.isVeg              = true,
    this.tag                = '',
    this.description        = '',
    this.highlights         = const [],
    this.quantity           = 0,
    this.posQuantity = 0,
  });
  // ── copyWith ──────────────────────────────────────────────────────────────

  Product copyWith({
    String?       id,
    String?       name,
    double?       price,
    double?       originalPrice,
    String?       image,
    String?       imageUrl,
    String?       category,
    String?       subCategory,
    String?       weight,
    String?       sku,
    String?       deliveryTime,
    double?       discountPercentage,
    bool?         isVeg,
    String?       tag,
    String?       description,
    List<String>? highlights,
    int?          quantity,
    int? posQuantity,
  }) {
    return Product(
      id:                 id                 ?? this.id,
      name:               name               ?? this.name,
      price:              price              ?? this.price,
      originalPrice:      originalPrice      ?? this.originalPrice,
      image:              image              ?? this.image,
      imageUrl:           imageUrl           ?? this.imageUrl,
      category:           category           ?? this.category,
      subCategory:        subCategory        ?? this.subCategory,
      weight:             weight             ?? this.weight,
      sku:                sku                ?? this.sku,
      deliveryTime:       deliveryTime       ?? this.deliveryTime,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      isVeg:              isVeg              ?? this.isVeg,
      tag:                tag                ?? this.tag,
      description:        description        ?? this.description,
      highlights:         highlights         ?? this.highlights,
      quantity:           quantity           ?? this.quantity,
      posQuantity: posQuantity ?? this.posQuantity,
    );
  }

  // ── Serialisation (local cache / SharedPreferences) ──────────────────────────

  Map<String, dynamic> toJson() => {
    'id':                 id,
    'name':               name,
    'price':              price,
    'originalPrice':      originalPrice,
    'image':              image,
    'imageUrl':           imageUrl,
    'category':           category,
    'subCategory':        subCategory,
    'weight':             weight,
    'sku':                sku,
    'deliveryTime':       deliveryTime,
    'discountPercentage': discountPercentage,
    'isVeg':              isVeg,
    'tag':                tag,
    'description':        description,
    'highlights':         highlights,
    'quantity':           quantity,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id:                  json['id']?.toString()                            ?? '',
    name:                json['name']?.toString()                          ?? '',
    price:               (json['price']              as num?)?.toDouble()  ?? 0.0,
    originalPrice:       (json['originalPrice']      as num?)?.toDouble()  ?? 0.0,
    image:               json['image']?.toString()                         ?? '',
    imageUrl:            json['imageUrl']?.toString()                      ?? '',
    category:            json['category']?.toString()                      ?? '',
    subCategory:         json['subCategory']?.toString()                   ?? '',
    weight:              json['weight']?.toString()                        ?? '',
    sku:                 json['sku']?.toString()                           ?? '',
    deliveryTime:        json['deliveryTime']?.toString()                  ?? '',
    discountPercentage:  (json['discountPercentage'] as num?)?.toDouble()  ?? 0.0,
    isVeg:               json['isVeg'] as bool?                            ?? true,
    tag:                 json['tag']?.toString()                           ?? '',
    description:         json['description']?.toString()                   ?? '',
    highlights:          (json['highlights'] as List<dynamic>?)
        ?.map((e) => e.toString()).toList()            ?? [],
    quantity:            (json['quantity'] as num?)?.toInt()               ?? 0,
  );

  factory Product.fromCategoryJson(
      Map<String, dynamic> json, {
        String categoryName = '',
        required String Function(String?) buildUrl, // pass buildImageUrl
      }) {
    final rawImage    = json['image']?.toString() ?? '';
    final basePrice   = double.tryParse(json['price']?.toString()         ?? '0') ?? 0.0;
    final specialRaw  = json['special_price']?.toString() ?? '';
    final specialPrice = double.tryParse(specialRaw) ?? 0.0;

    // If special_price is set and > 0, it is the selling price; base is MRP
    final double price         = specialPrice > 0 ? specialPrice : basePrice;
    final double originalPrice = specialPrice > 0 ? basePrice    : basePrice;

    final qty = int.tryParse(
        json['pos_quentity']?.toString() ?? '0') ?? 0;

    return Product(
      id:                 json['product_id']?.toString() ?? '',
      name:               json['name']?.toString()        ?? '',
      price:              price,
      originalPrice:      originalPrice,
      image:              rawImage,
      imageUrl:           buildUrl(rawImage),   // safe — never bare filename
      category:           categoryName.isNotEmpty
          ? categoryName
          : (json['category_id']?.toString() ?? ''),
      weight: (() {
        for (final key in ['piece', 'unit', 'weight', 'net_qty', 'barcode_type']) {
          final val = json[key]?.toString() ?? '';
          if (val.isNotEmpty && val != '0' && val != '0.000' && val != 'null') return val;
        }
        return '';
      })(),
      sku:                '',
      deliveryTime:       '15 mins',
      discountPercentage: 0,
      isVeg:              true,
      quantity:           qty < 0 ? 0 : qty,
    );
  }

  // ── Factory: getProductDetails / getInitialData "product" object ──────────

  factory Product.fromApiMap(
      Map<String, dynamic> json, {
        required String Function(String?) buildUrl,
      }) {

    final rawImage     = json['image']?.toString() ?? '';
    final basePrice    = double.tryParse(json['price']?.toString()         ?? '0') ?? 0.0;
    final specialPrice = double.tryParse(json['special_price']?.toString() ?? '0') ?? 0.0;
    final bool   hasOffer = specialPrice > 0 && specialPrice < basePrice;
    final double price    = hasOffer ? specialPrice : basePrice;
    final posQty = int.tryParse(json['pos_quentity']?.toString() ?? '0') ?? 0;
    final qty    = int.tryParse(json['quantity']?.toString() ?? '0') ?? 0;
    final tag       = (json['r_tag']?.toString() ?? '').isNotEmpty
        ? json['r_tag'].toString()
        : (json['w_tag']?.toString() ?? '');

    return Product(
      id:            json['product_id']?.toString()    ?? '',
      name:          json['name']?.toString()          ?? '',
      price:         price,
      // originalPrice: addPrice > 0 ? addPrice : price,
      originalPrice: hasOffer ? basePrice : price,
      image:         rawImage,
      imageUrl:      buildUrl(rawImage),
      category:      json['category']?.toString()      ?? '',
      subCategory:   json['sub_category']?.toString()  ?? '',
      // weight:        json['weight']?.toString()        ?? '',
      weight: (() {
        for (final key in ['piece', 'unit', 'weight', 'net_qty', 'barcode_type']) {
          final val = json[key]?.toString() ?? '';
          if (val.isNotEmpty && val != '0' && val != '0.000' && val != 'null') return val;
        }
        return '';
      })(),
      sku:           json['sku']?.toString()           ?? '',
      deliveryTime:  json['delivery_time']?.toString() ?? '15 mins',
      isVeg:         (json['is_veg']?.toString()       ?? '1') == '1',
      tag:           tag,
      description:   json['description']?.toString()  ?? '',
      highlights:    (json['highlights'] as List<dynamic>?)
          ?.map((e) => e.toString()).toList() ?? [],
      quantity: qty < 0 ? 0 : qty,
      posQuantity: posQty < 0 ? 0 : posQty,
    );
  }

  // ── Computed helpers ──────────────────────────────────────────────────────────

  int get computedDiscount {
    if (discountPercentage > 0) return discountPercentage.round();
    if (originalPrice <= 0 || originalPrice <= price) return 0;
    return (((originalPrice - price) / originalPrice) * 100).round();
  }

  double get savings => originalPrice > price ? originalPrice - price : 0;
  bool get isInStock => posQuantity > 0;

  int get deliveryMinutes {
    final match = RegExp(r'\d+').firstMatch(deliveryTime);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  // bool get isInStock => quantity > 0;

  String get displayWeight {
    if (weight.isNotEmpty &&
        weight != id &&
        !RegExp(r'^\d{5,}$').hasMatch(weight) &&
        !RegExp(r'^0+(\.0+)?$').hasMatch(weight.trim())) {
      return weight;
    }
    return '';
  }
}

