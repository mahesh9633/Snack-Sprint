

  import '../widgets/piece_selector_sheet.dart';

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
    final List<ProductPiece> pieces;   // <-- new field
    final bool   isCombo;

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
      this.pieces = const [],
      this.isCombo            = false,
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
      List<ProductPiece>? pieces,
      bool?               isCombo,
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
        posQuantity: posQuantity               ?? this.posQuantity,
        pieces:             pieces             ?? this.pieces,
        isCombo:            isCombo            ?? this.isCombo,
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
      'posQuantity':        posQuantity,
      'isCombo':            isCombo,
      'pieces': pieces.map((p) => {
        'id':            p.rowId,
        'piece_id':      p.pieceId,
        'piece':         p.label,
        'price':         p.price.toString(),
        'special_price': p.specialPrice.toString(),
        'image':         p.image,
        'min_quantity':  p.minQuantity.toString(),
        'is_combo':      p.isCombo ? 'Yes' : 'No',
        'pos_quantity':  p.stock.toString(),
      }).toList(),
    };

    factory Product.fromJson(Map<String, dynamic> json) {
      double parseDouble(dynamic value) {
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? '0') ?? 0.0;
      }

      int parseInt(dynamic value) {
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '0') ?? 0;
      }

      bool parseBool(dynamic value, {bool defaultValue = false}) {
        if (value is bool) return value;

        final text = value?.toString().trim().toLowerCase();

        if (text == 'true' || text == '1' || text == 'yes') {
          return true;
        }

        if (text == 'false' || text == '0' || text == 'no') {
          return false;
        }

        return defaultValue;
      }

      return Product(
        id: json['id']?.toString() ??
            json['product_id']?.toString() ??
            '',
        name: json['name']?.toString() ?? '',
        price: parseDouble(json['price']),
        originalPrice: parseDouble(
          json['originalPrice'] ?? json['original_price'],
        ),
        image: json['image']?.toString() ??
            json['product_image']?.toString() ??
            '',
        imageUrl: json['imageUrl']?.toString() ??
            json['image_url']?.toString() ??
            json['productImageUrl']?.toString() ??
            '',
        category: json['category']?.toString() ??
            json['category_id']?.toString() ??
            '',
        subCategory: json['subCategory']?.toString() ??
            json['sub_category']?.toString() ??
            '',
        weight: json['weight']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        deliveryTime: json['deliveryTime']?.toString() ??
            json['delivery_time']?.toString() ??
            '',
        discountPercentage: parseDouble(
          json['discountPercentage'] ?? json['discount_percentage'],
        ),
        isVeg: parseBool(
          json['isVeg'] ?? json['is_veg'],
          defaultValue: true,
        ),
        tag: json['tag']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        highlights: (json['highlights'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        quantity: parseInt(json['quantity']),
        posQuantity: parseInt(
          json['posQuantity'] ??
              json['pos_quantity'] ??
              json['pos_quentity'],
        ),
        isCombo: parseBool(
          json['isCombo'] ?? json['is_combo'],
        ),
        pieces: (json['pieces'] as List<dynamic>?)
            ?.whereType<Map>()
            .map(
              (piece) => ProductPiece.fromJson(
            Map<String, dynamic>.from(piece),
          ),
        )
            .toList() ??
            [],
      );
    }

    factory Product.fromCategoryJson(
        Map<String, dynamic> json, {
          String categoryName = '',
          required String Function(String?) buildUrl,
        }) {
      final rawImage     = json['image']?.toString() ?? '';
      final basePrice    = double.tryParse(json['price']?.toString()         ?? '0') ?? 0.0;
      final specialPrice = double.tryParse(json['special_price']?.toString() ?? '0') ?? 0.0;

      // ── Parse pieces ────────────────────────────────────────────────
      final rawPieces = json['pieces'];
      final List<ProductPiece> parsedPieces = [];
      ProductPiece? defaultPiece;

      if (rawPieces is List) {
        for (final p in rawPieces) {
          if (p is Map<String, dynamic>) {
            final piecePrice = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
            final pieceSp    = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0.0;
            // only include pieces that actually have a price
            if (piecePrice > 0 || pieceSp > 0) {
              final minQtyInt      = int.tryParse(p['min_quantity']?.toString() ?? '0') ?? 0;
              final productIsCombo = (json['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes';
              final pc = ProductPiece(
                rowId: p['id']?.toString() ?? '',
                pieceId: p['piece_id']?.toString() ?? '',
                label: p['piece']?.toString() ?? '',
                price:        piecePrice,
                specialPrice: pieceSp,
                image:        p['image']?.toString() ?? '',
                minQuantity:  minQtyInt,
                isCombo:      productIsCombo || (p['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes',
                stock:        int.tryParse(
                    (p['pos_quantity'] ?? p['pos_quentity'] ?? p['quantity'] ?? '0').toString()
                ) ?? 0,
              );
              parsedPieces.add(pc);
              if (p['piece_default']?.toString() == '1') defaultPiece = pc;
            }
          }
        }
      }

      // ── Effective display price ──────────────────────────────────────
      // Priority: product's own special_price > pieces default > first piece
      final double displayPrice;
      final double originalPrice;

      if (basePrice > 0) {
        // Product has its own base price
        final bool hasOffer = specialPrice > 0 && specialPrice < basePrice;
        displayPrice  = hasOffer ? specialPrice : basePrice;
        originalPrice = basePrice;
      } else if (defaultPiece != null) {
        // price = 0, derive from default piece
        displayPrice  = defaultPiece.effectivePrice;
        originalPrice = defaultPiece.price;
      } else if (parsedPieces.isNotEmpty) {
        displayPrice  = parsedPieces.first.effectivePrice;
        originalPrice = parsedPieces.first.price;
      } else {
        displayPrice  = 0;
        originalPrice = 0;
      }

      // ── Weight label: prefer default piece label ─────────────────────
      final weightLabel = (defaultPiece?.label.isNotEmpty == true)
          ? defaultPiece!.label
          : (parsedPieces.isNotEmpty && parsedPieces.first.label.isNotEmpty)
          ? parsedPieces.first.label
          : '';

      final qty = int.tryParse(json['pos_quentity']?.toString() ?? '0') ?? 0;
      // Use default piece image if available, else fall back to product image
      final defaultPieceImage = (defaultPiece?.image.isNotEmpty == true &&
          defaultPiece!.image != 'no_image.png')
          ? defaultPiece.image
          : (parsedPieces.isNotEmpty &&
          parsedPieces.first.image.isNotEmpty &&
          parsedPieces.first.image != 'no_image.png')
          ? parsedPieces.first.image
          : rawImage;

      return Product(
        id:            json['product_id']?.toString() ?? '',
        name:          json['name']?.toString()        ?? '',
        price:         displayPrice,
        originalPrice: originalPrice,
        image:         defaultPieceImage,                // ← CHANGED
        imageUrl:      buildUrl(defaultPieceImage),      // ← CHANGED
        category:      categoryName.isNotEmpty
            ? categoryName
            : (json['category_id']?.toString() ?? ''),
        weight:        weightLabel,
        sku:           '',
        deliveryTime:  '25 mins',
        discountPercentage: 0,
        isVeg:         true,
        quantity:      qty < 0 ? 0 : qty,
        posQuantity:   qty < 0 ? 0 : qty,
        pieces:        parsedPieces,
        isCombo:       (json['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes',
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
      final posQty = int.tryParse(json['pos_quentity']?.toString() ?? '0') ?? 0;
      final qty    = int.tryParse(json['quantity']?.toString() ?? '0') ?? 0;
      final tag    = (json['r_tag']?.toString() ?? '').isNotEmpty
          ? json['r_tag'].toString()
          : (json['w_tag']?.toString() ?? '');

      // ── Parse pieces ────────────────────────────────────────────────
      final rawPieces = json['pieces'];
      final List<ProductPiece> parsedPieces = [];
      ProductPiece? defaultPiece;

      if (rawPieces is List) {
        for (final p in rawPieces) {
          if (p is Map<String, dynamic>) {
            final piecePrice = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;
            final pieceSp    = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0.0;
            if (piecePrice > 0 || pieceSp > 0) {
              final minQtyInt      = int.tryParse(p['min_quantity']?.toString() ?? '0') ?? 0;
              final productIsCombo = (json['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes';
              final pc = ProductPiece(
                rowId: p['id']?.toString() ?? '',
                pieceId: p['piece_id']?.toString() ?? '',
                label: p['piece']?.toString() ?? '',
                price:        piecePrice,
                specialPrice: pieceSp,
                image:        p['image']?.toString() ?? '',
                minQuantity:  minQtyInt,
                isCombo:      productIsCombo || (p['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes',
                stock:        int.tryParse(
                    (p['pos_quantity'] ?? p['pos_quentity'] ?? p['quantity'] ?? '0').toString()
                ) ?? 0,
              );
              parsedPieces.add(pc);
              if (p['piece_default']?.toString() == '1') defaultPiece = pc;
            }
          }
        }
      }

      // ── Effective price ──────────────────────────────────────────────
      final double displayPrice;
      final double originalPrice;

      if (basePrice > 0) {
        final bool hasOffer = specialPrice > 0 && specialPrice < basePrice;
        displayPrice  = hasOffer ? specialPrice : basePrice;
        originalPrice = basePrice;
      } else if (defaultPiece != null) {
        displayPrice  = defaultPiece.effectivePrice;
        originalPrice = defaultPiece.price;
      } else if (parsedPieces.isNotEmpty) {
        displayPrice  = parsedPieces.first.effectivePrice;
        originalPrice = parsedPieces.first.price;
      } else {
        displayPrice  = 0;
        originalPrice = 0;
      }

      // ── Weight: prefer default piece label over raw weight field ─────
      final weightLabel = (defaultPiece?.label.isNotEmpty == true)
          ? defaultPiece!.label
          : (parsedPieces.isNotEmpty && parsedPieces.first.label.isNotEmpty)
          ? parsedPieces.first.label
          : '';

      // Use default piece image if available, else fall back to product image
      final defaultPieceImage = (defaultPiece?.image.isNotEmpty == true &&
          defaultPiece!.image != 'no_image.png')
          ? defaultPiece.image
          : (parsedPieces.isNotEmpty &&
          parsedPieces.first.image.isNotEmpty &&
          parsedPieces.first.image != 'no_image.png')
          ? parsedPieces.first.image
          : rawImage;

      return Product(
        id: json['product_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        price: displayPrice,
        originalPrice: originalPrice,
        image: defaultPieceImage,
        imageUrl: buildUrl(defaultPieceImage),

        // UPDATED
        category: json['category']?.toString() ??
            json['category_id']?.toString() ??
            '',

        subCategory: json['subCategory']?.toString() ??
            json['sub_category']?.toString() ??
            json['subcategory_id']?.toString() ??
            json['sub_category_id']?.toString() ??
            '',

        weight: weightLabel,
        sku: json['sku']?.toString() ?? '',
        deliveryTime: json['delivery_time']?.toString() ?? '15 mins',
        isVeg: (json['is_veg']?.toString() ?? '1') == '1',
        tag: tag,
        description: json['description']?.toString() ?? '',
        highlights: (json['highlights'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        quantity: qty < 0 ? 0 : qty,
        posQuantity: posQty < 0 ? 0 : posQty,
        pieces: parsedPieces,
        isCombo: (json['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes',
      );
    }

    // ── Computed helpers ──────────────────────────────────────────────────────────

    int get computedDiscount {
      if (discountPercentage > 0) return discountPercentage.round();
      if (originalPrice <= 0 || originalPrice <= price) return 0;
      return (((originalPrice - price) / originalPrice) * 100).round();
    }

    double get savings => originalPrice > price ? originalPrice - price : 0;
    // bool get isInStock => posQuantity > 0;
    bool get isInStock => posQuantity > 0 || quantity > 0;

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


