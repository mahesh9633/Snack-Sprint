import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../model/cart_model.dart';
import '../model/favorites_model.dart';
import '../model/product_model.dart';
import '../services/api_config_service.dart';
import '../services/similar_product_service.dart';
import '../services/session_manager.dart';
import '../widgets/floating_cart.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/piece_selector_sheet.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<List<SimilarProduct>> _similarFuture;

  Product? _fullProduct;
  bool _loadingDetail = true;

  List<_PieceOption> _pieces = [];
  _PieceOption? _selectedPiece;
  bool _piecesExpanded = true;
  final Map<String, int> _pendingQtyMap = {};

  Product get _product => _fullProduct ?? widget.product;

  double get _displayPrice {
    if (_selectedPiece != null) {
      final sp = double.tryParse(_selectedPiece!.specialPrice) ?? 0;
      final p  = double.tryParse(_selectedPiece!.price) ?? 0;
      return (sp > 0 && sp < p) ? sp : p;
    }
    return _product.price;
  }

  int get _pendingQty =>
      _selectedPiece != null ? (_pendingQtyMap[_selectedPiece!.pieceId] ?? 1) : 1;
  @override
  void initState() {
    super.initState();
    _loadSimilar();
    _loadFullProduct();
  }

  void _loadSimilar() {
    _similarFuture = SimilarProductsService.getSimilarProducts(
      widget.product.id,
    );
  }

  Future<void> _loadFullProduct() async {
    if (mounted) setState(() => _loadingDetail = true);

    // Keep caller-supplied image as fallback
    final fallbackImageUrl = widget.product.imageUrl.startsWith('http')
        ? widget.product.imageUrl
        : widget.product.image.startsWith('http')
        ? widget.product.image
        : widget.product.imageUrl.isNotEmpty && widget.product.imageUrl != 'no_image.png'
        ? '${ApiConfig.imageBase}${widget.product.imageUrl}'
        : widget.product.image.isNotEmpty && widget.product.image != 'no_image.png'
        ? '${ApiConfig.imageBase}${widget.product.image}'
        : '';

    try {
      final token = await SessionManager.getToken();
      final uri = Uri.parse(
        '${ApiConfig.route('groceries/categories.getProductDetails', token: token)}&product_id=${widget.product.id}',
      );

      final response =
      await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Unexpected response format: ${decoded.runtimeType}');
        }
        final data = decoded;


        if (data['status']?.toString() == 'success' &&
            data['product'] != null) {
          // API returns product as either a Map or a List — handle both
          final rawProduct = data['product'];
          final Map<String, dynamic>? apiProduct;
          if (rawProduct is List) {
            apiProduct = rawProduct.isNotEmpty
                ? Map<String, dynamic>.from(rawProduct.first as Map)
                : null;
          } else if (rawProduct is Map) {
            apiProduct = Map<String, dynamic>.from(rawProduct);
          } else {
            apiProduct = null;
          }
          if (apiProduct == null) {
            if (mounted) {
              setState(() {
                _fullProduct = widget.product.copyWith(imageUrl: fallbackImageUrl);
                _loadingDetail = false;
              });
            }
            return;
          }

          // Build image URL from API response directly
          final rawApiImage = apiProduct['image']?.toString() ?? '';
          String resolvedUrl = '';
          if (rawApiImage.isNotEmpty && rawApiImage != 'no_image.png') {
            resolvedUrl = rawApiImage.startsWith('http')
                ? rawApiImage
                : '${ApiConfig.imageBase}$rawApiImage';
          }
          if (resolvedUrl.isEmpty) resolvedUrl = fallbackImageUrl;

          final full = Product.fromApiMap(
            apiProduct,
            buildUrl: (raw) {
              if (raw == null || raw.isEmpty || raw == 'no_image.png') return '';
              if (raw.startsWith('http')) return raw;
              return '${ApiConfig.imageBase}$raw';
            },
          );

          final rawPieces = apiProduct['pieces'];
          final List<_PieceOption> parsedPieces = [];
          if (rawPieces is List) {
            for (final p in rawPieces) {
              if (p is Map<String, dynamic>) {
                final price = p['price']?.toString() ?? '0';
                final sp    = p['special_price']?.toString() ?? '0';
                if ((double.tryParse(price) ?? 0) > 0 ||
                    (double.tryParse(sp) ?? 0) > 0) {
                  final pieceName = p['piece']?.toString() ?? '';
                  final minQtyInt = int.tryParse(p['min_quantity']?.toString() ?? '0') ?? 0;
                  final pieceLabel = (minQtyInt > 1 && pieceName.isNotEmpty)
                      ? '$pieceName × $minQtyInt'
                      : pieceName;
                  final pieceRawStock = int.tryParse(p['pos_quantity']?.toString() ?? '0') ?? 0;
                  final productIsCombo = (apiProduct['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes';
                  final productLevelQty = int.tryParse(
                      (apiProduct['pos_quentity'] ?? apiProduct['quantity'] ?? '0').toString()
                  ) ?? 0;
                  final pieceStock = (productIsCombo && pieceRawStock == 0) ? productLevelQty : pieceRawStock;
                  parsedPieces.add(_PieceOption(
                    pieceId:      p['id']?.toString() ?? '',
                    piece:        pieceLabel,
                    price:        price,
                    specialPrice: sp,
                    image:        p['image']?.toString() ?? '',
                    stock:        pieceStock,
                    minQuantity:  minQtyInt,
                  ));
                }
              }
            }
          }
          if (mounted) {
            setState(() {
              _fullProduct   = full.copyWith(
                imageUrl: resolvedUrl,
                isCombo:  widget.product.isCombo,
              );
              _pieces        = parsedPieces;
              _selectedPiece = parsedPieces.isNotEmpty ? parsedPieces.first : null;
              for (final pc in parsedPieces) {
                _pendingQtyMap[pc.pieceId] = 1;
              }
              _loadingDetail = false;
            });
          }
          return;
        }
      }
    } catch (e) {
    }


    if (mounted) {
      setState(() {
        _fullProduct   = widget.product.copyWith(
          imageUrl: fallbackImageUrl,
          isCombo:  widget.product.isCombo,
        );
        _pieces        = [];
        _selectedPiece = null;
        _loadingDetail = false;
      });
    }
  }
  void _openSimilarProduct(SimilarProduct similar) {
    final p = Product(
      id: similar.productId,
      name: similar.name,
      price: similar.priceDouble,
      originalPrice: similar.priceDouble,
      image: similar.rawImage,
      imageUrl: similar.fullImageUrl,
      category: '',
      quantity: int.tryParse(similar.posQuantity) ?? 0,
      posQuantity: int.tryParse(similar.posQuantity) ?? 0,
      deliveryTime: '25 mins',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDetail) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8, right: 8, bottom: 8,
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: _circleIcon(Icons.arrow_back, Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE91E63),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer2<CartModel, FavoritesModel>(
        builder: (context, cart, favs, _) {
          final int qty;
          if (_selectedPiece != null) {
            final pieceProduct = Product(
              id: '${_product.id}_piece_${_selectedPiece!.pieceId}',
              name: '${_product.name} – ${_selectedPiece!.piece}',
              price: _selectedPiece!.displayPrice,
              originalPrice: double.tryParse(_selectedPiece!.price) ?? _selectedPiece!.displayPrice,
              image: _product.image,
              imageUrl: _product.imageUrl,
              category: _product.category,
              quantity: _product.quantity,
              posQuantity: _product.posQuantity,
              isCombo: _product.isCombo,
              pieces: _selectedPiece != null ? [_toPiece(_selectedPiece!)] : _product.pieces,
            );
            qty = cart.getQuantity(pieceProduct);
          } else {
            qty = cart.getQuantity(_product);
          }
          final inCart = qty > 0;
          final effectiveQty = inCart ? qty : _pendingQty;
          final isFav = favs.isFavorite(_product.id);
          return Stack(children: [
            RefreshIndicator(
              color: const Color(0xFFFF0080),
              onRefresh: _loadFullProduct,
              child: CustomScrollView(
                slivers: [
                  // ── Hero image app bar ──────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 260,   // ← CHANGED from 300
                    pinned: true,
                    toolbarHeight: 56,     // ← ADDED: keeps toolbar height fixed
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: _circleIcon(Icons.arrow_back, Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: _circleIcon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          const Color(0xFFFF0080),
                        ),
                        onPressed: () {
                          favs.toggleFavorite(_product);
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(SnackBar(
                              content: Text(favs.isFavorite(_product.id)
                                  ? '❤️ Added to Favourites'
                                  : '🤍 Removed from Favourites'),
                              duration: const Duration(seconds: 1),
                              backgroundColor: const Color(0xFFFF0080),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ));
                        },
                      ),
                      IconButton(
                        icon: _circleIcon(Icons.share, Colors.black),
                        onPressed: () {
                          final name    = _product.name;
                          final price   = _product.price.toStringAsFixed(0);
                          final deepLink = 'https://yourapp.page.link/product?id=${_product.id}';
                          Share.share(
                            '🛒 *$name*\n'
                                '💰 Price: ₹$price\n'
                                '📦 ${_product.displayWeight.isNotEmpty ? _product.displayWeight : ""}\n\n'
                                'Open in app: $deepLink',
                            subject: name,
                          );
                        },
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        color: const Color(0xFFF5F5F5),
                        // ── ADDED: clip so image never bleeds outside ──
                        child: SafeArea(
                          bottom: false,
                          child: Stack(children: [
                            _buildHeroImage(),
                            Builder(builder: (_) {
                              final double origPrice = _selectedPiece != null
                                  ? (double.tryParse(_selectedPiece!.price) ?? 0)
                                  : _product.originalPrice;
                              final double discountPct = origPrice > 0 && origPrice > _displayPrice
                                  ? ((origPrice - _displayPrice) / origPrice * 100).roundToDouble()
                                  : (_product.computedDiscount > 0 ? _product.computedDiscount.toDouble() : 0);
                              if (discountPct <= 0) return const SizedBox.shrink();
                              return Positioned(
                                top: 60,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF0C831F),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                      '${discountPct.toInt()}% OFF',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                              );
                            }),
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: _product.isVeg
                                        ? const Color(0xFF0C831F)
                                        : const Color(0xFFB85C00),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _product.isVeg
                                          ? const Color(0xFF0C831F)
                                          : const Color(0xFFB85C00),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),

                  // ── Content ─────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_product.isCombo) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.card_giftcard,
                                          size: 13,
                                          color: Color(0xFFFF6B00)),
                                      SizedBox(width: 4),
                                      Text('Combo Deal',
                                          style: TextStyle(
                                              color: Color(0xFFFF6B00),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (_product.tag.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(_product.tag,
                                      style: const TextStyle(
                                          color: Color(0xFF388E3C),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 8),
                              ],

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(_product.name,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87)),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => favs.toggleFavorite(_product),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isFav
                                            ? const Color(0xFFB85C00)
                                            .withOpacity(0.1)
                                            : Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: const Color(0xFFFF0080),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              if (_product.displayWeight.isNotEmpty)
                                Text(_product.displayWeight,
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey[600])),

                              const SizedBox(height: 12),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF0C831F),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        '₹${_displayPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  if ((_selectedPiece != null
                                      ? (double.tryParse(_selectedPiece!.price) ?? 0)
                                      : _product.originalPrice) > _displayPrice) ...[
                                    Text('₹${(_selectedPiece != null
                                        ? (double.tryParse(_selectedPiece!.price) ?? 0)
                                        : _product.originalPrice).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                            decoration:
                                            TextDecoration.lineThrough)),
                                    const SizedBox(width: 8),
                                    Text(
                                        '₹${((_selectedPiece != null ? (double.tryParse(_selectedPiece!.price) ?? 0) : _product.originalPrice) - _displayPrice).toStringAsFixed(0)} OFF',
                                        style: const TextStyle(
                                            color: Color(0xFF0C831F),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.bolt,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                    _product.deliveryMinutes > 0
                                        ? '${_product.deliveryMinutes} mins delivery'
                                        : 'Fast delivery',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[600])),
                              ]),

                              if (_pieces.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _PiecesSelector(
                                  pieces:         _pieces,
                                  selected:       _selectedPiece,
                                  expanded:       _piecesExpanded,
                                  effectiveStockMap: _product.isCombo
                                      ? () {
                                    final totalStock = _product.posQuantity > 0
                                        ? _product.posQuantity
                                        : _product.quantity;
                                    int usedByOthers = 0;
                                    for (final pc in _pieces) {
                                      if (_selectedPiece != null && pc.pieceId == _selectedPiece!.pieceId) continue;
                                      final pid = '${_product.id}_piece_${pc.pieceId}';
                                      final tmp = Product(id: pid, name: '', price: 0, originalPrice: 0, category: '', quantity: 0, posQuantity: 0);
                                      usedByOthers += cart.getQuantity(tmp);
                                    }
                                    final Map<String, int> map = {};
                                    for (final pc in _pieces) {
                                      final pid = '${_product.id}_piece_${pc.pieceId}';
                                      final thisQty = cart.getQuantity(Product(id: pid, name: '', price: 0, originalPrice: 0, category: '', quantity: 0, posQuantity: 0));
                                      final otherQty = usedByOthers - (pc.pieceId == (_selectedPiece?.pieceId ?? '') ? 0 : thisQty) + thisQty;
                                      map[pc.pieceId] = (totalStock - (usedByOthers - thisQty)).clamp(0, totalStock);
                                    }
                                    return map;
                                  }()
                                      : const {},
                                  onToggle: () =>
                                      setState(() => _piecesExpanded = !_piecesExpanded),
                                  onSelect: (p) => setState(() {
                                    if (_selectedPiece != null) {
                                      _pendingQtyMap[_selectedPiece!.pieceId] = _pendingQty;
                                    }
                                    _selectedPiece = p;
                                    if (!_pendingQtyMap.containsKey(p.pieceId)) {
                                      _pendingQtyMap[p.pieceId] = 1;
                                    }
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        if (_product.description.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('About this product',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(_product.description,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    height: 1.5)),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                        ],

                        if (_product.highlights.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Key Highlights',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _product.highlights
                                  .map((h) => _HighlightChip(text: h))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                        ],

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Product Details',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),

                        if (_product.category.isNotEmpty &&
                            int.tryParse(_product.category) == null)
                          _DetailRow(
                              label: 'Category', value: _product.category),

                        if (_product.displayWeight.isNotEmpty &&
                            _product.displayWeight != '0.000' &&
                            _product.displayWeight != '0')
                          _DetailRow(
                              label: 'Net Quantity',
                              value: _product.displayWeight),

                        _DetailRow(
                          label: 'Food Type',
                          value: _product.isVeg ? 'Vegetarian' : 'Non-Vegetarian',
                        ),

                        _DetailRow(
                          label: 'Delivery Time',
                          value: _product.deliveryMinutes > 0
                              ? '${_product.deliveryMinutes} minutes'
                              : 'Standard delivery',
                        ),

                        if (_product.tag.isNotEmpty)
                          _DetailRow(label: 'Tag', value: _product.tag),

                        if (_product.sku.isNotEmpty &&
                            !RegExp(r'^\d{5,}$').hasMatch(_product.sku))
                          _DetailRow(label: 'SKU', value: _product.sku),

                        const SizedBox(height: 16),
                        const Divider(height: 1),

                        // ── Similar Products ───────────────────────────────
                        _SimilarProductsSection(
                          future: _similarFuture,
                          onProductTap: _openSimilarProduct,
                        ),

                        // Extra bottom padding so content isn't hidden behind bars
                        const SizedBox(height: 160),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: MediaQuery.of(context).padding.bottom +
                  (effectiveQty > 1 ? 96 : 80),
              left: 16,
              right: 16,
              child: cart.totalQuantity > 0
                  ? FloatingCartBar(
                token: '',
                customerId: '',
                onGoToHome: () => Navigator.of(context).pop(),
              )
                  : const SizedBox.shrink(),
            ),

            // ── Sticky bottom bar (price + add/stepper) ──────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, -3))
                  ],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${(_displayPrice * effectiveQty).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C831F)),
                        ),
                        if (effectiveQty > 1)
                          Text('₹${_displayPrice.toStringAsFixed(0)} × $effectiveQty',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (inCart)
                    _DetailStepperButton(
                        product: _selectedPiece != null
                            ? Product(
                          id: '${_product.id}_piece_${_selectedPiece!.pieceId}',
                          name: '${_product.name} – ${_selectedPiece!.piece}',
                          price: _selectedPiece!.displayPrice,
                          originalPrice: double.tryParse(_selectedPiece!.price) ?? _selectedPiece!.displayPrice,
                          image: _product.image,
                          imageUrl: _product.imageUrl,
                          category: _product.category,
                          quantity: _product.quantity,
                          posQuantity: _product.posQuantity,
                          isCombo: _product.isCombo,
                          pieces: _selectedPiece != null ? [_toPiece(_selectedPiece!)] : _product.pieces,
                        )
                            : _product,
                        qty: qty,
                        cart: cart)
                  else
                    _DetailAddButton(
                        product: _selectedPiece != null
                            ? Product(
                          id: '${_product.id}_piece_${_selectedPiece!.pieceId}',
                          name: '${_product.name} – ${_selectedPiece!.piece}',
                          price: _selectedPiece!.displayPrice,
                          originalPrice: double.tryParse(_selectedPiece!.price) ?? _selectedPiece!.displayPrice,
                          image: _product.image,
                          imageUrl: _product.imageUrl,
                          category: _product.category,
                          quantity: _product.quantity,
                          posQuantity: _product.posQuantity,
                          isCombo: _product.isCombo,
                          pieces: _selectedPiece != null ? [_toPiece(_selectedPiece!)] : _product.pieces,
                        )
                            : _product,
                        cart: cart,
                        qty: _pendingQty,
                        onIncrement: () => setState(() {
                          final key = _selectedPiece?.pieceId ?? '';
                          _pendingQtyMap[key] = (_pendingQtyMap[key] ?? 1) + 1;
                        }),
                        onDecrement: () => setState(() {
                          final key = _selectedPiece?.pieceId ?? '';
                          final cur = _pendingQtyMap[key] ?? 1;
                          _pendingQtyMap[key] = cur > 1 ? cur - 1 : 1;
                        }),
                        outOfStock: _selectedPiece != null
                            ? _selectedPiece!.stock == 0
                            : !_product.isInStock),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _circleIcon(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.12), blurRadius: 8)
      ],
    ),
    child: Icon(icon, color: color, size: 20),
  );

  Widget _buildHeroImage() {
    // If a piece is selected and has its own image, prefer it
    String url = '';
    if (_selectedPiece != null && _selectedPiece!.image.isNotEmpty && _selectedPiece!.image != 'no_image.png') {
      url = _selectedPiece!.image.startsWith('http')
          ? _selectedPiece!.image
          : '${ApiConfig.imageBase}${_selectedPiece!.image}';
    } else if (_product.imageUrl.startsWith('http')) {
      url = _product.imageUrl;
    } else if (_product.image.startsWith('http')) {
      url = _product.image;
    } else if (_product.imageUrl.isNotEmpty && _product.imageUrl != 'no_image.png') {
      url = '${ApiConfig.imageBase}${_product.imageUrl}';
    } else if (_product.image.isNotEmpty && _product.image != 'no_image.png') {
      url = '${ApiConfig.imageBase}${_product.image}';
    }

    if (url.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 260, // ← CHANGED from 300
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(
              child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.image_not_supported_outlined,
                  size: 80, color: Colors.grey)),
        ),
      );
    }
    return const Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 80, color: Colors.grey));
  }
}

// ── Similar Products Section ──────────────────────────────────────────────────

class _SimilarProductsSection extends StatelessWidget {
  final Future<List<SimilarProduct>> future;
  final ValueChanged<SimilarProduct> onProductTap;

  const _SimilarProductsSection({
    required this.future,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SimilarProduct>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Similar Products',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => _ShimmerCard(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final products = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.auto_awesome,
                    size: 18, color: Color(0xFFB85C00)),
                const SizedBox(width: 6),
                const Text('Similar Products',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${products.length} items',
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _SimilarProductCard(
                  product: products[i],
                  onTap: () => onProductTap(products[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

// ── Similar Product Card ──────────────────────────────────────────────────────
class _SimilarProductCard extends StatelessWidget {
  final SimilarProduct product;
  final VoidCallback onTap;
  const _SimilarProductCard({required this.product, required this.onTap});

  Product _toProduct() => Product(
    id: product.productId,
    name: product.name,
    price: product.priceDouble,
    originalPrice: product.priceDouble,
    image: product.rawImage,
    imageUrl: product.fullImageUrl,
    category: '',
    quantity: int.tryParse(product.posQuantity) ?? 0,
    posQuantity: int.tryParse(product.posQuantity) ?? 0,
    deliveryTime: '25 mins',
    pieces: product.pieces,
  );

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.fullImageUrl;
    final hasImage = imageUrl.isNotEmpty;
    final p = _toProduct();

    return Consumer<CartModel>(
      builder: (context, cart, _) {
        final qty = cart.getQuantity(p);
        final inCart = qty > 0;
        return Container(
          width: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              GestureDetector(
                onTap: onTap,
                child: ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: hasImage
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                      progress == null
                          ? child
                          : Container(
                        color: Colors.grey[100],
                        child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFB85C00))),
                      ),
                      errorBuilder: (_, __, ___) => _noImagePlaceholder(),
                    )
                        : _noImagePlaceholder(),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFF388E3C),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            '₹${p.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          height: 1.3),
                    ),
                  ],
                ),
              ),

              const Spacer(),
              GestureDetector(
                onTap: () {}, // absorbs tap, prevents bubbling to card onTap
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: p.pieces.isNotEmpty
                      ? _PiecesAddButton(product: p)
                      : product.isInStock
                      ? (inCart
                      ? _SimilarStepper(product: p, qty: qty, cart: cart)
                      : _SimilarAddButton(product: p, cart: cart))
                      : _OutOfStockButton(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _noImagePlaceholder() => Container(
    color: Colors.grey[100],
    child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.grey, size: 36)),
  );
}

// ── Out of stock label ────────────────────────────────────────────────────────
class _OutOfStockButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 36,
    alignment: Alignment.center,
    decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6)),
    child: const Text('Out of Stock',
        style: TextStyle(
            fontSize: 11,
            color: Colors.red,
            fontWeight: FontWeight.bold)),
  );
}

// ── Simple ADD button (no pieces) ────────────────────────────────────────────
class _SimilarAddButton extends StatelessWidget {
  final Product product;
  final CartModel cart;
  const _SimilarAddButton({required this.product, required this.cart});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => cart.addItem(product),
    child: Container(
      width: double.infinity,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!, width: 1.2),
      ),
      child: const Text('ADD',
          style: TextStyle(
              color: Color(0xFFFF0080),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    ),
  );
}

// ── +/- stepper (no pieces) ───────────────────────────────────────────────────
class _SimilarStepper extends StatelessWidget {
  final Product product;
  final int qty;
  final CartModel cart;
  const _SimilarStepper(
      {required this.product, required this.qty, required this.cart});

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(
        color: const Color(0xFFFF0080),
        borderRadius: BorderRadius.circular(6)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => cart.decrementQuantity(product.id),
          child: const SizedBox(
              width: 32,
              height: 36,
              child: Icon(Icons.remove, color: Colors.white, size: 16)),
        ),
        Text('$qty',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: () => cart.addItem(product),
          child: const SizedBox(
              width: 32,
              height: 36,
              child: Icon(Icons.add, color: Colors.white, size: 16)),
        ),
      ],
    ),
  );
}

// ── ADD button when product has pieces ───────────────────────────────────────
class _PiecesAddButton extends StatelessWidget {
  final Product product;
  const _PiecesAddButton({required this.product});

  double _totalAmt(CartModel cart) {
    double total = 0;
    for (final piece in product.pieces) {
      final pieceProduct = Product(
        id: piece.cartId(product.id),
        name: '${product.name} – ${piece.label}',
        price: piece.effectivePrice,
        originalPrice:
        piece.hasDiscount ? piece.price : piece.effectivePrice,
        image: product.image,
        imageUrl: product.imageUrl,
        category: product.category,
        quantity: product.quantity,
        posQuantity: product.posQuantity,
      );
      total += cart.getQuantity(pieceProduct) * piece.effectivePrice;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartModel>(
      builder: (context, cart, _) {
        int totalQty = 0;
        for (final piece in product.pieces) {
          final pieceProduct = Product(
            id: piece.cartId(product.id),
            name: '${product.name} – ${piece.label}',
            price: piece.effectivePrice,
            originalPrice:
            piece.hasDiscount ? piece.price : piece.effectivePrice,
            image: product.image,
            imageUrl: product.imageUrl,
            category: product.category,
            quantity: product.quantity,
            posQuantity: product.posQuantity,
          );
          totalQty += cart.getQuantity(pieceProduct);
        }

        final hasItems = totalQty > 0;
        final borderClr =
        hasItems ? const Color(0xFF388E3C) : Colors.grey[300]!;
        final textClr =
        hasItems ? const Color(0xFF388E3C) : const Color(0xFFFF0080);

        return GestureDetector(
          onTap: () => handleAddToCart(
            context: context,
            product: product,
            pieces: product.pieces,
          ),
          child: Container(
            width: double.infinity,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderClr, width: 1.2),
            ),
            child: hasItems
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ADD (${product.pieces.length} opp)',
                  style: TextStyle(
                      color: textClr,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
                Text(
                  '₹${_totalAmt(cart).toInt()}',
                  style: TextStyle(
                      color: textClr,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ADD',
                    style: TextStyle(
                        color: textClr,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                Text(
                  '${product.pieces.length} options',
                  style: TextStyle(color: textClr, fontSize: 7),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 140,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Container(
                      height: 12,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.only(bottom: 6)),
                  Container(height: 12, width: 80, color: Colors.grey[300]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reused widgets ────────────────────────────────────────────────────────────

class _HighlightChip extends StatelessWidget {
  final String text;
  const _HighlightChip({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle, size: 14, color: Color(0xFF0C831F)),
      const SizedBox(width: 4),
      Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87)),
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(
      {required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
        border:
        Border(bottom: BorderSide(color: Colors.grey.shade100))),
    child: Row(children: [
      Expanded(
          flex: 2,
          child: Text(label,
              style:
              TextStyle(fontSize: 13, color: Colors.grey[600]))),
      Expanded(
          flex: 3,
          child: Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.black87))),
    ]),
  );
}

class _DetailAddButton extends StatelessWidget {
  final Product product;
  final CartModel cart;
  final bool outOfStock;
  final int qty;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _DetailAddButton({
    required this.product,
    required this.cart,
    this.outOfStock = false,
    this.qty = 1,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    if (outOfStock) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('OUT OF STOCK',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      );
    }

    // qty == 1: plain ADD TO CART button
    return ElevatedButton(
      onPressed: () {
        for (int i = 0; i < qty; i++) {
          cart.addItem(product);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF0080),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: qty > 1
          ? Text('ADD $qty TO CART',
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))
          : const Text('ADD TO CART',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Piece Option model ────────────────────────────────────────────────────────

class _PieceOption {
  final String pieceId;
  final String piece;
  final String price;
  final String specialPrice;
  final String image;
  final int    stock;
  final int    minQuantity;

  const _PieceOption({
    required this.pieceId,
    required this.piece,
    required this.price,
    required this.specialPrice,
    this.image = '',
    this.stock = 0,
    this.minQuantity = 0,
  });

  double get displayPrice {
    final sp = double.tryParse(specialPrice) ?? 0;
    final p  = double.tryParse(price) ?? 0;
    return (sp > 0 && sp < p) ? sp : p;
  }

  bool get hasDiscount {
    final sp = double.tryParse(specialPrice) ?? 0;
    final p  = double.tryParse(price) ?? 0;
    return sp > 0 && sp < p;
  }
}

// ── Pieces Selector Widget ────────────────────────────────────────────────────

class _PiecesSelector extends StatelessWidget {
  final List<_PieceOption>  pieces;
  final _PieceOption?       selected;
  final bool                expanded;
  final VoidCallback        onToggle;
  final ValueChanged<_PieceOption> onSelect;
  final Map<String, int>    effectiveStockMap; // pieceId → available stock

  const _PiecesSelector({
    required this.pieces,
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
    this.effectiveStockMap = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Collapsed pill (always visible) ──────────────────────────────
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF0080), width: 1.4),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFFF0F6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.layers_outlined,
                    size: 16, color: Color(0xFFFF0080)),
                const SizedBox(width: 6),
                Text(
                  selected != null
                      ? '${selected!.piece}  ₹${selected!.displayPrice.toStringAsFixed(0)}'
                      : 'Select size',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF0080),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: Color(0xFFFF0080)),
                ),
              ],
            ),
          ),
        ),

        // ── Expanded options (always visible, toggle only hides via arrow) ──
        if (expanded)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: pieces.map((p) {
                  final isSelected = selected?.pieceId == p.pieceId;
                  return GestureDetector(
                    onTap: () => onSelect(p),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (effectiveStockMap[p.pieceId] ?? p.stock) == 0 ? Colors.grey[50] : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF0080)
                              : Colors.grey.shade300,
                          width: isSelected ? 2.0 : 1.4,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.piece,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (effectiveStockMap[p.pieceId] ?? p.stock) == 0 ? Colors.grey : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${p.displayPrice.toStringAsFixed(0)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: (effectiveStockMap[p.pieceId] ?? p.stock) == 0 ? Colors.grey : const Color(0xFF0C831F),
                            ),
                          ),
                          if (p.hasDiscount) ...[
                            const SizedBox(height: 1),
                            Text(
                              '₹${(double.tryParse(p.price) ?? 0).toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.black54,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailStepperButton extends StatefulWidget {
  final Product product;
  final int qty;
  final CartModel cart;
  const _DetailStepperButton(
      {required this.product, required this.qty, required this.cart});

  @override
  State<_DetailStepperButton> createState() => _DetailStepperButtonState();
}

class _DetailStepperButtonState extends State<_DetailStepperButton> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing(int currentQty) {
    _ctrl.text = '$currentQty';
    _focus.requestFocus();
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.selection = TextSelection(
        baseOffset:   0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  void _commitEdit(CartModel cart) {
    final val = int.tryParse(_ctrl.text.trim()) ?? 0;
    final stock = widget.product.quantity > 0
        ? widget.product.quantity
        : widget.product.posQuantity;

    if (val <= 0) {
      cart.removeItem(widget.product);
    } else if (stock > 0 && val > stock) {
      // Clamp to max stock and show snackbar
      cart.setQuantity(widget.product, stock);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Only $stock quantity available'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFFF0080),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
    } else {
      cart.setQuantity(widget.product, val);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final qty   = widget.qty;
    final stock = widget.product.quantity > 0
        ? widget.product.quantity
        : widget.product.posQuantity;

    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFFF0080),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        InkWell(
          onTap: () => widget.cart.decrementQuantity(widget.product.id),
          borderRadius:
          const BorderRadius.horizontal(left: Radius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Icon(Icons.remove, color: Colors.white),
          ),
        ),

        // ── Tappable qty / inline editor ──────────────────────────────
        if (_editing)
          SizedBox(
            width: 52,
            child: TextField(
              controller:   _ctrl,
              focusNode:    _focus,
              keyboardType: TextInputType.number,
              textAlign:    TextAlign.center,
              style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   18,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  border:         InputBorder.none,
                  isDense:        true,
                  contentPadding: EdgeInsets.zero),
              onChanged: (_) => setState(() {}), // triggers live price refresh
              onSubmitted: (_) => _commitEdit(widget.cart),
              onTapOutside: (_) => _commitEdit(widget.cart),
            ),
          )
        else
          GestureDetector(
            onTapDown: (_) => _startEditing(qty),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$qty',
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   18,
                      fontWeight: FontWeight.bold)),
            ),
          ),

        InkWell(
          onTap: () {
            if (stock > 0 && qty >= stock) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  content: Text('Only $stock quantity available'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFFFF0080),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              return;
            }
            widget.cart.incrementQuantity(widget.product.id);
          },
          borderRadius:
          const BorderRadius.horizontal(right: Radius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Icon(Icons.add, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}
ProductPiece _toPiece(_PieceOption opt) => ProductPiece(
  pieceId:      opt.pieceId,
  label:        opt.piece,
  price:        double.tryParse(opt.price) ?? 0,
  specialPrice: double.tryParse(opt.specialPrice) ?? 0,
  image:        opt.image,
  minQuantity:  opt.minQuantity,
);