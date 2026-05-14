import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../model/favorites_model.dart';
import '../model/product_model.dart';
import '../model/category_data_model.dart';
import '../products/product_detail_screen.dart';
import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../services/session_manager.dart';
import '../widgets/floating_cart.dart';
import '../widgets/piece_selector_sheet.dart';

String get _tImgBase => ApiConfig.imageBase;
const Duration _kTrendingRefreshInterval = Duration(seconds: 30);

Product _toProduct(CategoryDataProduct p) {
  final raw    = p.image;
  final imgUrl = (raw.isNotEmpty && raw != 'no_image.png')
      ? '$_tImgBase$raw' : '';
  final int qty = int.tryParse(p.quantity) ?? 0;

  // p.price and p.wholesalePrice are already correctly resolved
  // by CategoryDataProduct.fromJson (piece-aware logic)
  return Product(
    id:                 p.productId,
    name:               p.name,
    price:              p.price,
    originalPrice:      p.wholesalePrice > 0 ? p.wholesalePrice : p.price,
    image:              raw,
    imageUrl:           imgUrl,
    category:           p.categoryId,
    weight:             p.piece.isNotEmpty ? p.piece : '',
    discountPercentage: p.discountPercent.toDouble(),
    quantity:           qty,
    posQuantity:        qty,
    pieces:             p.pieces.map((e) => ProductPiece.fromJson(e)).toList(),
  );
}

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool               _loading = true;
  String?            _error;
  List<Product>      _allProducts = [];

  Timer?        _autoRefreshTimer;
  bool          _newDataAvailable = false;
  List<Product> _pendingProducts  = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_kTrendingRefreshInterval, (_) {
      _checkForNewData();
    });
  }

  Future<void> _checkForNewData() async {
    if (!mounted || _loading) return;
    try {
      final token  = await SessionManager.getToken();
      final result = await ApiService.getCategoryData(token: token);
      if (!mounted) return;

      if (result['success'] == true) {
        final fresh = _parseProducts(result);
        if (fresh.length != _allProducts.length) {
          setState(() {
            _pendingProducts  = fresh;
            _newDataAvailable = true;
          });
        }
      }
    } catch (_) {}
  }

  void _applyPendingData() {
    setState(() {
      _allProducts      = _pendingProducts;
      _pendingProducts  = [];
      _newDataAvailable = false;
    });
  }

  List<Product> _parseProducts(Map<String, dynamic> result) {
    final rawSubs  = result['subcategories'] as List? ?? [];
    final rawProds = result['products']      as List? ?? [];
    final List<Product> allProds = [];

    for (final p in rawProds) {
      try {
        allProds.add(_toProduct(
            CategoryDataProduct.fromJson(p as Map<String, dynamic>)));
      } catch (_) {}
    }

    for (final s in rawSubs) {
      final sub = s as Map<String, dynamic>;
      for (final p in (sub['products'] as List? ?? [])) {
        try {
          allProds.add(_toProduct(
              CategoryDataProduct.fromJson(p as Map<String, dynamic>)));
        } catch (_) {}
      }
      for (final cs in (sub['subcategories'] as List? ?? [])) {
        final csMap = cs as Map<String, dynamic>;
        for (final p in (csMap['products'] as List? ?? [])) {
          try {
            allProds.add(_toProduct(
                CategoryDataProduct.fromJson(p as Map<String, dynamic>)));
          } catch (_) {}
        }
      }
    }

    final seen = <String>{};
    return allProds.where((p) => seen.add(p.id)).toList();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token  = await SessionManager.getToken();
      final result = await ApiService.getCategoryData(token: token);
      if (!mounted) return;

      if (result['success'] == true) {
        final products = _parseProducts(result);
        setState(() {
          _allProducts      = products;
          _loading          = false;
          _newDataAvailable = false;
          _pendingProducts  = [];
        });

        // ✅ Remove favourites deleted from backend
        final favs = context.read<FavoritesModel>();
        await favs.syncWithBackend(
          products.map((p) => p.id).toList(),
          liveProducts: products,
        );
      } else {
        setState(() {
          _error   = result['message']?.toString() ?? 'Failed to load';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  Future<void> _onRefresh() async => _loadData();

  List<Product> get _discountedProducts =>
      (_allProducts.where((p) => p.discountPercentage > 0).toList()
        ..sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage)));

  List<Product> _getMostBought(CartModel cart) {
    final withQty = _allProducts
        .map((p) => MapEntry(p, cart.getQuantity(p)))
        .where((e) => e.value >= 5)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (withQty.isNotEmpty) return withQty.map((e) => e.key).toList();

    final fallback = _allProducts
        .map((p) => MapEntry(p, cart.getQuantity(p)))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return fallback.map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CartModel, FavoritesModel>(
      builder: (ctx, cart, favs, _) => Scaffold(
        backgroundColor: AppColors.white,
        appBar: _buildAppBar(favs),
        floatingActionButton: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: FloatingCartBar(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(color:AppColors.buttonPrimary))
            : _error != null
            ? _buildError()
            : Column(children: [
          if (_newDataAvailable)
            _TrendingNewDataBanner(
              onTap: _applyPendingData,
              onDismiss: () => setState(() {
                _newDataAvailable = false;
                _pendingProducts  = [];
              }),
            ),
          _buildTabBar(favs),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.buttonPrimary,
              onRefresh: _onRefresh,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFavouritesTab(favs, cart),
                  _buildDealsTab(cart, favs),
                  _buildMostBoughtTab(cart, favs),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FavoritesModel favs) {
    return AppBar(
      backgroundColor:AppColors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
          'Trending',
          style: TextStyle(
              color: AppColors.appBarText, fontWeight: FontWeight.bold, fontSize: 20)
      ),
      centerTitle: false,
      actions: [
        Stack(alignment: Alignment.topRight, children: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.buttonPrimary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.favorite, color: AppColors.buttonPrimary, size: 20),
              onPressed: () => _tabController.animateTo(0),
            ),
          ),
          if (favs.count > 0)
            Positioned(
              top: 6, right: 12,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${favs.count}',
                    style: const TextStyle(
                        color: AppColors.lightBrown,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _buildTabBar(FavoritesModel favs) {
    return Container(
      color: AppColors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.buttonPrimary,
        unselectedLabelColor: Colors.black54,
        indicatorColor: AppColors.buttonPrimary,
        indicatorWeight: 2.5,
        labelPadding: EdgeInsets.zero,
        labelStyle:
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        tabs: [
          Tab(
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite, size: 12),
                const SizedBox(width: 3),
                Text(favs.count > 0
                    ? 'Favourites (${favs.count})'
                    : 'Favourites'),
              ]),
            ),
          ),
          const Tab(
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('🔥 Best Deals'),
            ),
          ),
          const Tab(
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.trending_up, size: 12),
                SizedBox(width: 3),
                Text('Most Bought'),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavouritesTab(FavoritesModel favs, CartModel cart) {
    final list = favs.favoriteList;
    if (list.isEmpty) {
      return _emptyState(Icons.favorite_border,
          'No favourites yet\nTap ♥ on any product to save it here');
    }
    return RefreshIndicator(
      color:AppColors.buttonPrimary,
      onRefresh: _onRefresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.68,
            crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: list.length,
        itemBuilder: (_, i) => _ProductCard(
          product: list[i], cart: cart, favs: favs,
          onTap: () => _openDetail(list[i]),
        ),
      ),
    );
  }

  Widget _buildDealsTab(CartModel cart, FavoritesModel favs) {
    final deals = _discountedProducts;
    if (deals.isEmpty) {
      return _emptyState(
          Icons.local_offer_outlined, 'No deals available right now');
    }
    return RefreshIndicator(
      color:AppColors.buttonPrimary,
      onRefresh: _onRefresh,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.68,
            crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: deals.length,
        itemBuilder: (_, i) => _ProductCard(
          product: deals[i], cart: cart, favs: favs,
          onTap: () => _openDetail(deals[i]),
        ),
      ),
    );
  }

  Widget _buildMostBoughtTab(CartModel cart, FavoritesModel favs) {
    final items = _getMostBought(cart);
    if (items.isEmpty) {
      return _emptyState(
        Icons.trending_up_outlined,
        'No frequently bought items yet\nProducts bought 5+ times appear here',
      );
    }

    final hasTrueItems = _allProducts.any((p) => cart.getQuantity(p) >= 5);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF7B3F00),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.local_fire_department,
              color:AppColors.lightBrown, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasTrueItems
                  ? 'Items you\'ve bought 5+ times'
                  : 'Your frequently ordered items',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${items.length} items',
                style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          color: AppColors.buttonPrimary,
          onRefresh: _onRefresh,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.68,
                crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: items.length,
            itemBuilder: (_, i) => _MostBoughtCard(
              product: items[i],
              rank: i + 1,
              buyCount: cart.getQuantity(items[i]),
              cart: cart,
              favs: favs,
              onTap: () => _openDetail(items[i]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Retry', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor:AppColors.lightBrown),
        ),
      ]),
    ),
  );

  Widget _emptyState(IconData icon, String msg) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 64, color: AppColors.buttonPrimary),
      const SizedBox(height: 14),
      Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14, color:AppColors.appBarText, height: 1.5)),
    ]),
  );

  void _openDetail(Product product) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product)));
}

class _TrendingNewDataBanner extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _TrendingNewDataBanner({required this.onTap, required this.onDismiss});

  @override
  State<_TrendingNewDataBanner> createState() => _TrendingNewDataBannerState();
}

class _TrendingNewDataBannerState extends State<_TrendingNewDataBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(_slide),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B3F00),AppColors.lightBrown],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.lightBrown.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(children: [
                const Icon(Icons.new_releases, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('New trending items available — tap to update',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product        product;
  final CartModel      cart;
  final FavoritesModel favs;
  final VoidCallback   onTap;

  const _ProductCard({
    required this.product, required this.cart,
    required this.favs,    required this.onTap,
  });

  String get _resolvedImageUrl {
    if (product.imageUrl.isNotEmpty) return product.imageUrl;
    if (product.image.isNotEmpty && product.image != 'no_image.png') {
      return '${ApiConfig.imageBase}${product.image}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isFav     = favs.isFavorite(product.id);
    final hasSaving = product.originalPrice > product.price;
    final discount  = product.discountPercentage.round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.buttonPrimary),
        boxShadow: [BoxShadow(
            color: AppColors.lightBrown.withOpacity(0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Image only navigates ──
        GestureDetector(
          onTap: onTap,
          child: Stack(children: [
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 110, width: double.infinity,
                child: _resolvedImageUrl.isNotEmpty
                    ? Image.network(_resolvedImageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => favs.toggleFavorite(product),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 14, color: AppColors.buttonPrimary,
                  ),
                ),
              ),
            ),
            if (discount > 0)
              Positioned(
                top: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.priceGreen,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('$discount% OFF',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ), // closes image GestureDetector

        Padding(
          padding: const EdgeInsets.fromLTRB(7, 6, 7, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.priceGreen,
                  borderRadius: BorderRadius.circular(4)),
              child: Text('₹${product.price.toInt()}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            if (hasSaving) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text('₹${product.originalPrice.toInt()}',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 9,
                        decoration: TextDecoration.lineThrough),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            const Spacer(),
            if (product.weight.isNotEmpty)
              Text(product.weight,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(7, 3, 7, 0),
          child: Text(product.name,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),


        const Spacer(),

        Padding(
          padding: const EdgeInsets.fromLTRB(7, 3, 7, 8),
          child: _CartControl(product: product, cart: cart),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color:AppColors.warningLight,
    child: Center(child: Icon(Icons.image_not_supported,
        color:AppColors.lightBrown, size: 24)),
  );
}

// ─── Most Bought Card ─────────────────────────────────────────────────────────
class _MostBoughtCard extends StatelessWidget {
  final Product        product;
  final int            rank;
  final int            buyCount;
  final CartModel      cart;
  final FavoritesModel favs;
  final VoidCallback   onTap;

  const _MostBoughtCard({
    required this.product, required this.rank,
    required this.buyCount, required this.cart,
    required this.favs, required this.onTap,
  });

  String get _resolvedImageUrl {
    if (product.imageUrl.isNotEmpty) return product.imageUrl;
    if (product.image.isNotEmpty && product.image != 'no_image.png') {
      return '${ApiConfig.imageBase}${product.image}';
    }
    return '';
  }

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.lightBrown;
  }

  @override
  Widget build(BuildContext context) {
    final isFav     = favs.isFavorite(product.id);
    final hasSaving = product.originalPrice > product.price;
    final discount  = product.discountPercentage.round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBrown),
        boxShadow: [BoxShadow(
            color: AppColors.lightBrown.withOpacity(0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Image only navigates ──
        GestureDetector(
          onTap: onTap,
          child: Stack(children: [
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 110, width: double.infinity,
                child: _resolvedImageUrl.isNotEmpty
                    ? Image.network(_resolvedImageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            Positioned(
              top: 4, left: 4,
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                    color: _rankColor, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.15), blurRadius: 4)]),
                alignment: Alignment.center,
                child: Text('#$rank',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 8,
                        fontWeight: FontWeight.bold)),
              ),
            ),

            if (discount > 0)
              Positioned(
                top: 34, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.priceGreen,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('↓$discount%',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => favs.toggleFavorite(product),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 14, color: AppColors.lightBrown,
                  ),
                ),
              ),
            ),
          ]),
        ), // closes image GestureDetector

        Padding(
          padding: const EdgeInsets.fromLTRB(7, 6, 7, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.priceGreen,
                  borderRadius: BorderRadius.circular(4)),
              child: Text('₹${product.price.toInt()}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),

            if (hasSaving) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text('₹${product.originalPrice.toInt()}',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 9,
                        decoration: TextDecoration.lineThrough),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            const Spacer(),
            if (product.weight.isNotEmpty)
              Text(product.weight,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(7, 3, 7, 0),
          child: Text(product.name,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(7, 4, 7, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lightBrown.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.lightBrown.withOpacity(0.3),
                  width: 0.8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_bag_outlined,
                  size: 9, color: AppColors.lightBrown),
              const SizedBox(width: 3),
              Text('Bought $buyCount×',
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.lightBrown,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.fromLTRB(7, 3, 7, 8),
          child: _CartControl(product: product, cart: cart),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color:AppColors.warningLight,
    child: Center(child: Icon(Icons.image_not_supported,
        color: AppColors.buttonPrimary, size: 24)),
  );
}

// ─── Cart Control ─────────────────────────────────────────────────────────────
// ─── Cart Control ─────────────────────────────────────────────────────────────
class _CartControl extends StatelessWidget {
  final Product   product;
  final CartModel cart;
  const _CartControl({required this.product, required this.cart});

  int _totalPieceQty() {
    int total = 0;
    for (final piece in product.pieces) {
      final pieceProduct = Product(
        id:                 piece.cartId(product.id),
        name:               '${product.name} – ${piece.label}',
        price:              piece.effectivePrice,
        originalPrice:      piece.hasDiscount ? piece.price : piece.effectivePrice,
        image:              product.image,
        imageUrl:           product.imageUrl,
        category:           product.category,
        weight:             piece.label,
        sku:                product.sku,
        discountPercentage: piece.discountPct.toDouble(),
        quantity:           product.quantity,
        posQuantity:        product.posQuantity,
      );
      total += cart.getQuantity(pieceProduct);
    }
    return total;
  }

  double _totalPieceAmt() {
    double total = 0;
    for (final piece in product.pieces) {
      final pieceProduct = Product(
        id:                 piece.cartId(product.id),
        name:               '${product.name} – ${piece.label}',
        price:              piece.effectivePrice,
        originalPrice:      piece.hasDiscount ? piece.price : piece.effectivePrice,
        image:              product.image,
        imageUrl:           product.imageUrl,
        category:           product.category,
        weight:             piece.label,
        sku:                product.sku,
        discountPercentage: piece.discountPct.toDouble(),
        quantity:           product.quantity,
        posQuantity:        product.posQuantity,
      );
      total += cart.getQuantity(pieceProduct) * piece.effectivePrice;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (!product.isInStock) {
      return Container(
        width: double.infinity, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('Out of Stock',
            style: TextStyle(
                color: Colors.grey[500], fontSize: 10,
                fontWeight: FontWeight.w600)),
      );
    }

    // ── Pieces product ────────────────────────────────────────────────────
    if (product.pieces.isNotEmpty) {
      final totalQty = _totalPieceQty();
      final totalAmt = _totalPieceAmt();
      final hasItems = totalQty > 0;
      final Color accent = hasItems
          ? AppColors.priceGreen
          : AppColors.buttonPrimary;

      return GestureDetector(
        onTap: () => handleAddToCart(
            context: context, product: product, pieces: product.pieces),
        child: Container(
          width: double.infinity, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: accent, width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: hasItems
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  'ADD (${product.pieces.length} opp)',
                  style: TextStyle(
                      color:         accent,
                      fontSize:      11,
                      fontWeight:    FontWeight.bold,
                      letterSpacing: 0.5)),
              Text('₹${totalAmt.toInt()}',
                  style: TextStyle(
                      color:      accent,
                      fontSize:   9,
                      fontWeight: FontWeight.w700)),
            ],
          )
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('ADD',
                  style: TextStyle(
                      color:         accent,
                      fontSize:      11,
                      fontWeight:    FontWeight.bold,
                      letterSpacing: 0.5)),
              Text(
                  product.pieces.length == 1
                      ? '1 option'
                      : '${product.pieces.length} options',
                  style: TextStyle(color: accent, fontSize: 8)),
            ],
          ),
        ),
      );
    }

    // ── No pieces, qty == 0 → plain ADD ──────────────────────────────────
    final qty = cart.getQuantity(product);
    if (qty == 0) {
      return GestureDetector(
        onTap: () => cart.addItem(product),
        child: Container(
          width: double.infinity, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.buttonPrimary, width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('ADD',
              style: TextStyle(
                  color:         AppColors.buttonPrimary,
                  fontSize:      11,
                  fontWeight:    FontWeight.bold,
                  letterSpacing: 0.5)),
        ),
      );
    }

    // ── No pieces, qty > 0 → stepper ─────────────────────────────────────
    return Container(
      height: 36,
      decoration: BoxDecoration(
          color: AppColors.buttonPrimary,
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => cart.decrementQuantity(product.id),
            child: const SizedBox(width: 36, height: 36,
                child: Icon(Icons.remove, color: Colors.white, size: 14)),
          ),
          Text('$qty',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.bold)),
          GestureDetector(
            onTap: () => cart.addItem(product),
            child: const SizedBox(width: 28, height: 28,
                child: Icon(Icons.add, color: Colors.white, size: 14)),
          ),
        ],
      ),
    );
  }
}