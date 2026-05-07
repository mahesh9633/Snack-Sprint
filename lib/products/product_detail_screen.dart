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

  Product get _product => _fullProduct ?? widget.product;

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
    try {
      final token = await SessionManager.getToken();
      final uri = Uri.parse(
        '${ApiConfig.route('groceries/categories.getProductDetails', token: token)}&product_id=${widget.product.id}',
      );

      final response =
      await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status']?.toString() == 'success' &&
            data['product'] != null) {
          final full = Product.fromApiMap(
            data['product'] as Map<String, dynamic>,
            buildUrl: buildImageUrl,
          );
          if (mounted) {
            setState(() {
              _fullProduct = full;
              _loadingDetail = false;
            });
          }
          return;
        }
      }
    } catch (_) {
    }

    if (mounted) setState(() => _loadingDetail = false);
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
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer2<CartModel, FavoritesModel>(
        builder: (context, cart, favs, _) {
          final qty = cart.getQuantity(_product);
          final inCart = qty > 0;
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
                          if (_product.computedDiscount > 0)
                            Positioned(
                              top: 60,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0C831F),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                    '${_product.computedDiscount}% OFF',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
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
                                      '₹${_product.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                if (_product.originalPrice >
                                    _product.price) ...[
                                  Text(
                                      '₹${_product.originalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                          decoration:
                                          TextDecoration.lineThrough)),
                                  const SizedBox(width: 8),
                                  Text(
                                      '₹${_product.savings.toStringAsFixed(0)} OFF',
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

                      _DetailRow(
                        label: 'Availability',
                        value: _product.posQuantity > 0
                            ? 'In Stock (${_product.posQuantity})'
                            : 'Out of Stock',
                        valueColor: _product.posQuantity > 0
                            ? const Color(0xFF0C831F)
                            : Colors.red,
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
              bottom: MediaQuery.of(context).padding.bottom + 72,
              left: 16,
              right: 16,
              child: inCart
                  ? FloatingCartBar(
                token: '',
                customerId: '',
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
                          '₹${(_product.price * (inCart ? qty : 1)).toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C831F)),
                        ),
                        if (inCart && qty > 1)
                          Text('₹${_product.price.toStringAsFixed(0)} × $qty',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),

                  if (inCart)
                    _DetailStepperButton(
                        product: _product, qty: qty, cart: cart)
                  else
                    _DetailAddButton(
                        product: _product,
                        cart: cart,
                        outOfStock: !_product.isInStock),
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
    final raw = _product.imageUrl.isNotEmpty
        ? _product.imageUrl
        : buildImageUrl(_product.image);
    final url = (raw.startsWith('http://') || raw.startsWith('https://'))
        ? raw
        : '';

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
              height: 210,
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

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.fullImageUrl;
    final hasImage = imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          children: [
            ClipRRect(
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
                  errorBuilder: (_, __, ___) =>
                      _noImagePlaceholder(),
                )
                    : _noImagePlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${product.priceDouble.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0C831F)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.isInStock
                              ? const Color(0xFFE8F5E9)
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.isInStock ? 'In Stock' : 'Out',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: product.isInStock
                                  ? const Color(0xFF0C831F)
                                  : Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noImagePlaceholder() => Container(
    color: Colors.grey[100],
    child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.grey, size: 36)),
  );
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
  const _DetailAddButton(
      {required this.product,
        required this.cart,
        this.outOfStock = false});
  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: outOfStock ? null : () => cart.addItem(product),
    style: ElevatedButton.styleFrom(
      backgroundColor:
      outOfStock ? Colors.grey : const Color(0xFFFF0080),
      padding:
      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(outOfStock ? 'OUT OF STOCK' : 'ADD TO CART',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold)),
  );
}

class _DetailStepperButton extends StatelessWidget {
  final Product product;
  final int qty;
  final CartModel cart;
  const _DetailStepperButton(
      {required this.product, required this.qty, required this.cart});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: const Color(0xFFFF0080),
        borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      InkWell(
        onTap: () => cart.decrementQuantity(product.id),
        borderRadius:
        const BorderRadius.horizontal(left: Radius.circular(12)),
        child: const Padding(
          padding:
          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Icon(Icons.remove, color: Colors.white),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('$qty',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
      InkWell(
        onTap: () => cart.incrementQuantity(product.id),
        borderRadius:
        const BorderRadius.horizontal(right: Radius.circular(12)),
        child: const Padding(
          padding:
          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Icon(Icons.add, color: Colors.white),
        ),
      ),
    ]),
  );
}