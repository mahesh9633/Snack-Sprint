import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../model/category_data_model.dart';
import '../model/product_model.dart';
import '../products/product_card.dart';
import '../products/product_detail_screen.dart';
import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../services/session_manager.dart';
import '../widgets/floating_cart.dart';
import '../widgets/piece_selector_sheet.dart';

String get _imgBase => ApiConfig.imageBase;
const int _previewMax = 20;

// ─── Stock helper ────────────────────────────────────────────────────────────
bool _isProductInStock(CategoryDataProduct p) {
  try {
    return p.isInStock;
  } catch (_) {
    return true;
  }
}

Product _toProduct(CategoryDataProduct p) {
  final raw    = p.defaultImage;
  final imgUrl = (raw.isNotEmpty && raw != 'no_image.png')
      ? '$_imgBase$raw'
      : '';
  final int productQty = int.tryParse(p.quantity) ?? 0;
  final bool isCombo   = p.isCombo;

  final pieces = p.pieces.map((e) {
    final base      = ProductPiece.fromJson(e);
    final pieceStock = base.stock;
    final resolvedStock = (isCombo && pieceStock == 0) ? productQty : pieceStock;
    return ProductPiece(
      rowId:        base.rowId,
      pieceId:      base.pieceId,
      label:        base.label,
      price:        base.price,
      specialPrice: base.specialPrice,
      image:        base.image,
      minQuantity:  base.minQuantity,
      isCombo:      base.isCombo,
      stock:        resolvedStock,
    );
  }).toList();

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
    quantity:           productQty,
    posQuantity:        productQty,
    pieces:             pieces,
    isCombo:            isCombo,
  );
}

// ─── CategoriesScreen ─────────────────────────────────────────────────────────
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool                          _loading        = true;
  String?                       _error;
  List<CategoryDataSubcategory> _subcategories  = [];
  List<CategoryDataProduct>     _parentProducts = [];

  final Map<String, List<CategoryDataProduct>>     _cache      = {};
  final Map<String, List<CategoryDataSubcategory>> _subCache   = {};
  final Map<String, bool>                          _subLoading = {};
  final Map<String, Future<void>>                  _inFlight   = {};

  String? _cachedToken;

  // ─── Muted/pale tile palette — subtle multicolor, BigBasket-clean ────────
  static const List<Color> _tileColors = [
    Color(0xFFF3EFEA), // pale warm beige
    Color(0xFFEEF3EE), // pale mint
    Color(0xFFF5F1E8), // pale butter
    Color(0xFFEFEEF3), // pale lavender
    Color(0xFFF5EEEF), // pale pink
    Color(0xFFEDF2F3), // pale sky
    Color(0xFFEFF3EF), // pale sage
    Color(0xFFF5F0EA), // pale apricot
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    _cache.clear();
    _subCache.clear();
    _subLoading.clear();
    _inFlight.clear();
    try {
      _cachedToken ??= await SessionManager.getToken();
      final result = await ApiService.getCategoryData(token: _cachedToken!);
      if (!mounted) return;
      if (result['success'] == true) {
        final rawSubs  = result['subcategories'] as List? ?? [];
        final rawProds = result['products']      as List? ?? [];
        final subs  = rawSubs.map((s) =>
            CategoryDataSubcategory.fromJson(s as Map<String, dynamic>)).toList();
        final prods = rawProds.map((p) =>
            CategoryDataProduct.fromJson(p as Map<String, dynamic>)).toList();
        for (final s in subs) {
          if (s.products.isNotEmpty) _cache[s.categoryId] = s.products;
        }
        setState(() {
          _subcategories  = subs;
          _parentProducts = prods;
          _loading        = false;
        });
        _prefetchBatch(subs.take(10).toList());
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

  Future<void> _fetchCategoryChildren(CategoryDataSubcategory cat) async {
    if (_subCache.containsKey(cat.categoryId)) return;
    if (_inFlight.containsKey(cat.categoryId)) return _inFlight[cat.categoryId]!;
    final future = _doFetch(cat);
    _inFlight[cat.categoryId] = future;
    try {
      await future;
    } finally {
      _inFlight.remove(cat.categoryId);
    }
  }

  Future<void> _doFetch(CategoryDataSubcategory cat) async {
    if (mounted) setState(() => _subLoading[cat.categoryId] = true);
    try {
      _cachedToken ??= await SessionManager.getToken();
      final result = await ApiService.getCategoryData(
          token: _cachedToken!, categoryId: cat.categoryId);
      if (!mounted) return;
      if (result['success'] == true) {
        final childSubs  = (result['subcategories'] as List? ?? [])
            .map((s) => CategoryDataSubcategory.fromJson(s as Map<String, dynamic>))
            .toList();
        final childProds = (result['products'] as List? ?? [])
            .map((p) => CategoryDataProduct.fromJson(p as Map<String, dynamic>))
            .toList();
        _subCache[cat.categoryId] = childSubs;
        for (final cs in childSubs) {
          if (cs.products.isNotEmpty) _cache[cs.categoryId] = cs.products;
        }
        if (childProds.isNotEmpty) _cache[cat.categoryId] = childProds;
      } else {
        _subCache[cat.categoryId] = [];
      }
    } catch (e) {
      if (mounted) _subCache[cat.categoryId] = [];
    }
    if (mounted) setState(() => _subLoading[cat.categoryId] = false);
  }

  Future<void> _prefetchBatch(List<CategoryDataSubcategory> cats) async {
    if (!mounted) return;
    await Future.wait(cats.map((cat) => _fetchCategoryChildren(cat)));
  }

  void _openCategory(CategoryDataSubcategory cat) async {
    if (!_subCache.containsKey(cat.categoryId)) {
      _fetchCategoryChildren(cat);
    }
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CategorySplitScreen(
        parentCat:     cat,
        fetchChildren: _fetchCategoryChildren,
        subCache:      _subCache,
        productCache:  _cache,
        subLoadingMap: _subLoading,
      ),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: FloatingCartBar(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation:       0,
        automaticallyImplyLeading: false,
        title: const Text('Categories',
            style: TextStyle(
                color:      AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize:   22)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _error != null
          ? _buildError()
          : _subcategories.isEmpty && _parentProducts.isEmpty
          ? _buildEmpty()
          : _buildList(),
    );
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
          onPressed: _fetchData,
          icon:  const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Retry', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.category_outlined, size: 60, color: AppColors.primaryBlue),
      const SizedBox(height: 16),
      const Text('No categories found',
          style: TextStyle(color: AppColors.textDark)),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: _fetchData,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange),
        child: const Text('Retry', style: TextStyle(color: AppColors.textLight)),
      ),
    ]),
  );

  // ─── Responsive 4-per-row colored tile grid (fixed-size chips, like
  //     the home-tab category chips: same box size + BoxFit.cover for
  //     every tile, so nothing ever looks bigger/smaller than another) ──
  Widget _buildList() {
    return RefreshIndicator(
      color: AppColors.buttonPrimary,
      onRefresh: _fetchData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive column count based on available width:
          //   < 600   → phones            → 4 per row
          //   600-899 → small tablets     → 5 per row
          //   900-1199→ large tablets     → 6 per row
          //   >=1200  → desktop/web       → 7 per row
          final width = constraints.maxWidth;
          int crossAxisCount;
          if (width >= 1200) {
            crossAxisCount = 7;
          } else if (width >= 900) {
            crossAxisCount = 6;
          } else if (width >= 600) {
            crossAxisCount = 5;
          } else {
            crossAxisCount = 4;
          }

          // Fixed square tile size derived once from available width —
          // same idea as _buildCatChip's hardcoded 65x65 box, just
          // computed so it adapts cleanly to any screen instead of
          // being a single hardcoded number.
          const double hPad        = 12; // outer grid padding (left+right combined /2 *2)
          const double crossSpace  = 10; // spacing between columns
          final double totalSpacing =
              (hPad * 2) + (crossSpace * (crossAxisCount - 1));
          final double tileSize =
              (width - totalSpacing) / crossAxisCount;

          return GridView.builder(
            physics:   const AlwaysScrollableScrollPhysics(),
            padding:   const EdgeInsets.fromLTRB(12, 10, 12, 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   crossAxisCount,
              crossAxisSpacing: crossSpace,
              mainAxisSpacing:  16,
              mainAxisExtent:   tileSize + 38,
            ),
            itemCount: _subcategories.length,
            itemBuilder: (context, index) {
              final cat    = _subcategories[index];
              final imgUrl = (cat.image.isNotEmpty && cat.image != 'no_image.png')
                  ? '$_imgBase${cat.image}'
                  : '';
              final tileColor = _tileColors[index % _tileColors.length];

              return GestureDetector(
                onTap: () => _openCategory(cat),
                child: Column(
                  children: [
                    // Fixed-size square box — identical for every tile,
                    // regardless of source image shape. BoxFit.cover +
                    // clipBehavior crops each image to fill it exactly,
                    // the same technique _buildCatChip uses.
                    Container(
                      width:  tileSize,
                      height: tileSize,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color:        tileColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: imgUrl.isNotEmpty
                          ? Image.network(imgUrl, fit: BoxFit.cover,
                          width: tileSize,
                          height: tileSize,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Center(child: _catIcon()))
                          : Center(child: _catIcon()),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 30,
                      child: Text(cat.name,
                          style: const TextStyle(
                              fontSize:   11.5,
                              fontWeight: FontWeight.w600,
                              height:     1.15,
                              color:      AppColors.textDark),
                          textAlign: TextAlign.center,
                          maxLines:  2,
                          overflow:  TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _catIcon() => const Icon(Icons.category_outlined,
      color: AppColors.primaryBlue, size: 26);
}

// ─── Category Split Screen ────────────────────────────────────────────────────
class _CategorySplitScreen extends StatefulWidget {
  final CategoryDataSubcategory                        parentCat;
  final Future<void> Function(CategoryDataSubcategory) fetchChildren;
  final Map<String, List<CategoryDataSubcategory>>     subCache;
  final Map<String, List<CategoryDataProduct>>         productCache;
  final Map<String, bool>                              subLoadingMap;

  const _CategorySplitScreen({
    required this.parentCat,
    required this.fetchChildren,
    required this.subCache,
    required this.productCache,
    required this.subLoadingMap,
  });

  @override
  State<_CategorySplitScreen> createState() => _CategorySplitScreenState();
}

class _CategorySplitScreenState extends State<_CategorySplitScreen> {
  late String            _selectedCatId;
  final ScrollController _rightScroll = ScrollController();

  Map<String, List<CategoryDataSubcategory>> get _subCache      => widget.subCache;
  Map<String, List<CategoryDataProduct>>     get _productCache  => widget.productCache;
  Map<String, bool>                          get _subLoadingMap => widget.subLoadingMap;

  @override
  void initState() {
    super.initState();
    _selectedCatId = widget.parentCat.categoryId;
  }

  @override
  void dispose() {
    _rightScroll.dispose();
    super.dispose();
  }

  List<CategoryDataSubcategory> get _sidebarItems =>
      _subCache[widget.parentCat.categoryId] ?? [];

  bool get _isSidebarLoading =>
      _subLoadingMap[widget.parentCat.categoryId] ?? false;

  List<CategoryDataProduct> get _rightProducts =>
      _productCache[_selectedCatId] ?? [];

  bool get _isRightLoading =>
      _subLoadingMap[_selectedCatId] ?? false;

  String get _selectedCatName {
    if (_selectedCatId == widget.parentCat.categoryId) {
      return widget.parentCat.name;
    }
    try {
      return _sidebarItems
          .firstWhere((s) => s.categoryId == _selectedCatId)
          .name;
    } catch (_) {
      return '';
    }
  }

  Future<void> _onSidebarTap(CategoryDataSubcategory cat) async {
    if (_selectedCatId == cat.categoryId) return;
    setState(() => _selectedCatId = cat.categoryId);

    if (_rightScroll.hasClients) {
      _rightScroll.animateTo(0,
          duration: const Duration(milliseconds: 250),
          curve:    Curves.easeOut);
    }

    if (!_subCache.containsKey(cat.categoryId)) {
      await widget.fetchChildren(cat);
      if (mounted) setState(() {});
    }
  }

  void _goToAllProducts(String title, List<CategoryDataProduct> products) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AllProductsScreen(title: title, products: products),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.cardWhite,
      // ── Floating cart bar ─────────────────────────────────────────────────
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: FloatingCartBar(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.parentCat.name,
            style: const TextStyle(
                color:      Colors.black,
                fontWeight: FontWeight.bold,
                fontSize:   18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: _isSidebarLoading &&
          _sidebarItems.isEmpty &&
          _rightProducts.isEmpty
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.lightBrown))
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeftSidebar(),
          Container(width: 1, color: Colors.grey[200]),
          Expanded(child: _buildRightPanel()),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final items = _sidebarItems;
    return SizedBox(
      width: 90,
      child: Container(
        color: AppColors.white,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          children: [
            _SidebarTile(
              label: 'All',
              imgUrl: (widget.parentCat.image.isNotEmpty &&
                  widget.parentCat.image != 'no_image.png')
                  ? '$_imgBase${widget.parentCat.image}'
                  : '',
              isSelected: _selectedCatId == widget.parentCat.categoryId,
              onTap: () {
                if (_selectedCatId == widget.parentCat.categoryId) return;
                setState(() => _selectedCatId = widget.parentCat.categoryId);
                if (_rightScroll.hasClients) {
                  _rightScroll.animateTo(0,
                      duration: const Duration(milliseconds: 200),
                      curve:    Curves.easeOut);
                }
              },
            ),
            ...items.map((cat) {
              final img = (cat.image.isNotEmpty && cat.image != 'no_image.png')
                  ? '$_imgBase${cat.image}'
                  : '';
              return _SidebarTile(
                label:      cat.name,
                imgUrl:     img,
                isSelected: _selectedCatId == cat.categoryId,
                onTap:      () => _onSidebarTap(cat),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_isRightLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.lightBrown));
    }

    final products = _rightProducts;
    final screenW  = MediaQuery.of(context).size.width;
    final rightW   = screenW - 91;
    final cardW    = (rightW - 24) / 2;
    final imgH     = cardW * 0.72;
    final cardH    = imgH + 115;

    CategoryDataSubcategory currentCat() {
      if (_selectedCatId == widget.parentCat.categoryId) {
        return widget.parentCat;
      }
      try {
        return _sidebarItems
            .firstWhere((s) => s.categoryId == _selectedCatId);
      } catch (_) {
        return widget.parentCat;
      }
    }

    return RefreshIndicator(
      color:     AppColors.buttonPrimary,
      onRefresh: () async {
        widget.subCache.remove(_selectedCatId);
        widget.productCache.remove(_selectedCatId);
        await widget.fetchChildren(currentCat());
        if (mounted) setState(() {});
      },
      child: CustomScrollView(
        controller: _rightScroll,
        physics:    const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color:   Colors.white,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
              child: Row(children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                      color:        AppColors.buttonPrimary,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(_selectedCatName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                if (products.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppColors.appBarText.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${products.length}',
                        style: const TextStyle(
                            fontSize:   10,
                            color:      AppColors.appBarText,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
          ),

          if (products.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 48,  color: AppColors.floatingCartBg),
                  const SizedBox(height: 10),
                  Text('No products found',
                      style: TextStyle(
                          color: Colors.black87, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('Pull down to refresh',
                      style: TextStyle(
                          color: Colors.black87, fontSize: 11)),
                ]),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   2,
                  mainAxisExtent:   cardH,
                  crossAxisSpacing: 8,
                  mainAxisSpacing:  8,
                ),
                delegate: SliverChildBuilderDelegate(
                      (_, i) => RepaintBoundary(
                      child: ProductCard(product: _toProduct(products[i]), imageHeight: imgH)),
                  childCount: products.length > _previewMax
                      ? _previewMax
                      : products.length,
                ),
              ),
            ),

            if (products.length > _previewMax)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: _SeeMoreButton(
                    count: products.length,
                    onTap: () =>
                        _goToAllProducts(_selectedCatName, products),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }
}

// ─── Sidebar Tile ─────────────────────────────────────────────────────────────
class _SidebarTile extends StatelessWidget {
  final String       label;
  final String       imgUrl;
  final bool         isSelected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.label,
    required this.imgUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:  const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? AppColors.lightBrown
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.lightBrown.withOpacity(0.10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.lightBrown.withOpacity(0.45)
                    : Colors.grey[300]!,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _icon())
                : _icon(),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize:   9.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.buttonPrimary
                  : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }

  Widget _icon() => Icon(Icons.category,
      color: AppColors.buttonPrimary.withOpacity(0.6), size: 22);
}

// ─── Product Card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final CategoryDataProduct p;
  const _ProductCard({required this.p});

  static double cardHeightForWidth(double availableCardWidth) {
    final imgH = availableCardWidth * 0.72;
    return imgH + 138;
  }

  @override
  Widget build(BuildContext context) {
    final raw     = p.defaultImage;   // ← CHANGED
    final imgUrl  = (raw.isNotEmpty && raw != 'no_image.png')
        ? '$_imgBase$raw'
        : '';
    final product = _toProduct(p);
    final inStock = _isProductInStock(p);

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.max,
        children: [

          // ── Image ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product))),
            child: LayoutBuilder(builder: (_, constraints) {
              final imgH = constraints.maxWidth * 0.72;
              return Stack(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10)),
                  child: SizedBox(
                    height: imgH,
                    width:  double.infinity,
                    child:  imgUrl.isNotEmpty
                        ? Image.network(imgUrl, fit: BoxFit.cover,
                        loadingBuilder: (_, child, prog) =>
                        prog == null ? child : _placeholder(),
                        errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                ),
                if (p.discountPercent > 0)
                  Positioned(
                    top: 5, left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color:        AppColors.priceGreen,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('↓${p.discountPercent}%',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   8,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (!_isProductInStock(p))
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10)),
                      child: Container(
                        color:     Colors.black.withOpacity(0.35),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                              color:        Colors.red[700],
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('Out of Stock',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
          ),

          // ── Content ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                  color:        AppColors.priceGreen,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('₹${product.price.toInt()}',
                                  style: const TextStyle(
                                      color:      Colors.white,
                                      fontSize:   8,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (product.originalPrice > product.price) ...[
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                    '₹${product.originalPrice.toInt()}',
                                    style: TextStyle(
                                        fontSize:   6,
                                        color:      Colors.grey[500],
                                        decoration:
                                        TextDecoration.lineThrough),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                              ),
                            ],
                          ]),
                    ),

                    if (product.displayWeight.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(product.displayWeight,
                            style: TextStyle(
                                fontSize: 9, color: Colors.black87),
                            maxLines:  1,
                            overflow:  TextOverflow.ellipsis,
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 3),

                if (p.discountPercent > 0) ...[
                  Text('${p.discountPercent}% off',
                      style: const TextStyle(
                          fontSize:   9,
                          color:      AppColors.priceGreen,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                ],

                Text(p.name,
                    style: const TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w500,
                        color:      Colors.black87,
                        height:     1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          const Spacer(),

          // ── ADD button ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: SizedBox(
              height: 36,
              width:  double.infinity,
              child:  _CartButton(
                  product:   product,
                  isInStock: inStock),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey[100],
    child: Center(
        child: Icon(Icons.image_not_supported,
            color: Colors.grey[300], size: 24)),
  );
}

// ─── Cart Button ──────────────────────────────────────────────────────────────
class _CartButton extends StatefulWidget {
  final Product product;
  final bool    isInStock;
  const _CartButton({required this.product, required this.isInStock});

  @override
  State<_CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<_CartButton> {
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
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.selection = TextSelection(
        baseOffset:   0,
        extentOffset: _ctrl.text.length,
      );
      _focus.requestFocus();
    });
  }

  void _commitEdit(CartModel cart) {
    final val   = int.tryParse(_ctrl.text.trim()) ?? 0;
    final stock = widget.product.quantity > 0
        ? widget.product.quantity
        : widget.product.posQuantity;
    if (val <= 0) {
      cart.removeItem(widget.product);
    } else if (stock > 0 && val > stock) {
      cart.setQuantity(widget.product, stock);
      showDialog(
        context: context,
        barrierColor: Colors.black26,
        builder: (_) => Center(
          child: Container(
            margin:  const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.15), blurRadius: 20)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline,
                  color: AppColors.buttonPrimary, size: 36),
              const SizedBox(height: 12),
              Text('Only $stock item${stock == 1 ? '' : 's'} available',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w600,
                      color:      Colors.black87)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 10),
                  decoration: BoxDecoration(
                      color:        AppColors.buttonPrimary,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('OK',
                      style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   14)),
                ),
              ),
            ]),
          ),
        ),
      );
    } else {
      cart.setQuantity(widget.product, val);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isInStock) {
      return Container(
        width:     double.infinity,
        height:    30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color:        Colors.grey[200],
            borderRadius: BorderRadius.circular(6)),
        child: Text('Unavailable',
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      );
    }

    return Consumer<CartModel>(
      builder: (ctx, cart, __) {

        // ── Pieces: sum qty across ALL piece cartIds ──────────────────────
        if (widget.product.pieces.isNotEmpty) {
          int    totalQty = 0;
          double totalAmt = 0;
          for (final piece in widget.product.pieces) {
            final pieceProduct = Product(
              id:                 piece.cartId(widget.product.id),
              name:               '${widget.product.name} – ${piece.label}',
              price:              piece.effectivePrice,
              originalPrice:      piece.hasDiscount
                  ? piece.price
                  : piece.effectivePrice,
              image:              widget.product.image,
              imageUrl:           widget.product.imageUrl,
              category:           widget.product.category,
              weight:             piece.label,
              sku:                widget.product.sku,
              discountPercentage: piece.discountPct.toDouble(),
              quantity:           widget.product.quantity,
              posQuantity:        widget.product.posQuantity,
            );
            final q = cart.getQuantity(pieceProduct);
            totalQty += q;
            totalAmt += q * piece.effectivePrice;
          }

          final hasItems = totalQty > 0;
          final Color accent = hasItems
              ? AppColors.priceGreen
              : AppColors.buttonPrimary;
          final Color accentBorder = hasItems
              ? AppColors.priceGreen
              : Colors.grey[300]!;

          return GestureDetector(
            onTap: () => handleAddToCart(
              context: ctx,
              product: widget.product,
              pieces:  widget.product.pieces,
            ),
            child: Container(
              width:     double.infinity,
              height:    36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: accentBorder, width: 1.2),
              ),
              child: hasItems
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      'ADD (${widget.product.pieces.length} opp)',
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
                      widget.product.pieces.length == 1
                          ? '1 option'
                          : '${widget.product.pieces.length} options',
                      style: TextStyle(color: accent, fontSize: 8)),
                ],
              ),
            ),
          );
        }

        // ── No pieces, qty == 0 → plain ADD ──────────────────────────────
        final qty = cart.getQuantity(widget.product);
        if (qty == 0) {
          return GestureDetector(
            onTap: () => cart.addItem(widget.product),
            child: Container(
              width:     double.infinity,
              height:    30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.grey[300]!, width: 1.2),
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

        // ── No pieces, qty > 0 → stepper with inline edit + live price ───
        final liveQty   = _editing
            ? (int.tryParse(_ctrl.text) ?? qty)
            : qty;
        final liveTotal = (liveQty * widget.product.price).toInt();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 30,
              decoration: BoxDecoration(
                  color:        AppColors.buttonPrimary,
                  borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => cart.decrementQuantity(widget.product.id),
                    child: const SizedBox(
                        width: 30, height: 30,
                        child: Icon(Icons.remove,
                            color: Colors.white, size: 14)),
                  ),
                  if (_editing)
                    SizedBox(
                      width: 42,
                      child: TextField(
                        controller:   _ctrl,
                        focusNode:    _focus,
                        keyboardType: TextInputType.number,
                        textAlign:    TextAlign.center,
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   12,
                            fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                            border:         InputBorder.none,
                            isDense:        true,
                            contentPadding: EdgeInsets.zero),
                        onChanged:    (_) => setState(() {}),
                        onSubmitted:  (_) => _commitEdit(cart),
                        onTapOutside: (_) => _commitEdit(cart),
                      ),
                    )
                  else
                    GestureDetector(
                      onTapDown: (_) => _startEditing(qty),
                      child: Text('$qty',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   12,
                              fontWeight: FontWeight.bold)),
                    ),
                  GestureDetector(
                    onTap: () {
                      final stock = widget.product.quantity > 0
                          ? widget.product.quantity
                          : widget.product.posQuantity;
                      if (stock > 0 && qty >= stock) {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black26,
                          builder: (_) => Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 40),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                color:        Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20)],
                              ),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: AppColors.buttonPrimary,
                                        size:  36),
                                    const SizedBox(height: 12),
                                    Text(
                                        'Only $stock item${stock == 1 ? '' : 's'} available',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize:   15,
                                            fontWeight: FontWeight.w600,
                                            color:      Colors.black87)),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: () =>
                                          Navigator.pop(context),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32, vertical: 10),
                                        decoration: BoxDecoration(
                                            color: AppColors.buttonPrimary,
                                            borderRadius:
                                            BorderRadius.circular(8)),
                                        child: const Text('OK',
                                            style: TextStyle(
                                                color:      Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize:   14)),
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                        );
                        return;
                      }
                      cart.addItem(widget.product);
                    },
                    child: const SizedBox(
                        width: 30, height: 30,
                        child: Icon(Icons.add,
                            color: Colors.white, size: 14)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── See More Button ──────────────────────────────────────────────────────────
class _SeeMoreButton extends StatelessWidget {
  final int          count;
  final VoidCallback onTap;
  const _SeeMoreButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.lightBrown.withOpacity(0.08),
            AppColors.lightBrown.withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:AppColors.lightBrown.withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('See all $count products',
              style: const TextStyle(
                  color:      AppColors.appBarText,
                  fontWeight: FontWeight.bold,
                  fontSize:   13)),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios,
              size: 12, color: AppColors.lightBrown),
        ]),
      ),
    );
  }
}

// ─── All Products Screen ──────────────────────────────────────────────────────
class AllProductsScreen extends StatefulWidget {
  final String                    title;
  final List<CategoryDataProduct> products;

  const AllProductsScreen(
      {super.key, required this.title, required this.products});

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  static const int       _pageSize     = 40;
  int                    _visibleCount = _pageSize;
  final ScrollController _scroll       = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300 &&
        _visibleCount < widget.products.length) {
      setState(() => _visibleCount =
          (_visibleCount + _pageSize).clamp(0, widget.products.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.products.take(_visibleCount).toList();
    final hasMore = _visibleCount < widget.products.length;

    final screenW = MediaQuery.of(context).size.width;
    final cardW   = (screenW - 44) / 2;
    final imgH    = cardW * 0.72;
    final cardH   = imgH + 138;

    return Scaffold(
      backgroundColor: AppColors.white,
      // ── Floating cart bar ─────────────────────────────────────────────────
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: FloatingCartBar(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
            style: const TextStyle(
                color:      Colors.black,
                fontWeight: FontWeight.bold,
                fontSize:   18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
        actions: [
          Container(
            margin:  const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.lightBrown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${widget.products.length} items',
                style: const TextStyle(
                    color:      AppColors.appBarText,
                    fontSize:   12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: widget.products.isEmpty
          ? Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No products available',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 15)),
          ]))
          : RefreshIndicator(
        color:     AppColors.buttonPrimary,
        onRefresh: () async {
          setState(() => _visibleCount = _pageSize);
        },
        child: GridView.builder(
          controller: _scroll,
          physics:    const AlwaysScrollableScrollPhysics(),
          padding:    const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   2,
            mainAxisExtent:   cardH,
            crossAxisSpacing: 12,
            mainAxisSpacing:  12,
          ),
          itemCount: visible.length + (hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == visible.length) {
              return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        color: AppColors.lightBrown),
                  ));
            }
            return RepaintBoundary(
                child: ProductCard(product: _toProduct(visible[i]), imageHeight: imgH));
          },
        ),
      ),
    );
  }
}
