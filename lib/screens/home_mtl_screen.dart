

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/see_all.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_color.dart';
import '../model/cart_model.dart';
import '../model/favorites_model.dart';
import '../model/initial_model.dart';
import '../model/product_model.dart';
import '../products/product_card.dart';
import '../products/product_detail_screen.dart';
import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../services/banner_service.dart';
import '../services/home_banner_service.dart';
import '../services/session_manager.dart';
import '../widgets/floating_cart.dart';
import '../widgets/piece_selector_sheet.dart';
import 'offer_products_screen.dart';
import '../widgets/home_banner_slider.dart';

// ─── constants ────────────────────────────────────────────────────────────────
final String _kImgBase = ApiConfig.imageBase;
const int _kPreviewMax = 4;
const Duration _kAutoRefreshInterval = Duration(seconds: 5);

// ─── Blinkit-style colors ─────────────────────────────────────────────────────
const Color _kGreen       = AppColors.buttonPrimary;
const Color _kLightGreen  = AppColors.lightGreen;
const Color _kCardBg      = AppColors.cardWhite;
const Color _kTextPrimary = AppColors.textDark;
const Color _kTextSub     = AppColors.textGrey;
const Color _kBorder      = AppColors.border;
const Color _green        = AppColors.freshGreen;

// ─── Internal helper for category strip items ─────────────────────────────────
class _CatItem {
  final String       label;
  final String?      imageUrl;
  final String?      emoji;
  final bool         isSelected;
  final VoidCallback onTap;
  const _CatItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.imageUrl,
    this.emoji,
  });
}

class MtlTabBody extends StatefulWidget {
  final TextEditingController? externalSearchController;
  final FocusNode?             searchFocusNode;
  final LayerLink?             searchLayerLink;
  const MtlTabBody({
    super.key,
    this.externalSearchController,
    this.searchFocusNode,
    this.searchLayerLink,
  });

  @override
  State<MtlTabBody> createState() => _MtlTabBodyState();
}

class _MtlTabBodyState extends State<MtlTabBody> {
  bool              _loading = true;
  String?           _error;
  InitialDataModel? _data;

  Timer?            _autoRefreshTimer;
  bool              _newDataAvailable = false;
  InitialDataModel? _pendingData;
  bool              _isRefreshing     = false;

  String _selectedCatId = '';
  String _selectedSubId = '';

  // ── Subcategory "View All" state ──────────────────────────────────────────
  bool _catViewAll = false;
  bool _catViewAllMain = false;

  List<ApiBanner> _runningBanners = [];
  bool            _bannersLoaded  = false;
  List<ApiBanner> _bottomBanners  = [];

  final Map<String, _CatDetail> _catCache   = {};
  final Map<String, bool>       _catLoading = {};
  final Map<String, _CatDetail> _subCache   = {};
  final Map<String, bool>       _subLoading = {};

  late final LayerLink            _searchLayerLink;
  OverlayEntry?              _searchOverlay;
  late TextEditingController _searchController;
  late FocusNode             _searchFocus;
  List<_SearchResult>        _searchResults  = [];
  bool                       _ownsController = false;
  Timer?                     _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.externalSearchController != null) {
      _searchController = widget.externalSearchController!;
      _ownsController   = false;
      _searchController.addListener(_onExternalSearch);
    } else {
      _searchController = TextEditingController();
      _ownsController   = true;
    }
    _searchFocus = widget.searchFocusNode ?? FocusNode();
    if (widget.searchLayerLink != null) {
      _searchLayerLink = widget.searchLayerLink!;
    }
    _fetchInitialData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_kAutoRefreshInterval, (_) {
      _checkForNewData();
    });
  }

  // ── UPDATED: no longer clears the caches and fetches silently (no spinner) ──
  Future<void> _checkForNewData() async {
    if (!mounted || _isRefreshing) return;
    try {
      final token      = await SessionManager.getToken();
      final customerId = await SessionManager.getCustomerId();
      final result     = await getInitialData(customerId: customerId, token: token);
      if (!mounted) return;
      if (result['success'] != true) return;

      final newModel = InitialDataModel.fromJson(
          result['data'] as Map<String, dynamic>);

      setState(() {
        _data             = newModel;
        _newDataAvailable = false;
        _pendingData      = null;
      });

      // ✅ Silently refresh EVERY cached category, not just the currently
      // open one, so prices/stock update everywhere in the background.
      final catIdsToRefresh = _catCache.keys.toList();
      for (final catId in catIdsToRefresh) {
        if (!mounted) return;
        await _fetchCatDetail(catId, silent: true);
      }

      final subIdsToRefresh = _subCache.keys.toList();
      for (final subId in subIdsToRefresh) {
        if (!mounted) return;
        await _fetchSubDetail(subId, silent: true);
      }
    } catch (_) {}
  }


  void _applyPendingData() {
    if (_pendingData == null) return;
    setState(() {
      _data             = _pendingData;
      _pendingData      = null;
      _newDataAvailable = false;
      _catCache.clear();
      _subCache.clear();
      _catLoading.clear();
      _subLoading.clear();
    });
  }


  void _onExternalSearch() {
    final text = _searchController.text;
    setState(() {});
    _searchDebounce?.cancel();
    if (text.trim().isEmpty) { _closeOverlay(); return; }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_runSearch(text));
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchDebounce?.cancel();
    _closeOverlay();
    _searchController.removeListener(_onExternalSearch);
    if (_ownsController) _searchController.dispose();
    if (widget.searchFocusNode == null) _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchRunningBanners() async {
    final token   = await SessionManager.getToken();
    final banners = await getRunningBanners(token: token);
    if (mounted) {
      setState(() {
        _runningBanners = banners;
        _bannersLoaded  = true;
      });
    }
  }
  Future<void> _fetchBottomBanners() async {
    final token   = await SessionManager.getToken();
    final banners = await getBottomBanners(token: token);
    if (mounted) {
      setState(() {
        _bottomBanners = banners;
      });
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _loading = true; _error = null;
      _catCache.clear(); _subCache.clear();
      _catLoading.clear(); _subLoading.clear();
    });
    final token      = await SessionManager.getToken();
    final customerId = await SessionManager.getCustomerId();
    final result     = await getInitialData(
        customerId: customerId, token: token);
    if (!mounted) return;
    if (result['success'] == true) {
      final rawData = result['data'] as Map<String, dynamic>;
      final model   = InitialDataModel.fromJson(rawData);
      setState(() {
        _data             = model;
        _loading          = false;
        _newDataAvailable = false;
        _pendingData      = null;
      });
      _fetchRunningBanners();
      _fetchBottomBanners();
      _prefetchAllCategories(model);
      final favs         = context.read<FavoritesModel>();
      final liveProducts = model.randomProducts
          .map((p) => _toProduct(p))
          .toList();
      await favs.syncWithBackend(
        liveProducts.map((p) => p.id).toList(),
        liveProducts: liveProducts,
      );
    } else {
      setState(() {
        _error   = result['message']?.toString() ?? 'Unknown error';
        _loading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() { _isRefreshing = true; });
    await _fetchInitialData();
    setState(() { _isRefreshing = false; });
  }

  Future<void> _prefetchAllCategories(InitialDataModel model) async {
    final toFetch = model.categories
        .where((cat) => !_catCache.containsKey(cat.categoryId))
        .toList();
    if (toFetch.isEmpty || !mounted) return;
    await Future.wait(
      toFetch.map((cat) => _fetchCatDetail(cat.categoryId)),
    );
  }

  Future<void> refresh() async { await _onRefresh(); }

  // ── UPDATED: supports `silent` background refresh (no loader flag) ─────────
  Future<void> _fetchCatDetail(String catId, {bool silent = false}) async {
    if (!silent && _catCache.containsKey(catId)) return;
    if (!silent) setState(() => _catLoading[catId] = true);
    try {
      final token  = await SessionManager.getToken();
      final result = await getCategoryData(token: token, categoryId: catId);
      if (!mounted) return;
      if (result['success'] == true) {
        final raw      = result['data'] as Map<String, dynamic>? ?? {};
        final rawSubs  = raw['subcategories'] as List? ?? [];
        final rawProds = raw['products']      as List? ?? [];
        final childSubs = <_ChildSub>[];
        for (final s in rawSubs) {
          final sMap     = s as Map<String, dynamic>;
          final subProds = <_SubProduct>[];
          for (final p in (sMap['products'] as List? ?? [])) {
            final prod = _SubProduct.fromJson(p as Map<String, dynamic>);
            if (prod != null) subProds.add(prod);
          }
          childSubs.add(_ChildSub(
            categoryId: sMap['category_id']?.toString() ?? '',
            name:       sMap['name']?.toString()        ?? '',
            image:      sMap['image']?.toString()       ?? '',
            products:   subProds,
          ));
        }
        final directProds = <_SubProduct>[];
        for (final p in rawProds) {
          final prod = _SubProduct.fromJson(p as Map<String, dynamic>);
          if (prod != null) directProds.add(prod);
        }
        setState(() {
          _catCache[catId] =
              _CatDetail(childSubs: childSubs, directProducts: directProds);
          if (!silent) _catLoading[catId] = false;
        });
      } else {
        // Fetch failed — don't cache, so a retry can actually happen later.
        if (!silent) setState(() => _catLoading[catId] = false);
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _catLoading[catId] = false);
      }
    }
  }

  // ── UPDATED: supports `silent` background refresh (no loader flag) ─────────
  Future<void> _fetchSubDetail(String subId, {bool silent = false}) async {
    if (!silent && _subCache.containsKey(subId)) return;
    if (!silent) setState(() => _subLoading[subId] = true);
    try {
      final token  = await SessionManager.getToken();
      final result = await getCategoryData(token: token, categoryId: subId);
      if (!mounted) return;
      if (result['success'] == true) {
        final raw      = result['data'] as Map<String, dynamic>? ?? {};
        final rawSubs  = raw['subcategories'] as List? ?? [];
        final rawProds = raw['products']      as List? ?? [];
        final childSubs = <_ChildSub>[];
        for (final s in rawSubs) {
          final sMap     = s as Map<String, dynamic>;
          final subProds = <_SubProduct>[];
          for (final p in (sMap['products'] as List? ?? [])) {
            final prod = _SubProduct.fromJson(p as Map<String, dynamic>);
            if (prod != null) subProds.add(prod);
          }
          childSubs.add(_ChildSub(
            categoryId: sMap['category_id']?.toString() ?? '',
            name:       sMap['name']?.toString()        ?? '',
            image:      sMap['image']?.toString()       ?? '',
            products:   subProds,
          ));
        }
        final directProds = <_SubProduct>[];
        for (final p in rawProds) {
          final prod = _SubProduct.fromJson(p as Map<String, dynamic>);
          if (prod != null) directProds.add(prod);
        }
        setState(() {
          _subCache[subId] =
              _CatDetail(childSubs: childSubs, directProducts: directProds);
          if (!silent) _subLoading[subId] = false;
        });
      } else {
        if (!silent) setState(() => _subLoading[subId] = false);
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _subLoading[subId] = false);
      }
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────
  Future<void> _runSearch(String query) async {
    setState(() {});
    if (query.trim().isEmpty) { _closeOverlay(); return; }
    final q       = query.toLowerCase();
    final results = <_SearchResult>[];

    for (final cat in _data?.categories ?? []) {
      // ── ensure this category's products are loaded before searching it ──
      if (!_catCache.containsKey(cat.categoryId)) {
        await _fetchCatDetail(cat.categoryId);
      }
      if (!mounted) return;

      if (cat.name.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          type:     _SearchType.category,
          id:       cat.categoryId,
          label:    cat.name,
          subtitle: 'Category',
          imageUrl: cat.imageUrl,
          onTap: () {
            _closeOverlay(); _searchController.clear();
            setState(() { _selectedCatId = cat.categoryId; _selectedSubId = ''; });
            _fetchCatDetail(cat.categoryId);
          },
        ));
      }
      final catDetail = _catCache[cat.categoryId];
      if (catDetail != null) {
        // ── products directly under the category (no subcategory) ──
        for (final p in catDetail.directProducts) {
          if (p.name.toLowerCase().contains(q)) {
            results.add(_SearchResult(
              type:     _SearchType.product,
              id:       p.productId,
              label:    p.name,
              subtitle: '₹${p.price.toInt()} · ${cat.name}',
              imageUrl: p.imageUrl,
              onTap: () {
                _closeOverlay(); _searchController.clear();
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: p.toProduct()),
                ));
              },
            ));
          }
        }
        for (final sub in catDetail.childSubs) {
          if (sub.name.toLowerCase().contains(q)) {
            results.add(_SearchResult(
              type:     _SearchType.subcategory,
              id:       sub.categoryId,
              label:    sub.name,
              subtitle: 'in ${cat.name}',
              imageUrl: sub.imageUrl,
              onTap: () {
                _closeOverlay(); _searchController.clear();
                setState(() {
                  _selectedCatId = cat.categoryId;
                  _selectedSubId = sub.categoryId;
                });
              },
            ));
          }
          for (final p in sub.products) {
            if (p.name.toLowerCase().contains(q)) {
              results.add(_SearchResult(
                type:     _SearchType.product,
                id:       p.productId,
                label:    p.name,
                subtitle: '₹${p.price.toInt()} · ${sub.name}',
                imageUrl: p.imageUrl,
                onTap: () {
                  _closeOverlay(); _searchController.clear();
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: p.toProduct()),
                  ));
                },
              ));
            }
          }
        }
      }
    }
    for (final p in _data?.randomProducts ?? []) {
      if (p.name.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          type:     _SearchType.product,
          id:       p.productId,
          label:    p.name,
          subtitle: '₹${p.retailPrice.toInt()} · Featured',
          imageUrl: p.imageUrl,
          onTap: () {
            _closeOverlay(); _searchController.clear();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: _toProduct(p)),
            ));
          },
        ));
      }
    }
    for (final offer in _data?.offers ?? []) {
      if (offer.name.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          type:     _SearchType.offer,
          id:       offer.categoryId,
          label:    offer.name,
          subtitle: '${offer.products.length} products · Special Offer',
          imageUrl: '',
          onTap: () {
            _closeOverlay(); _searchController.clear();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => OfferProductsScreen(
                offerName: offer.name,
                products:  offer.products.map((p) => _toProduct(p)).toList(),
              ),
            ));
          },
        ));
      }
      for (final p in offer.products) {
        if (p.name.toLowerCase().contains(q)) {
          results.add(_SearchResult(
            type:     _SearchType.product,
            id:       p.productId,
            label:    p.name,
            subtitle: '₹${p.retailPrice.toInt()} · ${offer.name}',
            imageUrl: p.imageUrl,
            onTap: () {
              _closeOverlay(); _searchController.clear();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: _toProduct(p)),
              ));
            },
          ));
        }
      }
    }
    if (!mounted) return;
    // ── dedupe: keep only the first occurrence of each type+id ──
    final seen = <String>{};
    final deduped = <_SearchResult>[];
    for (final r in results) {
      final key = '${r.type}-${r.id}';
      if (seen.add(key)) deduped.add(r);
    }
    setState(() {
      final products = deduped.where((r) => r.type == _SearchType.product).toList();
      final others   = deduped.where((r) => r.type != _SearchType.product).toList();
      _searchResults = [...products.take(20), ...others.take(10)];
    });
    _showOverlay();
  }

  void _showOverlay() {
    _closeOverlay();
    if (_searchResults.isEmpty) return;
    final overlay = Overlay.of(context);
    _searchOverlay = OverlayEntry(
      builder: (_) => _SearchPopup(
        link:      _searchLayerLink,
        results:   _searchResults,
        onDismiss: _closeOverlay,
      ),
    );
    overlay.insert(_searchOverlay!);
  }

  void _closeOverlay() { _searchOverlay?.remove(); _searchOverlay = null; }

  LayerLink get searchLayerLink => _searchLayerLink;

  Product _toProduct(ApiProduct p) {
    return Product(
      id:                 p.productId.isNotEmpty
          ? p.productId
          : (p.sku.isNotEmpty ? p.sku : p.name),
      name:               p.name,
      price:              p.retailPrice,
      originalPrice:      p.wholesalePrice,
      image:              p.image,
      imageUrl:           p.imageUrl,
      category:           p.category,
      weight:             p.unit,
      sku:                p.sku,
      discountPercentage: p.discountPercent,
      quantity:           p.quantity,
      posQuantity:        p.quantity,
      pieces:             p.pieces,
      isCombo:            p.isCombo,
    );
  }

  ApiCategory? get _selectedCategory {
    if (_selectedCatId.isEmpty || _data == null) return null;
    try {
      return _data!.categories
          .firstWhere((c) => c.categoryId == _selectedCatId);
    } catch (_) { return null; }
  }

  List<ApiProduct> get _visibleProducts => _data?.randomProducts ?? [];
  List<ApiProduct> get _comboProducts   => _data?.comboProducts  ?? [];

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(
              child: CircularProgressIndicator(color: _kGreen)),
        ),
      );
    }
    if (_error != null) return SliverToBoxAdapter(child: _buildError());

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _CategoryStripWrapper(
            newDataBanner: _newDataAvailable
                ? _NewDataBanner(
              onTap: _applyPendingData,
              onDismiss: () => setState(() {
                _newDataAvailable = false;
                _pendingData      = null;
              }),
            )
                : null,
            child: _buildCategoryStrip(),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 8),
            if (_selectedCatId.isNotEmpty) ...[
              _buildCategoryDetailSection(),
              const SizedBox(height: 2),
            ],
            _buildDayBanner(),
            _buildFeaturedProducts(),
            _buildComboProducts(),
            _buildRunningBanners(),
            _buildOffersSection(),
            _buildBottomBanners(),
            // const SizedBox(height: 12),
          ]),
        ),
      ],
    );
  }
  // ── Bottom Banners (Today's Deals — type=3, shown last) ────────────────
  Widget _buildBottomBanners() {
    if (_bottomBanners.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: "Today's Deals", icon: Icons.local_fire_department),
      SizedBox(
        height: 180,
        child: PageView.builder(
          padEnds:    true,
          controller: PageController(
              viewportFraction: 0.92,
              initialPage:      _bottomBanners.length * 500),
          itemCount:  null,
          itemBuilder: (_, i) {
            final b = _bottomBanners[i % _bottomBanners.length];
            return GestureDetector(
              onTap: () => _openBannerCategory(b),
              child: Padding(
                padding: const EdgeInsets.only(right: 10, left: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: b.imageUrl.isNotEmpty
                      ? Image.network(b.imageUrl, fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade100))
                      : Container(color: Colors.grey.shade100),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ── Category strip — 5 per row, 2 rows max, "Shop by Categories / View All" ─
  Widget _buildCategoryStrip() {
    final cats = _data?.categories ?? [];

    final allItems = <_CatItem>[
      ...cats.map((cat) => _CatItem(
        label:      cat.name,
        imageUrl:   cat.imageUrl.isNotEmpty ? cat.imageUrl : null,
        isSelected: _selectedCatId == cat.categoryId,
        onTap: () => setState(() {
          _selectedCatId  = cat.categoryId;
          _selectedSubId  = '';
          _catViewAll     = false;
          _catViewAllMain = false;
          _fetchCatDetail(cat.categoryId);
        }),
      )),
    ];

    const int kMax = 8;
    final showItems = _catViewAllMain ? allItems : allItems.take(kMax).toList();
    final hasMore   = allItems.length > kMax;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: [
          // ── Header row ─────────────────────────────────────────────
          const Text(
            'Order by Categories',
            style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w700,
                color:      _kTextPrimary),
          ),
          const SizedBox(height: 8),
          // ── 5-column grid ──────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: showItems.map((item) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 50) / 4,
                child: _buildCatChip(
                  label: item.label,
                  imageUrl: item.imageUrl,
                  emoji: item.emoji,
                  isSelected: item.isSelected,
                  onTap: item.onTap,
                ),
              );
            }).toList(),
          ),
          if (hasMore) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  setState(() => _catViewAllMain = !_catViewAllMain);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _catViewAllMain ? 'View Less' : 'View All',
                    style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      _green ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Reusable chip (category + subcategory) ────────────────────────────────
  Widget _buildCatChip({
    required String    label,
    required bool      isSelected,
    required VoidCallback onTap,
    String?  imageUrl,
    String?  emoji,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: isSelected
                  ? _kGreen.withOpacity(0.12)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _kGreen : const Color(0xFFE0E0E0),
                width: isSelected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _catFallback(isSelected, emoji),
            )
                : _catFallback(isSelected, emoji),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color:      isSelected ? _kGreen : _kTextPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
            softWrap:  true,
          ),
        ],
      ),
    );
  }

  Widget _catFallback(bool sel, String? emoji) => Center(
    child: emoji != null
        ? Text(emoji, style: const TextStyle(fontSize: 20))
        : Icon(Icons.grid_view_rounded,
        color: sel ? _kGreen : Colors.grey.shade400, size: 20),
  );

  // ── Category detail — subcategories 5 per row + "View All" header ─────────
  Widget _buildCategoryDetailSection() {
    final isLoading = _catLoading[_selectedCatId] ?? false;
    final detail    = _catCache[_selectedCatId];

    if (detail == null && isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: _kGreen)),
      );
    }
    if (detail == null) return const SizedBox.shrink();

    final hasChildSubs   = detail.childSubs.isNotEmpty;
    final hasDirectProds = detail.directProducts.isNotEmpty;

    if (!hasChildSubs && !hasDirectProds) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(children: [
          Icon(Icons.inventory_2_outlined,
              size: 42, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text('No products available',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ]),
      );
    }

    final allSubs = detail.childSubs;

    const int kSubMax = 4;
    final showSubs  = _catViewAll
        ? allSubs
        : allSubs.take(kSubMax).toList();
    final hasMore   = allSubs.length > kSubMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasChildSubs) ...[
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 8,
            color:  const Color(0xFFF5F5F5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                // ── Header row ──────────────────────────────────────
                Text(
                  _selectedCategory?.name ?? 'Subcategories',
                  style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      _kTextPrimary),
                ),
                const SizedBox(height: 4),
                // ── 5-column subcategory grid ────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: showSubs.map((sub) {
                    final isSelected = _selectedSubId == sub.categoryId;

                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 50) / 4,
                      child: _buildCatChip(
                        label: sub.name,
                        imageUrl: sub.imageUrl.isNotEmpty ? sub.imageUrl : null,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => _selectedSubId = sub.categoryId);
                          _fetchSubDetail(sub.categoryId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _CategoryFullPage(
                                parentName:     _selectedCategory?.name ?? sub.name,
                                parentImage:    _selectedCategory?.imageUrl ?? '',
                                allSubs:        allSubs,
                                initialSubId:   sub.categoryId,
                                directProducts: const [],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
                if (hasMore) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _catViewAll = !_catViewAll),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _catViewAll ? 'View Less' : 'View All',
                          style: const TextStyle(
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                              color:      _green),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        if (hasDirectProds) ...[
          const SizedBox(height: 2),
          _buildDirectProducts('', detail.directProducts),
        ],
      ],
    );
  }

  Widget _buildChildSubProducts(_CatDetail detail) {
    final subList = detail.childSubs
        .where((s) => s.categoryId == _selectedSubId)
        .toList();
    if (subList.isEmpty) return const SizedBox.shrink();
    final s = subList.first;

    final isLoading = _subLoading[_selectedSubId] ?? false;
    final subDetail = _subCache[_selectedSubId];
    final products  = subDetail != null ? subDetail.directProducts : s.products;
    final bool showSeeMore = products.length > _kPreviewMax;

    final VoidCallback? onSeeMore = showSeeMore
        ? () => _goToFullCategoryPage(
      parentName:   _selectedCategory?.name ?? s.name,
      parentImage:  _selectedCategory?.imageUrl ?? '',
      allSubs:      detail.childSubs,
      initialSubId: _selectedSubId,
    )
        : null;

    return Container(
      width:  double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color:     Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                      color: _kGreen,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(s.name,
                      style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                          color:      _kTextPrimary),
                      overflow: TextOverflow.ellipsis)),
            ]),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: _kGreen)),
            )
          else if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Icon(Icons.inventory_2_outlined,
                    size: 36, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('No products in ${s.name}',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 13)),
              ]),
            )
          else ...[
              _HorizontalProductRow(
                  products:  products,
                  cap:       _kPreviewMax,
                  onSeeMore: onSeeMore),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildDirectProducts(
      String catName, List<_SubProduct> prods) {
    if (prods.isEmpty) return const SizedBox.shrink();
    final bool showSeeMore = prods.length > _kPreviewMax;
    final VoidCallback? onSeeMore = showSeeMore
        ? () => _goToFullCategoryPage(
      parentName:     catName.isNotEmpty
          ? catName
          : (_selectedCategory?.name ?? ''),
      parentImage:    _selectedCategory?.imageUrl ?? '',
      allSubs:        _catCache[_selectedCatId]?.childSubs ?? [],
      initialSubId:   '__direct__',
      directProducts: prods,
    )
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (catName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                    color: _kGreen,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(catName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      _HorizontalProductRow(
          products: prods, cap: _kPreviewMax, onSeeMore: onSeeMore),
      if (onSeeMore != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: GestureDetector(
            onTap: onSeeMore,
            child: _viewAllButton('View All'),
          ),
        ),
    ]);
  }

  void _goToFullCategoryPage({
    required String            parentName,
    required String            parentImage,
    required List<_ChildSub>   allSubs,
    required String            initialSubId,
    List<_SubProduct> directProducts = const [],
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CategoryFullPage(
          parentName:     parentName,
          parentImage:    parentImage,
          allSubs:        allSubs,
          initialSubId:   initialSubId,
          directProducts: directProducts,
        ),
      ),
    );
  }

  // ── Auto-scroll banner — now wired to category navigation ────────────
  Widget _buildDayBanner() => HomeBannerSlider(
    onCategoryTap: (BannerItem banner) => _openCategoryById(
      categoryId:   banner.categoryId,
      hasCategory:  banner.hasCategory,
      fallbackLink: banner.fullLink,
      categoryName: banner.categoryName,
    ),
  );

  // ── Featured Products ─────────────────────────────────────────────────────
  Widget _buildFeaturedProducts() {
    final products = _visibleProducts;
    if (products.isEmpty) return const SizedBox.shrink();
    const title  = 'Featured Products';
    final screenW = MediaQuery.of(context).size.width;
    final cardW   = screenW * 0.32;
    final imgH    = cardW * 0.80;
    final cardH   = imgH + 113.0;
    const int previewCount = 4;
    final bool hasSeeMore  = products.length > previewCount;
    final displayProducts  =
    hasSeeMore ? products.take(previewCount).toList() : products;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: title, icon: Icons.auto_awesome),
      SizedBox(
        height: cardH,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:         const EdgeInsets.symmetric(horizontal: 16),
          itemCount:       displayProducts.length,
          itemBuilder: (_, i) => SizedBox(
            width: cardW,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ProductCard(
                product:     _toProduct(displayProducts[i]),
                imageHeight: imgH,
              ),
            ),
          ),
        ),
      ),
      if (hasSeeMore)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeeAllScreen(
                  title:    title,
                  products: products.map((p) => _toProduct(p)).toList(),
                ),
              ),
            ),
            child: _viewAllButton('See all products'),
          ),
        ),
    ]);
  }

  // ── Combo Products ────────────────────────────────────────────────────────
  Widget _buildComboProducts() {
    final combos = _comboProducts;
    if (combos.isEmpty) return const SizedBox.shrink();
    final screenW = MediaQuery.of(context).size.width;
    final cardW   = screenW * 0.32;
    final imgH    = cardW * 0.80;
    final cardH   = imgH + 113.0;
    const int previewCount = 4;
    final bool hasSeeMore  = combos.length > previewCount;
    final displayCombos    =
    hasSeeMore ? combos.take(previewCount).toList() : combos;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Combo Deals', icon: Icons.card_giftcard),
      SizedBox(
        height: cardH,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:         const EdgeInsets.symmetric(horizontal: 16),
          itemCount:       displayCombos.length,
          itemBuilder: (_, i) => SizedBox(
            width: cardW,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ProductCard(
                product:     _toProduct(displayCombos[i]),
                imageHeight: imgH,
              ),
            ),
          ),
        ),
      ),
      if (hasSeeMore)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeeAllScreen(
                  title:    'Combo Deals',
                  products: combos.map((p) => _toProduct(p)).toList(),
                ),
              ),
            ),
            child: _viewAllButton('See all combos'),
          ),
        ),
    ]);
  }

  // ── Running Banners (Promotions section) ──────────────────────────────
  Widget _buildRunningBanners() {
    if (_runningBanners.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: 'Promotions', icon: Icons.campaign),
      SizedBox(
        height: 180,
        child: PageView.builder(
          padEnds:    true,
          controller: PageController(
              viewportFraction: 0.92,
              initialPage:      _runningBanners.length * 500),
          itemCount:  null,
          itemBuilder: (_, i) {
            final b = _runningBanners[i % _runningBanners.length];
            return GestureDetector(
              onTap: () => _openBannerCategory(b),
              child: Padding(
                padding: const EdgeInsets.only(right: 10, left: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: b.imageUrl.isNotEmpty
                      ? Image.network(b.imageUrl, fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade100))
                      : Container(color: Colors.grey.shade100),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Future<void> _openCategoryById({
    required String categoryId,
    required bool   hasCategory,
    required String fallbackLink,
    required String categoryName,
  }) async {
    if (!hasCategory) {
      if (fallbackLink.isNotEmpty) {
        launchUrl(Uri.parse(fallbackLink), mode: LaunchMode.externalApplication);
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _kGreen),
      ),
    );

    try {
      final token  = await SessionManager.getToken();
      final result = await getBannerProducts(
          token: token, categoryId: categoryId);

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this offer right now')),
        );
        return;
      }

      final raw      = result['data'] as Map<String, dynamic>? ?? {};
      final rawSubs  = raw['subcategories'] as List? ?? [];
      final rawProds = raw['products']      as List? ?? [];

      final childSubs = <_ChildSub>[];
      for (final s in rawSubs) {
        final sMap     = s as Map<String, dynamic>;
        final subProds = <_SubProduct>[];
        for (final p in (sMap['products'] as List? ?? [])) {
          final prod = _SubProduct.fromJson(p as Map<String, dynamic>);
          if (prod != null) subProds.add(prod);
        }
        childSubs.add(_ChildSub(
          categoryId: sMap['category_id']?.toString() ?? '',
          name:       sMap['name']?.toString()        ?? '',
          image:      sMap['image']?.toString()       ?? '',
          products:   subProds,
        ));
      }

      final directProds = <_SubProduct>[];
      for (final p in rawProds) {
        final prod = _SubProduct.fromJson(p as Map<String, dynamic>);
        if (prod != null) directProds.add(prod);
      }
      _catCache[categoryId] =
          _CatDetail(childSubs: childSubs, directProducts: directProds);

      final String screenTitle = categoryName.isNotEmpty ? categoryName : 'Offer';

      if (childSubs.isEmpty && directProds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products found in this category')),
        );
        return;
      }
      if (!mounted) return;
      final String categoryImage = raw['image']?.toString() ?? '';

      // If category has both direct products AND subcategories,
      // always land on __direct__ (All tab) first so products are visible.
      final String resolvedInitialSubId = directProds.isNotEmpty
          ? '__direct__'
          : childSubs.isNotEmpty
          ? childSubs.first.categoryId
          : '__direct__';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CategoryFullPage(
            parentName:     screenTitle,
            parentImage:    categoryImage,
            allSubs:        childSubs,
            initialSubId:   resolvedInitialSubId,
            directProducts: directProds,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong opening this offer')),
        );
      }
    }
  }

  // Thin wrapper kept so the Promotions banner section needs no other changes.
  Future<void> _openBannerCategory(ApiBanner b) => _openCategoryById(
    categoryId:   b.categoryId,
    hasCategory:  b.hasCategory,
    fallbackLink: b.link,
    categoryName: b.categoryName,
  );

  // ── Offers Section ────────────────────────────────────────────────────────
  Widget _buildOffersSection() {
    final offers  = _data?.offers ?? [];
    if (offers.isEmpty) return const SizedBox.shrink();
    final screenW = MediaQuery.of(context).size.width;
    final cardW   = screenW * 0.33;
    final imgH    = cardW * 0.80;
    final cardH   = imgH + 113.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final offer in offers) ...[
        if (offer.products.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: RichText(
              text: TextSpan(children: [
                const TextSpan(
                  text:  'Trending in ',
                  style: TextStyle(
                      color:      _kTextPrimary,
                      fontSize:   16,
                      fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:  offer.name,
                  style: const TextStyle(
                      color:      AppColors.primaryOrange,
                      fontSize:   16,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
          SizedBox(
            height: cardH,
            child: Builder(builder: (context) {
              final previewProducts = offer.products.take(4).toList();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:         const EdgeInsets.symmetric(horizontal: 16),
                itemCount:       previewProducts.length,
                itemBuilder: (_, i) {
                  final product = _toProduct(previewProducts[i]);
                  return RepaintBoundary(
                    key: ValueKey(
                        'offer_${offer.categoryId}_${product.id}'),
                    child: SizedBox(
                      width: cardW,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ProductCard(
                            product: product, imageHeight: imgH),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          if (offer.products.length > 4)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OfferProductsScreen(
                      offerName: offer.name,
                      products:  offer.products
                          .map((p) => _toProduct(p))
                          .toList(),
                    ),
                  ),
                ),
                child: _viewAllButton('See all in ${offer.name}'),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ],
    ]);
  }

  // ── Shared "View All / See All" button ─────────────────────────────────────
  Widget _viewAllButton(String label) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('View All',
                style: TextStyle(
                    color:      _green ,
                    fontSize:   13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_forward, color: _green , size: 13),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(_error!,
            style:     TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _fetchInitialData,
          style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
          child: const Text('Retry',
              style: TextStyle(color: Colors.white)),
        ),
      ]),
    ),
  );
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String   title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        Icon(icon, color: _kGreen, size: 18),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w800,
                color:      _kTextPrimary)),
      ]),
    );
  }
}

// ── Category strip wrapper ────────────────────────────────────────────────────
class _CategoryStripWrapper extends StatelessWidget {
  final Widget  child;
  final Widget? newDataBanner;
  const _CategoryStripWrapper({required this.child, this.newDataBanner});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize:        MainAxisSize.min,
        crossAxisAlignment:  CrossAxisAlignment.stretch,
        children: [
          if (newDataBanner != null) newDataBanner!,
          child,
        ],
      ),
    );
  }
}

// ── New Data Banner ───────────────────────────────────────────────────────────
class _NewDataBanner extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NewDataBanner({required this.onTap, required this.onDismiss});

  @override
  State<_NewDataBanner> createState() => _NewDataBannerState();
}

class _NewDataBannerState extends State<_NewDataBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
          begin: const Offset(0, -1), end: Offset.zero)
          .animate(_slide),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        decoration: BoxDecoration(
          color:        _kGreen,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color:     _kGreen.withOpacity(0.3),
                blurRadius: 8,
                offset:     const Offset(0, 3))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Row(children: [
                const Icon(Icons.refresh, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'New products available! Tap to refresh',
                    style: TextStyle(
                        color:      Colors.white,
                        fontSize:   12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(Icons.close,
                      color: Colors.white70, size: 16),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Horizontal product row ────────────────────────────────────────────────────
class _HorizontalProductRow extends StatelessWidget {
  final List<_SubProduct> products;
  final int?              cap;
  final VoidCallback?     onSeeMore;

  const _HorizontalProductRow({
    required this.products,
    required this.cap,
    this.onSeeMore,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final screenW    = MediaQuery.of(context).size.width;
    final cardW      = screenW * 0.32;
    final imgH       = cardW * 0.80;
    final cardH      = imgH + 113.0;
    final shown = cap != null ? products.take(cap!).toList() : products;

    return SizedBox(
      height: cardH,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.fromLTRB(16, 6, 16, 0),
        itemCount:       shown.length,
        itemBuilder: (_, i) => SizedBox(
          width: cardW,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ProductCard(
                product: shown[i].toProduct(), imageHeight: imgH),
          ),
        ),
      ),
    );
  } // closes build()
} // closes _HorizontalProductRow class

// ─── Internal models ──────────────────────────────────────────────────────────
class _CatDetail {
  final List<_ChildSub>   childSubs;
  final List<_SubProduct> directProducts;
  const _CatDetail({required this.childSubs, required this.directProducts});
}

class _ChildSub {
  final String            categoryId;
  final String            name;
  final String            image;
  final List<_SubProduct> products;
  const _ChildSub({
    required this.categoryId,
    required this.name,
    required this.image,
    required this.products,
  });
  // String get imageUrl {
  //   if (image.isEmpty || image == 'no_image.png') return '';
  //   return image.startsWith('http') ? image : '$_kImgBase$image';
  // }
  String get imageUrl {
    if (image.isEmpty) return '';
    if (image == 'no_image.png') return '';
    if (image == 'no_image.jpg') return '';
    if (image == 'null') return '';
    return image.startsWith('http') ? image : '$_kImgBase$image';
  }
}

class _SubProduct {
  final String           productId;
  final String           name;
  final String           image;
  final double           price;
  final double           wholesale;
  final int              qty;
  final String           sku;
  final String           unit;
  final List<ProductPiece> pieces;

  const _SubProduct({
    required this.productId,
    required this.name,
    required this.image,
    required this.price,
    required this.wholesale,
    required this.qty,
    required this.sku,
    required this.unit,
    required this.pieces,
  });

  static _SubProduct? fromJson(Map<String, dynamic> j) {
    try {
      final piecesList = (j['pieces'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      Map<String, dynamic>? defaultPieceMap;
      for (final p in piecesList) {
        if (p['piece_default']?.toString() == '1') {
          defaultPieceMap = p;
          break;
        }
      }
      if (defaultPieceMap == null && piecesList.isNotEmpty) {
        defaultPieceMap = piecesList.reduce((a, b) {
          final aP =
              double.tryParse(a['price']?.toString() ?? '0') ?? 0;
          final bP =
              double.tryParse(b['price']?.toString() ?? '0') ?? 0;
          return aP >= bP ? a : b;
        });
      }

      final String rawUnit =
      defaultPieceMap?['piece']?.toString().isNotEmpty == true
          ? defaultPieceMap!['piece'].toString()
          : (j['piece']?.toString() ?? '').isNotEmpty
          ? j['piece'].toString()
          : (j['barcode_type']?.toString() ?? '');

      final double rawPrice =
          double.tryParse(j['price']?.toString() ?? '0') ?? 0;
      final double specialPrice =
          double.tryParse(j['special_price']?.toString() ?? '0') ?? 0;
      final double piecePrice = double.tryParse(
          defaultPieceMap?['price']?.toString() ?? '0') ??
          0;
      final double pieceSp = double.tryParse(
          defaultPieceMap?['special_price']?.toString() ?? '0') ??
          0;

      final stockStatus =
          j['stock_status']?.toString().toLowerCase() ?? '';
      final subtract  = j['subtract']?.toString() ?? '';
      final rawQtyStr = j['pos_quentity']?.toString() ??
          j['quantity']?.toString() ?? '';

      int qty;
      if (stockStatus.isNotEmpty &&
          (stockStatus == 'out of stock' ||
              stockStatus == '0' ||
              stockStatus == 'outofstock')) {
        qty = 0;
      } else if (stockStatus.isNotEmpty &&
          (stockStatus.contains('in stock') ||
              stockStatus == '1' ||
              stockStatus == '2')) {
        qty = 1;
      } else if (subtract == '0') {
        qty = 1;
      } else if (rawQtyStr.isEmpty || rawQtyStr == 'null') {
        qty = 1;
      } else {
        qty = int.tryParse(rawQtyStr) ?? 1;
        if (qty == 0 && stockStatus.isEmpty && subtract.isEmpty) qty = 1;
      }

      final double finalPrice;
      final double finalWholesale;
      final bool pieceHasOffer   = pieceSp > 0 && pieceSp < piecePrice;
      final bool productHasOffer = specialPrice > 0 && specialPrice < rawPrice;

      if (pieceHasOffer) {
        finalPrice = pieceSp; finalWholesale = piecePrice;
      } else if (piecePrice > 0 && productHasOffer) {
        finalPrice = specialPrice; finalWholesale = rawPrice;
      } else if (piecePrice > 0) {
        finalPrice = piecePrice; finalWholesale = 0;
      } else if (productHasOffer) {
        finalPrice = specialPrice; finalWholesale = rawPrice;
      } else {
        finalPrice = rawPrice; finalWholesale = 0;
      }

      final String productRawImage =
          j['image']?.toString() ?? '';
      final String defaultPieceRawImage =
          defaultPieceMap?['image']?.toString() ?? '';
      final String resolvedImage =
      (defaultPieceRawImage.isNotEmpty &&
          defaultPieceRawImage != 'no_image.png')
          ? defaultPieceRawImage
          : productRawImage;

      return _SubProduct(
        productId: j['product_id']?.toString() ?? '',
        name:      j['name']?.toString()       ?? '',
        image:     resolvedImage,
        price:     finalPrice,
        wholesale: finalWholesale,
        qty:       qty,
        sku:       j['sku']?.toString() ?? '',
        unit:      rawUnit,
        pieces: (j['pieces'] as List? ?? []).map((e) {
          final pm = e as Map<String, dynamic>;
          final pp =
              double.tryParse(pm['price']?.toString() ?? '0') ?? 0.0;
          final ps = double.tryParse(
              pm['special_price']?.toString() ?? '0') ??
              0.0;
          final minQty =
              int.tryParse(pm['min_quantity']?.toString() ?? '0') ?? 0;
          final pName  = pm['piece']?.toString() ?? '';
          final pieceRawStock = int.tryParse(
              (pm['pos_quantity'] ??
                  pm['pos_quentity'] ??
                  pm['quantity'] ??
                  '0')
                  .toString()) ??
              0;
          final productIsCombo =
              (j['is_combo']?.toString() ?? 'No').toLowerCase() == 'yes';
          final productLevelQty = int.tryParse(
              (j['pos_quentity'] ?? j['quantity'] ?? '0')
                  .toString()) ??
              0;
          // combo → product-level stock; non-combo → piece-level stock
          final stock = productIsCombo
              ? productLevelQty
              : pieceRawStock;
          return ProductPiece(
            pieceId:     pm['piece_id']?.toString() ??
                pm['id']?.toString() ??
                '',
            label:       (minQty > 1 && pName.isNotEmpty)
                ? '$pName × $minQty'
                : pName,
            price:       pp,
            specialPrice: ps,
            image:       pm['image']?.toString() ?? '',
            minQuantity: minQty,
            isCombo:     (pm['is_combo']?.toString() ?? 'No')
                .toLowerCase() ==
                'yes',
            stock: stock,
          );
        }).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  String get imageUrl {
    if (image.isEmpty || image == 'no_image.png') return '';
    return image.startsWith('http') ? image : '$_kImgBase$image';
  }

  bool get isInStock => qty > 0;

  int get discountPercent {
    if (wholesale <= 0 || wholesale <= price) return 0;
    return ((wholesale - price) / wholesale * 100).round();
  }

  Product toProduct() => Product(
    id:                 productId,
    name:               name,
    price:              price,
    originalPrice:      wholesale > 0 ? wholesale : price,
    image:              imageUrl,
    imageUrl:           imageUrl,
    category:           '',
    weight:             unit,
    sku:                sku,
    discountPercentage: discountPercent.toDouble(),
    quantity:           qty,
    posQuantity:        qty,
    pieces:             pieces,
  );
}

// ─── Product card ─────────────────────────────────────────────────────────────
class _MtlProductCard extends StatelessWidget {
  final _SubProduct p;
  final double      imgH;
  const _MtlProductCard({required this.p, required this.imgH});

  @override
  Widget build(BuildContext context) {
    final product = p.toProduct();
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color:     Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset:     const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.max,
        children: [
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product)),
            ),
            child: Stack(children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F8F8),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SizedBox(
                    height: imgH,
                    width:  double.infinity,
                    child: p.imageUrl.isNotEmpty
                        ? Image.network(
                      p.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : Container(
                          color: const Color(0xFFF8F8F8)),
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                        : _placeholder(),
                  ),
                ),
              ),
              if (!p.isInStock)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: Container(
                      color:     Colors.white.withOpacity(0.75),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color:        Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.red.shade200)),
                        child: const Text('Not Available',
                            style: TextStyle(
                                color:      Colors.red,
                                fontSize:   9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                if (p.unit.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color:        const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(p.unit,
                        style: const TextStyle(
                            fontSize:   9,
                            color:      Color(0xFF555555),
                            fontWeight: FontWeight.w500)),
                  ),
                const SizedBox(height: 2),
                Text(p.name,
                    style: const TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                        color:      _kTextPrimary,
                        height:     1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('₹${p.price.toInt()}',
                        style: const TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w800,
                            color:      _kTextPrimary)),
                    if (p.wholesale > p.price) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('₹${p.wholesale.toInt()}',
                            style: const TextStyle(
                                fontSize:   10,
                                color:      Color(0xFF999999),
                                decoration:
                                TextDecoration.lineThrough,
                                decorationColor: Color(0xFF999999)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: _CartBtn(
                product:   product,
                isInStock: p.qty > 0,
                pieces:    p.pieces),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFF8F8F8),
    child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.grey.shade300, size: 28)),
  );
}

// ─── Cart button ──────────────────────────────────────────────────────────────
class _CartBtn extends StatefulWidget {
  final Product            product;
  final bool               isInStock;
  final List<ProductPiece> pieces;
  const _CartBtn({
    required this.product,
    required this.isInStock,
    this.pieces = const [],
  });

  @override
  State<_CartBtn> createState() => _CartBtnState();
}

class _CartBtnState extends State<_CartBtn> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  late final FocusNode             _focus;

  @override
  void initState() {
    super.initState();
    _ctrl  = TextEditingController();
    _focus = FocusNode();
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  void _startEditing(int currentQty) {
    _ctrl.text = '$currentQty';
    _focus.requestFocus();
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.selection = TextSelection(
          baseOffset: 0, extentOffset: _ctrl.text.length);
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
      _showStockDialog(stock);
    } else {
      cart.setQuantity(widget.product, val);
    }
    setState(() => _editing = false);
  }

  void _showStockDialog(int stock) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => Center(
        child: Container(
          margin:  const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color:     Colors.black.withOpacity(0.15),
                  blurRadius: 20)
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline, color: _kGreen, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Stock Limit Reached',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 10),
                decoration: BoxDecoration(
                    color:        _kGreen,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('OK',
                    style: TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isInStock) {
      return Container(
        width:     double.infinity,
        height:    34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color:        Colors.grey.shade100,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.grey.shade200)),
        child: const Text('Not Available',
            style: TextStyle(
                fontSize:   10,
                color:      Colors.red,
                fontWeight: FontWeight.bold)),
      );
    }

    if (widget.pieces.isNotEmpty) {
      return Consumer<CartModel>(
        builder: (_, cart, __) {
          int totalQty = 0;
          for (final piece in widget.pieces) {
            final pid =
                '${widget.product.id}_piece_${piece.pieceId}';
            final tmp = Product(
                id:          pid,
                name:        '',
                price:       0,
                originalPrice: 0,
                category:    '',
                quantity:    0,
                posQuantity: 0);
            totalQty += cart.getQuantity(tmp);
          }
          final hasItems = totalQty > 0;
          return GestureDetector(
            onTap: () => handleAddToCart(
                context: context,
                product: widget.product,
                pieces:  widget.pieces),
            child: Container(
              width:     double.infinity,
              height:    34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        hasItems ? _kGreen : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _kGreen, width: 1.5),
              ),
              child: Text(
                hasItems ? 'ADDED' : 'ADD',
                style: TextStyle(
                    color:      hasItems ? Colors.white : _kGreen,
                    fontSize:   11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          );
        },
      );
    }

    return Consumer<CartModel>(
      builder: (_, cart, __) {
        final qty = cart.getPieceQuantity(widget.product.id);
        if (qty == 0) {
          return GestureDetector(
            onTap: () => cart.addItem(widget.product),
            child: Container(
              width:     double.infinity,
              height:    34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _kGreen, width: 1.5),
              ),
              child: const Text('ADD',
                  style: TextStyle(
                      color:      _kGreen,
                      fontSize:   13,
                      fontWeight: FontWeight.w800)),
            ),
          );
        }
        return Container(
          height: 34,
          decoration: BoxDecoration(
              color:        _kGreen,
              borderRadius: BorderRadius.circular(7)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () =>
                    cart.decrementQuantity(widget.product.id),
                child: const SizedBox(
                    width:  34,
                    height: 34,
                    child: Icon(Icons.remove,
                        color: Colors.white, size: 16)),
              ),
              if (_editing)
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller:   _ctrl,
                    focusNode:    _focus,
                    keyboardType: TextInputType.number,
                    textAlign:    TextAlign.center,
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   13,
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
                          fontSize:   13,
                          fontWeight: FontWeight.bold)),
                ),
              GestureDetector(
                onTap: () {
                  final stock = widget.product.quantity > 0
                      ? widget.product.quantity
                      : widget.product.posQuantity;
                  if (stock > 0 && qty >= stock) {
                    _showStockDialog(stock);
                    return;
                  }
                  cart.addItem(widget.product);
                },
                child: const SizedBox(
                    width:  34,
                    height: 34,
                    child: Icon(Icons.add,
                        color: Colors.white, size: 16)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Category full page ───────────────────────────────────────────────────────
class _CategoryFullPage extends StatefulWidget {
  final String            parentName;
  final String            parentImage;
  final List<_ChildSub>   allSubs;
  final String            initialSubId;
  final List<_SubProduct> directProducts;

  const _CategoryFullPage({
    required this.parentName,
    required this.parentImage,
    required this.allSubs,
    required this.initialSubId,
    this.directProducts = const [],
  });

  @override
  State<_CategoryFullPage> createState() => _CategoryFullPageState();
}

class _CategoryFullPageState extends State<_CategoryFullPage> {
  late String            _selectedSubId;
  static const int       _pageSize = 40;
  int                    _visible  = _pageSize;
  final ScrollController _rightScroll = ScrollController();
  late List<_ChildSub>   _allSubs;
  late List<_SubProduct> _directProducts;

  @override
  void initState() {
    super.initState();
    _allSubs        = widget.allSubs;
    _directProducts = widget.directProducts;
    if (widget.initialSubId.isNotEmpty) {
      _selectedSubId = widget.initialSubId;
    } else if (widget.allSubs.isNotEmpty) {
      _selectedSubId = widget.allSubs.first.categoryId;
    } else {
      _selectedSubId = '__direct__';
    }
    _rightScroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_rightScroll.position.pixels >=
        _rightScroll.position.maxScrollExtent - 300 &&
        _visible < _currentProducts.length) {
      setState(() => _visible =
          (_visible + _pageSize).clamp(0, _currentProducts.length));
    }
  }

  @override
  void dispose() { _rightScroll.dispose(); super.dispose(); }

  List<_SubProduct> get _currentProducts {
    if (_selectedSubId == '__direct__') return _directProducts;
    final sub =
    _allSubs.where((s) => s.categoryId == _selectedSubId).toList();
    return sub.isNotEmpty ? sub.first.products : [];
  }

  String get _currentSubName {
    if (_selectedSubId == '__direct__') return widget.parentName;
    final sub =
    _allSubs.where((s) => s.categoryId == _selectedSubId).toList();
    return sub.isNotEmpty ? sub.first.name : '';
  }

  Future<void> _onRefresh() async {
    try {
      final token   = await SessionManager.getToken();
      final fetchId = _selectedSubId == '__direct__'
          ? (_allSubs.isNotEmpty ? _allSubs.first.categoryId : '')
          : _selectedSubId;
      if (fetchId.isEmpty) return;
      final result = await getCategoryData(
          token: token, categoryId: fetchId);
      if (!mounted) return;
      if (result['success'] == true) {
        final raw      = result['data'] as Map<String, dynamic>? ?? {};
        final rawProds = raw['products'] as List? ?? [];
        final freshProds = <_SubProduct>[];
        for (final p in rawProds) {
          final prod =
          _SubProduct.fromJson(p as Map<String, dynamic>);
          if (prod != null) freshProds.add(prod);
        }
        final idx =
        _allSubs.indexWhere((s) => s.categoryId == fetchId);
        if (idx >= 0) {
          final updated = _ChildSub(
            categoryId: _allSubs[idx].categoryId,
            name:       _allSubs[idx].name,
            image:      _allSubs[idx].image,
            products:   freshProds,
          );
          final newSubs = List<_ChildSub>.from(_allSubs);
          newSubs[idx] = updated;
          setState(() { _allSubs = newSubs; _visible = _pageSize; });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenW  = MediaQuery.of(context).size.width;
    const sidebarW = 88.0;
    const spacing  = 6.0;
    const int  cols = 2;
    final cardW = (screenW - sidebarW - 18 - (spacing * (cols - 1))) / cols;
    final imgH  = cardW * 0.80;

    final prods   = _currentProducts;
    final show    = prods.take(_visible).toList();
    final hasMore = _visible < prods.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: FloatingCartBar(),
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.parentName,
            style: const TextStyle(
                color:      _kTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize:   17)),
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh, color: _kGreen),
            onPressed: _onRefresh,
          ),
          Container(
            margin:  const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color:        _kLightGreen,
                borderRadius: BorderRadius.circular(12)),
            child: Text('${prods.length}',
                style: const TextStyle(
                    color:      _kGreen,
                    fontSize:   12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: sidebarW,
            color: Colors.white,
            child: ListView(children: [
              if (_directProducts.isNotEmpty)
                _SidebarItem(
                  label:      'All',
                  imageUrl:   widget.parentImage,
                  isSelected: _selectedSubId == '__direct__',
                  onTap: () => setState(() {
                    _selectedSubId = '__direct__';
                    _visible       = _pageSize;
                  }),
                ),
              ..._allSubs.map((sub) => _SidebarItem(
                label:      sub.name,
                imageUrl:   sub.imageUrl,
                isSelected: _selectedSubId == sub.categoryId,
                onTap: () => setState(() {
                  _selectedSubId = sub.categoryId;
                  _visible       = _pageSize;
                }),
              )),
            ]),
          ),
          Container(width: 1, color: const Color(0xFFEEEEEE)),
          Expanded(
            child: prods.isEmpty
                ? Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No products in $_currentSubName',
                          style: TextStyle(
                              color:    Colors.grey[500],
                              fontSize: 14)),
                    ]))
                : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: Colors.white,
                    padding:
                    const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(children: [
                      Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                              color: _kGreen,
                              borderRadius:
                              BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_currentSubName,
                              style: const TextStyle(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color:        _kLightGreen,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${prods.length}',
                            style: const TextStyle(
                                fontSize:   10,
                                color:      _kGreen,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color:     _kGreen,
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        controller: _rightScroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 80),
                        itemCount: (show.length / 2).ceil() + (hasMore ? 1 : 0),
                        itemBuilder: (_, rowIndex) {
                          if (rowIndex == (show.length / 2).ceil()) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: CircularProgressIndicator(color: _kGreen),
                              ),
                            );
                          }
                          final left  = rowIndex * 2;
                          final right = left + 1;
                          final cardH = imgH + 113.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width:  cardW,
                                  height: cardH,
                                  child: RepaintBoundary(
                                    child: ProductCard(
                                      product:     show[left].toProduct(),
                                      imageHeight: imgH,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (right < show.length)
                                  SizedBox(
                                    width:  cardW,
                                    height: cardH,
                                    child: RepaintBoundary(
                                      child: ProductCard(
                                        product:     show[right].toProduct(),
                                        imageHeight: imgH,
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(width: cardW, height: cardH),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ]),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar item ─────────────────────────────────────────────────────────────
class _SidebarItem extends StatelessWidget {
  final String       label;
  final String       imageUrl;
  final bool         isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.imageUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? _kLightGreen : Colors.white,
          border: Border(
            left: BorderSide(
                color: isSelected ? _kGreen : Colors.transparent,
                width: 3),
            bottom: const BorderSide(color: Color(0xFFF0F0F0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? _kGreen.withOpacity(0.08)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? _kGreen : const Color(0xFFE0E0E0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.grid_view_rounded,
                      color: isSelected
                          ? _kGreen
                          : Colors.grey.shade400,
                      size: 22))
                  : Icon(Icons.grid_view_rounded,
                  color: isSelected
                      ? _kGreen
                      : Colors.grey.shade400,
                  size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize:   11,
                height: 1.2,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:      isSelected ? _kGreen : _kTextPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines:  2,
              overflow:  TextOverflow.ellipsis,
              softWrap:  true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search ───────────────────────────────────────────────────────────────────
enum _SearchType { category, subcategory, product, offer }

class _SearchResult {
  final _SearchType  type;
  final String       id;
  final String       label;
  final String       subtitle;
  final String       imageUrl;
  final VoidCallback onTap;
  const _SearchResult({
    required this.type,
    required this.id,
    required this.label,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });
}

class _SearchPopup extends StatelessWidget {
  final LayerLink           link;
  final List<_SearchResult> results;
  final VoidCallback        onDismiss;

  const _SearchPopup({
    required this.link,
    required this.results,
    required this.onDismiss,
  });

  static const _typeColor = {
    _SearchType.category:    AppColors.primaryBlue,
    _SearchType.subcategory: AppColors.deepBlue,
    _SearchType.product:     AppColors.freshGreen,
    _SearchType.offer:       AppColors.primaryOrange,
  };
  static const _typeLabel = {
    _SearchType.category:    'Category',
    _SearchType.subcategory: 'Sub',
    _SearchType.product:     'Product',
    _SearchType.offer:       'Offer',
  };
  static const _typeIcon = {
    _SearchType.category:    Icons.grid_view_rounded,
    _SearchType.subcategory: Icons.subdirectory_arrow_right,
    _SearchType.product:     Icons.shopping_bag_outlined,
    _SearchType.offer:       Icons.local_offer,
  };

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap:    onDismiss,
          behavior: HitTestBehavior.translucent,
          child:    const SizedBox.expand(),
        ),
      ),
      CompositedTransformFollower(
        link:             link,
        showWhenUnlinked: false,
        offset:           const Offset(0, 58),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation:    10,
            borderRadius: BorderRadius.circular(14),
            color:        Colors.white,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.48,
                maxWidth:  MediaQuery.of(context).size.width - 32,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: results.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: Text('No results found',
                          style: TextStyle(
                              color:    Colors.grey[400],
                              fontSize: 14))),
                )
                    : ListView.separated(
                  padding:  EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount:  results.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[100]),
                  itemBuilder: (_, i) {
                    final r     = results[i];
                    final color = _typeColor[r.type]!;
                    return InkWell(
                      onTap: r.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(children: [
                          Container(
                            width:  40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: r.imageUrl.isNotEmpty
                                ? Image.network(r.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(_typeIcon[r.type],
                                        color:  color,
                                        size:   18))
                                : Icon(_typeIcon[r.type],
                                color: color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(r.label,
                                    style: const TextStyle(
                                        fontSize:   13,
                                        fontWeight:
                                        FontWeight.w600),
                                    maxLines:  1,
                                    overflow:
                                    TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(r.subtitle,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500]),
                                    maxLines:  1,
                                    overflow:
                                    TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius:
                              BorderRadius.circular(6),
                            ),
                            child: Text(_typeLabel[r.type]!,
                                style: TextStyle(
                                    fontSize:   9,
                                    color:      color,
                                    fontWeight:
                                    FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              size:  10,
                              color: Colors.grey[400]),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}