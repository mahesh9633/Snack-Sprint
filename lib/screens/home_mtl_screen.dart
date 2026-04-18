import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/cart_model.dart';
import '../model/initial_model.dart';
import '../model/product_model.dart';
import '../products/product_card.dart';
import '../products/product_detail_screen.dart';
import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../services/banner_service.dart';
import '../services/session_manager.dart';
import '../widgets/floating_cart.dart';
import 'offer_products_screen.dart';
import '../widgets/home_banner_slider.dart';
// ─── constants ───────────────────────────────────────────────────────────────
final String _kImgBase = ApiConfig.imageBase;
const int    _kPreviewMax = 4;

const Duration _kAutoRefreshInterval = Duration(seconds: 30);

class MtlTabBody extends StatefulWidget {
  final TextEditingController? externalSearchController;
  final FocusNode?             searchFocusNode;
  final LayerLink?             searchLayerLink;
  const MtlTabBody({super.key, this.externalSearchController, this.searchFocusNode, this.searchLayerLink});

  @override
  State<MtlTabBody> createState() => _MtlTabBodyState();
}

class _MtlTabBodyState extends State<MtlTabBody> {
  bool              _loading = true;
  String?           _error;
  InitialDataModel? _data;

  // ── Auto-refresh state ─────────────────────────────────────────────────────
  Timer?            _autoRefreshTimer;
  bool              _newDataAvailable = false;
  InitialDataModel? _pendingData;       // freshly fetched but not yet shown
  bool              _isRefreshing      = false;

  String _selectedCatId = '';
  String _selectedSubId = '';

  // ── Running banners ────────────────────────────────────────────────────────
  List<ApiBanner> _runningBanners = [];
  bool            _bannersLoaded  = false;

  final Map<String, _CatDetail> _catCache   = {};
  final Map<String, bool>       _catLoading = {};
  final Map<String, _CatDetail> _subCache   = {};
  final Map<String, bool>       _subLoading = {};
  // ── Search fields ──────────────────────────────────────────────────────────
  late final LayerLink            _searchLayerLink;
  OverlayEntry?              _searchOverlay;
  late TextEditingController _searchController;
  late FocusNode             _searchFocus;
  List<_SearchResult>        _searchResults  = [];
  bool                       _ownsController = false;

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

  // ── Auto-refresh ───────────────────────────────────────────────────────────
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_kAutoRefreshInterval, (_) {
      _checkForNewData();
    });
  }

  Future<void> _checkForNewData() async {
    if (!mounted || _isRefreshing) return;
    try {
      final token      = await SessionManager.getToken();
      final customerId = await SessionManager.getCustomerId();
      final result     = await getInitialData(customerId: customerId, token: token);
      if (!mounted) return;
      if (result['success'] == true) {
        final newModel = InitialDataModel.fromJson(result['data'] as Map<String, dynamic>);
        // Compare product count or offer count to detect changes
        final currentProductCount = _data?.randomProducts.length ?? 0;
        final newProductCount     = newModel.randomProducts.length;
        final currentOfferCount   = _data?.offers.length ?? 0;
        final newOfferCount       = newModel.offers.length;

        if (newProductCount != currentProductCount || newOfferCount != currentOfferCount) {
          if (mounted) {
            setState(() {
              _pendingData      = newModel;
              _newDataAvailable = true;
            });
          }
        }
      }
    } catch (_) {
    }
  }

  /// Applies the pending data and dismisses the banner.
  void _applyPendingData() {
    if (_pendingData == null) return;
    setState(() {
      _data             = _pendingData;
      _pendingData      = null;
      _newDataAvailable = false;
      // Clear caches so category detail is re-fetched with new products
      _catCache.clear();
      _subCache.clear();
      _catLoading.clear();
      _subLoading.clear();
    });
  }

  void _onExternalSearch() {
    final text = _searchController.text;
    setState(() {});
    if (text.trim().isEmpty) {
      _closeOverlay();
      return;
    }
    _runSearch(text);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _closeOverlay();
    _searchController.removeListener(_onExternalSearch);
    if (_ownsController) _searchController.dispose();
    if (widget.searchFocusNode == null) _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchRunningBanners() async {
    final token = await SessionManager.getToken();
    final banners = await getRunningBanners(token: token);
    if (mounted) {
      setState(() {
        _runningBanners = banners;
        _bannersLoaded  = true;
      });
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() { _loading = true; _error = null; });
    final token      = await SessionManager.getToken();
    final customerId = await SessionManager.getCustomerId();
    final result     = await getInitialData(customerId: customerId, token: token);

    if (!mounted) return;
    if (result['success'] == true) {
      final model = InitialDataModel.fromJson(result['data'] as Map<String, dynamic>);

      for (final cat in model.categories) {
        for (final sub in cat.subcategories) {
        }
      }

      for (final p in model.randomProducts) {
      }

      for (final offer in model.offers) {
        for (final p in offer.products) {
        }
      }

      setState(() {
        _data             = model;
        _loading          = false;
        _newDataAvailable = false;
        _pendingData      = null;
      });
      _fetchRunningBanners();
    } else {
      setState(() {
        _error   = result['message']?.toString() ?? 'Unknown error';
        _loading = false;
      });
    }
  }

  /// Pull-to-refresh handler — full reload.
  Future<void> _onRefresh() async {
    setState(() { _isRefreshing = true; });
    _catCache.clear();
    _subCache.clear();
    _catLoading.clear();
    _subLoading.clear();
    await _fetchInitialData();
    setState(() { _isRefreshing = false; });
  }

  /// Called externally via GlobalKey to force a fresh server fetch.
  Future<void> refresh() async {
    await _onRefresh();
  }

  // ── Category detail fetching (unchanged) ─────────────────────────────────
  Future<void> _fetchCatDetail(String catId) async {
    if (_catCache.containsKey(catId)) return;
    setState(() => _catLoading[catId] = true);
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
          _catCache[catId]   = _CatDetail(childSubs: childSubs, directProducts: directProds);
          _catLoading[catId] = false;
        });
      } else {
        setState(() {
          _catCache[catId]   = _CatDetail(childSubs: [], directProducts: []);
          _catLoading[catId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _catCache[catId]   = _CatDetail(childSubs: [], directProducts: []);
          _catLoading[catId] = false;
        });
      }
    }
  }

  Future<void> _fetchSubDetail(String subId) async {
    if (_subCache.containsKey(subId)) return;
    setState(() => _subLoading[subId] = true);
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
          _subCache[subId]   = _CatDetail(childSubs: childSubs, directProducts: directProds);
          _subLoading[subId] = false;
        });
      } else {
        setState(() {
          _subCache[subId]   = _CatDetail(childSubs: [], directProducts: []);
          _subLoading[subId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subCache[subId]   = _CatDetail(childSubs: [], directProducts: []);
          _subLoading[subId] = false;
        });
      }
    }
  }

  // ── Search logic (unchanged) ──────────────────────────────────────────────
  void _runSearch(String query) {
    setState(() {});
    if (query.trim().isEmpty) {
      _closeOverlay();
      return;
    }
    final q       = query.toLowerCase();
    final results = <_SearchResult>[];

    for (final cat in _data?.categories ?? []) {
      if (cat.name.toLowerCase().contains(q)) {
        results.add(_SearchResult(
          type:     _SearchType.category,
          label:    cat.name,
          subtitle: 'Category',
          imageUrl: cat.imageUrl,
          onTap: () {
            _closeOverlay();
            _searchController.clear();
            setState(() {
              _selectedCatId = cat.categoryId;
              _selectedSubId = '';
            });
            _fetchCatDetail(cat.categoryId);
          },
        ));
      }

      final catDetail = _catCache[cat.categoryId];
      if (catDetail != null) {
        for (final sub in catDetail.childSubs) {
          if (sub.name.toLowerCase().contains(q)) {
            results.add(_SearchResult(
              type:     _SearchType.subcategory,
              label:    sub.name,
              subtitle: 'in ${cat.name}',
              imageUrl: sub.imageUrl,
              onTap: () {
                _closeOverlay();
                _searchController.clear();
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
                label:    p.name,
                subtitle: '₹${p.price.toInt()} · ${sub.name}',
                imageUrl: p.imageUrl,
                onTap: () {
                  _closeOverlay();
                  _searchController.clear();
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
          label:    p.name,
          subtitle: '₹${p.retailPrice.toInt()} · Featured',
          imageUrl: p.imageUrl,
          onTap: () {
            _closeOverlay();
            _searchController.clear();
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
          label:    offer.name,
          subtitle: '${offer.products.length} products · Special Offer',
          imageUrl: '',
          onTap: () {
            _closeOverlay();
            _searchController.clear();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => OfferProductsScreen(
                offerName: offer.name,
                products:  offer.products,
              ),
            ));
          },
        ));
      }
      for (final p in offer.products) {
        if (p.name.toLowerCase().contains(q)) {
          results.add(_SearchResult(
            type:     _SearchType.product,
            label:    p.name,
            subtitle: '₹${p.retailPrice.toInt()} · ${offer.name}',
            imageUrl: p.imageUrl,
            onTap: () {
              _closeOverlay();
              _searchController.clear();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: _toProduct(p)),
              ));
            },
          ));
        }
      }
    }

    setState(() => _searchResults = results.take(30).toList());
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

  void _closeOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  LayerLink get searchLayerLink => _searchLayerLink;

  Product _toProduct(ApiProduct p) => Product(
    id:                 p.productId.isNotEmpty ? p.productId : (p.sku.isNotEmpty ? p.sku : p.name),
    name:               p.name,
    price: (p.specialPrice > 0 && p.specialPrice < p.retailPrice) ? p.specialPrice : p.retailPrice,
    originalPrice:      p.retailPrice,
    image:              p.image,
    imageUrl:           p.imageUrl,
    category:           p.category,
    weight:             p.unit,
    sku:                p.sku,
    discountPercentage: p.discountPercent,
    quantity:           p.quantity,
  );

  ApiCategory? get _selectedCategory {
    if (_selectedCatId.isEmpty || _data == null) return null;
    try {
      return _data!.categories.firstWhere((c) => c.categoryId == _selectedCatId);
    } catch (_) { return null; }
  }

  List<ApiProduct> get _visibleProducts => _data?.randomProducts ?? [];

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator(color: Color(0xFFB85C00))),
        ),
      );
    }
    if (_error != null) return SliverToBoxAdapter(child: _buildError());

    return SliverMainAxisGroup(
      slivers: [
        // ── Pinned category strip ──────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _CategoryStripDelegate(
            child: _buildCategoryStrip(),
            newDataBanner: _newDataAvailable
                ? _NewDataBanner(
              onTap: _applyPendingData,
              onDismiss: () => setState(() {
                _newDataAvailable = false;
                _pendingData      = null;
              }),
            )
                : null,
          ),
        ),

        // ── Scrollable content ─────────────────────────────────────────────
        SliverList(
          delegate: SliverChildListDelegate([
            _buildRefreshHint(),
            _buildDayBanner(),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            if (_selectedCatId.isNotEmpty) _buildCategoryDetailSection(),
            if (_selectedCatId.isNotEmpty) const SizedBox(height: 16),
            _buildFeaturedProducts(),
            const SizedBox(height: 4),
            _buildRunningBanners(),
            const SizedBox(height: 4),
            _buildOffersSection(),
            const SizedBox(height: 4),
          ]),
        ),
      ],
    );
  }

  // ── Pull-to-refresh hint (subtle, shown briefly) ──────────────────────────
  Widget _buildRefreshHint() {
    return const SizedBox.shrink();
  }

  // ── Category strip ─────────────────────────────────────────────────────────
  Widget _buildCategoryStrip() {
    final cats = _data?.categories ?? [];
    return
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryBox(
            label: 'All', imageUrl: null, emoji: '🛍️',
            isSelected: _selectedCatId.isEmpty,
            onTap: () => setState(() { _selectedCatId = ''; _selectedSubId = ''; }),
          ),
          ...cats.map((cat) => _buildCategoryBox(
            label:      cat.name,
            imageUrl:   cat.imageUrl.isNotEmpty ? cat.imageUrl : null,
            isSelected: _selectedCatId == cat.categoryId,

            onTap: () {
              setState(() {
                _selectedCatId = cat.categoryId;
                _selectedSubId = '';
                _fetchCatDetail(cat.categoryId);
              });
            },
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryBox({
    required String label, required bool isSelected, required VoidCallback onTap,
    String? imageUrl, String? emoji,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),

        child: Column(
            mainAxisSize: MainAxisSize.min,   // ADD THIS
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48, height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFB85C00)
                  : const Color(0xFFB85C00).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFB85C00)
                    : const Color(0xFFB85C00).withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(
                  color: const Color(0xFFB85C00).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3))]
                  : [],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? Image.network(imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _catFallback(isSelected, emoji))
                : _catFallback(isSelected, emoji),
          ),
          const SizedBox(height: 3),

          SizedBox(
            width: 60,
            child: Text(label,
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFFB85C00) : Colors.black87,
              ),
              textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _catFallback(bool sel, String? emoji) => Center(
    child: emoji != null
        ? Text(emoji, style: const TextStyle(fontSize: 22))
        : Icon(Icons.category,
        color: sel ? Colors.white : const Color(0xFFB85C00), size: 22),
  );

  Widget _buildCategoryDetailSection() {
    final cat       = _selectedCategory;
    final isLoading = _catLoading[_selectedCatId] ?? false;
    final detail    = _catCache[_selectedCatId];

    if (isLoading || (detail == null && cat != null)) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(false),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFB85C00))),
      );
    }
    if (detail == null) return const SizedBox.shrink();

    final hasChildSubs   = detail.childSubs.isNotEmpty;
    final hasDirectProds = detail.directProducts.isNotEmpty;

    if (!hasChildSubs && !hasDirectProds) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(false),
        child: Column(children: [
          Icon(Icons.inventory_2_outlined, size: 42, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text('No products available',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (hasChildSubs)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(false),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // NEW - just the spacing
            const SizedBox(height: 8),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),

              // NEW
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   4,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing:  8,
              ),
              itemCount: detail.childSubs.length,
              itemBuilder: (_, i) {
                final sub        = detail.childSubs[i];
                final isSelected = _selectedSubId == sub.categoryId;
                return GestureDetector(
                  onTap: () {
                    if (isSelected) {
                      setState(() => _selectedSubId = '');
                    } else {
                      setState(() => _selectedSubId = sub.categoryId);
                      _fetchSubDetail(sub.categoryId);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => _CategoryFullPage(
                          parentName:     sub.name,
                          allSubs:        [],
                          initialSubId:   '__direct__',
                          directProducts: sub.products,
                        ),
                      ));
                    }
                  },

                  // NEW - matches image 2 style with light blue background, name on top, image below
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F4FB), // light blue background like image 2
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF90CAF9)
                            : Colors.transparent,
                        width: isSelected ? 2 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset:     const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Text label on top ──────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE3F4FB),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(13)),
                          ),
                          child: Text(
                            sub.name,
                            style: const TextStyle(
                              fontSize:   10,
                              fontWeight: FontWeight.w700,
                              color:      Colors.black87,
                              height:     1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines:  2,
                            overflow:  TextOverflow.ellipsis,
                          ),
                        ),
                        // ── Image on bottom ────────────────────────────
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(13)),
                            child: sub.imageUrl.isNotEmpty
                                ? Image.network(
                              sub.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE3F4FB),
                                child: Icon(Icons.category,
                                    color: Colors.grey[400], size: 24),
                              ),
                            )
                                : Container(
                              color: const Color(0xFFE3F4FB),
                              child: Icon(Icons.category,
                                  color: Colors.grey[400],
                                  size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ]),
        ),

      if (_selectedSubId.isNotEmpty) ...[
        const SizedBox(height: 10),
        _buildChildSubProducts(detail),
      ],

      if (hasDirectProds) ...[
        const SizedBox(height: 10),
        _buildDirectProducts('', detail.directProducts),
      ],
    ]);
  }

  Widget _buildChildSubProducts(_CatDetail detail) {
    final subList =
    detail.childSubs.where((s) => s.categoryId == _selectedSubId).toList();
    if (subList.isEmpty) return const SizedBox.shrink();
    final s = subList.first;

    final isLoading = _subLoading[_selectedSubId] ?? false;
    final subDetail = _subCache[_selectedSubId];
    final products  = subDetail != null ? subDetail.directProducts : s.products;
    final bool showSeeMore = products.length > _kPreviewMax;

    final VoidCallback? onSeeMore = showSeeMore
        ? () => _goToFullCategoryPage(
      parentName:   _selectedCategory?.name ?? s.name,
      allSubs:      detail.childSubs,
      initialSubId: _selectedSubId,
    )
        : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: _cardDecoration(true),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Container(
              width: 4, height: 16,
              decoration: BoxDecoration(
                  color: const Color(0xFFB85C00),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),

        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: Color(0xFFB85C00))),
          )
        else if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Icon(Icons.inventory_2_outlined,
                    size: 36, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('No products in ${s.name}',
                    style:
                    TextStyle(color: Colors.grey[400], fontSize: 13)),
              ]),
            ),
          )
        else ...[
            _HorizontalProductRow(
              products: products,
              cap:      _kPreviewMax,
              onSeeMore: onSeeMore,
            ),
            const SizedBox(height: 10),
          ],
      ]),
    );
  }

  Widget _buildDirectProducts(String catName, List<_SubProduct> prods) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: _cardDecoration(false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        if (catName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(
                    color: const Color(0xFFB85C00),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(catName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        _HorizontalProductRow(products: prods, cap: null, onSeeMore: null),
        const SizedBox(height: 10),
      ]),
    );
  }

  void _goToFullCategoryPage({
    required String parentName,
    required List<_ChildSub> allSubs,
    required String initialSubId,
    List<_SubProduct> directProducts = const [],
  }) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CategoryFullPage(
        parentName:     parentName,
        allSubs:        allSubs,
        initialSubId:   initialSubId,
        directProducts: directProducts,
      ),
    ));
  }


  Widget _buildDayBanner() {
    return const HomeBannerSlider();
  }

  Widget _buildFeaturedProducts() {
    final products = _visibleProducts;
    if (products.isEmpty) return const SizedBox.shrink();

    const title = 'Featured Products';
    final screenW = MediaQuery.of(context).size.width;
    final cardW   = screenW * 0.42;
    final imgH    = cardW * 0.75;
    final cardH   = imgH + 126.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: [
          Icon(Icons.auto_awesome, color: Color(0xFFB85C00), size: 18),
          SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ),
      SizedBox(
        height: cardH,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: products.length,
          itemBuilder: (_, i) => SizedBox(
            width: cardW,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ProductCard(
                product: _toProduct(products[i]),
                imageHeight: imgH,
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildRunningBanners() {
    if (_runningBanners.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: [
          Icon(Icons.campaign, color: Color(0xFFB85C00), size: 18),
          SizedBox(width: 6),
          Text('Promotions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ),
      SizedBox(
        height: 160,
        child: PageView.builder(
          padEnds:    true,
          controller: PageController(viewportFraction: 0.95, initialPage: _runningBanners.length * 500),
          itemCount:  null,
          itemBuilder: (_, i) {
            final b = _runningBanners[i % _runningBanners.length];
            return GestureDetector(
              onTap: () {
                if (b.link.isNotEmpty) {
                  launchUrl(Uri.parse(b.link), mode: LaunchMode.externalApplication);
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: b.imageUrl.isNotEmpty
                      ? Image.network(b.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFFFFF3E0)))
                      : Container(color: const Color(0xFFFFF3E0)),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }
  Widget _buildOffersSection() {
    final offers = _data?.offers ?? [];
    if (offers.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.of(context).size.width;
    final cardW   = screenW * 0.42;
    final imgH    = cardW * 0.75;
    final cardH   = imgH + 126.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: [
          Icon(Icons.local_offer, color: Color(0xFFB85C00), size: 18),
          SizedBox(width: 6),
          Text(
            'Special Offers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ]),
      ),

      for (final offer in offers) ...[
        if (offer.products.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Trending in ',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: offer.name,
                      style: const TextStyle(
                        color: Color(0xFF7B1FA2),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(
            height: cardH,
            child: Builder(
              builder: (context) {
                final previewProducts = offer.products.take(4).toList();
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: previewProducts.length,

                  itemBuilder: (_, i) {
                    final bool isLast = i == previewProducts.length - 1 && offer.products.length > 4;
                    final product = _toProduct(previewProducts[i]);
                    return RepaintBoundary(
                        key: ValueKey('offer_${offer.categoryId}_${product.id}'),
                        child: SizedBox(
                          width: cardW,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: ProductCard(
                                    product: product,
                                    imageHeight: imgH,
                                  ),
                                ),
                            if (isLast)
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OfferProductsScreen(
                                        offerName: offer.name,
                                        products: offer.products,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFB85C00), width: 1),
                                  ),
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFB85C00),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 4),
                          ],
                          ),
                          ),
                        ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),
        ],
      ],
    ]);
  }

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(_error!,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _fetchInitialData,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB85C00)),
          child: const Text('Retry',
              style: TextStyle(color: Colors.white)),
        ),
      ]),
    ),
  );
}

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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end:   Offset.zero,
      ).animate(_slide),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B3F00), Color(0xFFB85C00)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB85C00).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.new_releases,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New products available!',
                          style: TextStyle(
                              color:      Colors.white,
                              fontSize:   13,
                              fontWeight: FontWeight.bold)),
                      Text('Tap to refresh the page',
                          style: TextStyle(
                              color:   Colors.white70,
                              fontSize: 11)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(Icons.close,
                      color: Colors.white70, size: 18),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

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

    final screenW   = MediaQuery.of(context).size.width;
    final cardW     = screenW * 0.42;
    final imgH      = cardW * 0.75;
    final cardH     = imgH + 126.0;
    const seeMoreH  = 36.0;
    final rowHeight = cardH + seeMoreH + 24.0;

    final shown     = cap != null ? products.take(cap!).toList() : products;
    final lastIndex = shown.length - 1;
    final hasSeeMore = onSeeMore != null;

    return SizedBox(
      height: rowHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0), // ← bottom:0 so button isn't clipped
        itemCount: shown.length,
        itemBuilder: (_, i) {
          final isLastCard = i == lastIndex && hasSeeMore;
          return SizedBox(
            width: cardW,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: isLastCard
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── product card ─────────────────────────────
                  SizedBox(
                    height: cardH,
                    width:  cardW,
                    child:  _MtlProductCard(p: shown[i], imgH: imgH),
                  ),
                  const SizedBox(height: 10),
                  // ── View All pill BELOW card ──────────────────
                  GestureDetector(
                    onTap: onSeeMore,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFB85C00), width: 1),
                      ),
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontSize:   10,
                          color:      Color(0xFFB85C00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  : Column(                         // ← non-last cards also use Column
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: cardH * 0.85,
                    width:  cardW,
                    child:  _MtlProductCard(p: shown[i], imgH: imgH),
                  ),
                  const SizedBox(height: seeMoreH), // ← empty space = same height as button
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    required this.categoryId, required this.name,
    required this.image,      required this.products,
  });
  String get imageUrl {
    if (image.isEmpty || image == 'no_image.png') return '';
    return image.startsWith('http') ? image : '$_kImgBase$image';
  }
}

class _SubProduct {
  final String productId;
  final String name;
  final String image;
  final double price;
  final double wholesale;
  final int    qty;
  final String sku;
  final String unit;

  const _SubProduct({
    required this.productId,
    required this.name,
    required this.image,
    required this.price,
    required this.wholesale,
    required this.qty,
    required this.sku,
    required this.unit,
  });

  static _SubProduct? fromJson(Map<String, dynamic> j) {
    try {
      final rawUnit = (j['piece']?.toString() ?? '').isNotEmpty
          ? j['piece'].toString()
          : (j['barcode_type']?.toString() ?? '');

      final double rawPrice     = double.tryParse(j['price']?.toString()         ?? '0') ?? 0;
      final double specialPrice = double.tryParse(j['special_price']?.toString() ?? '0') ?? 0;
      final bool   hasOffer     = specialPrice > 0 && specialPrice < rawPrice;

      final stockStatus = j['stock_status']?.toString().toLowerCase() ?? '';
      final subtract    = j['subtract']?.toString()    ?? '';
      final rawQtyStr   = j['pos_quentity']?.toString()
          ?? j['quantity']?.toString()
          ?? '';

      int qty;
      if (stockStatus.isNotEmpty &&
          (stockStatus == 'out of stock' || stockStatus == '0' || stockStatus == 'outofstock')) {
        qty = 0;
      } else if (stockStatus.isNotEmpty &&
          (stockStatus.contains('in stock') || stockStatus == '1' || stockStatus == '2')) {
        qty = 1;
      } else if (subtract == '0') {
        qty = 1;
      } else if (rawQtyStr.isEmpty || rawQtyStr == 'null') {
        qty = 1;
      } else {
        qty = int.tryParse(rawQtyStr) ?? 1;
        if (qty == 0 && stockStatus.isEmpty && subtract.isEmpty) qty = 1;
      }

      return _SubProduct(
        productId: j['product_id']?.toString() ?? '',
        name:      j['name']?.toString()       ?? '',
        image:     j['image']?.toString()      ?? '',
        price:     hasOffer ? specialPrice : rawPrice,
        wholesale: hasOffer ? rawPrice     : 0,
        qty:       qty,
        sku:       j['sku']?.toString() ?? '',
        unit:      rawUnit,
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
  );
}

BoxDecoration _cardDecoration(bool highlighted) => BoxDecoration(
  color:        Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: highlighted
      ? Border.all(
      color: const Color(0xFFB85C00).withOpacity(0.3), width: 1.5)
      : null,
  boxShadow: [
    BoxShadow(
      color: highlighted
          ? const Color(0xFFB85C00).withOpacity(0.08)
          : Colors.black.withOpacity(0.04),
      blurRadius: highlighted ? 10 : 6,
      offset: const Offset(0, 2),
    )
  ],
);

class _MtlProductCard extends StatelessWidget {
  final _SubProduct p;
  final double      imgH;
  const _MtlProductCard({required this.p, required this.imgH});

  @override
  Widget build(BuildContext context) {
    final product = p.toProduct();
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
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
          mainAxisSize: MainAxisSize.max,
          children: [
            Stack(children: [
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
                child: SizedBox(
                  height: imgH,
                  width:  double.infinity,
                  child:  p.imageUrl.isNotEmpty
                      ? Image.network(p.imageUrl, fit: BoxFit.cover,
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('↓${p.discountPercent}%',
                        style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   7,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              if (!p.isInStock)
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
                            color: Colors.red[700],
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
            ]),

            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  color: const Color(0xFF388E3C),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('₹${p.price.toInt()}',
                                  style: const TextStyle(
                                      color:      Colors.white,
                                      fontSize:   10,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (p.wholesale > p.price) ...[
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text('₹${p.wholesale.toInt()}',
                                    style: TextStyle(
                                        fontSize:   8,
                                        color:      Colors.grey[500],
                                        decoration: TextDecoration.lineThrough),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (p.unit.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(p.unit,
                              style: TextStyle(
                                  fontSize: 8, color: Colors.grey[500]),
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
                            fontSize:   8,
                            color:      Color(0xFF388E3C),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                  ],

                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w500,
                          color: Colors.black87, height: 1.3),
                      maxLines:  2,
                      overflow:  TextOverflow.ellipsis),
                ],
              ),
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: _CartBtn(product: product, isInStock: p.isInStock),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey[100],
    child: Center(
        child: Icon(Icons.image_not_supported,
            color: Colors.grey[300], size: 28)),
  );
}

class _CartBtn extends StatelessWidget {
  final Product product;
  final bool    isInStock;
  const _CartBtn({required this.product, required this.isInStock});

  @override
  Widget build(BuildContext context) {
    if (!isInStock) {
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
      builder: (_, cart, __) {
        final qty = cart.getQuantity(product);
        if (qty == 0) {
          return GestureDetector(
            onTap: () => cart.addItem(product),
            child: Container(
              width:     double.infinity,
              height:    30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: const Color(0xFFFF0080), width: 1.2),
              ),
              child: const Text('ADD',
                  style: TextStyle(
                      color:        Color(0xFFFF0080),
                      fontSize:     11,
                      fontWeight:   FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          );
        }
        return Container(
          height: 30,
          decoration: BoxDecoration(
              color:  Color(0xFFFF0080),
              borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => cart.decrementQuantity(product.id),
                child: const SizedBox(
                    width: 30, height: 30,
                    child: Icon(Icons.remove, color: Colors.white, size: 14)),
              ),
              Text('$qty',
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   12,
                      fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => cart.addItem(product),
                child: const SizedBox(
                    width: 30, height: 30,
                    child: Icon(Icons.add, color: Colors.white, size: 14)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryFullPage extends StatefulWidget {
  final String            parentName;
  final List<_ChildSub>   allSubs;
  final String            initialSubId;
  final List<_SubProduct> directProducts;

  const _CategoryFullPage({
    required this.parentName,
    required this.allSubs,
    required this.initialSubId,
    this.directProducts = const [],
  });

  @override
  State<_CategoryFullPage> createState() => _CategoryFullPageState();
}

class _CategoryFullPageState extends State<_CategoryFullPage> {
  late String _selectedSubId;
  static const int _pageSize = 40;
  int _visible = _pageSize;
  final ScrollController _rightScroll = ScrollController();

  // Local copies that can be updated on pull-to-refresh
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
      setState(() =>
      _visible = (_visible + _pageSize).clamp(0, _currentProducts.length));
    }
  }

  @override
  void dispose() {
    _rightScroll.dispose();
    super.dispose();
  }

  List<_SubProduct> get _currentProducts {
    if (_selectedSubId == '__direct__') return _directProducts;
    final sub = _allSubs.where((s) => s.categoryId == _selectedSubId).toList();
    return sub.isNotEmpty ? sub.first.products : [];
  }

  String get _currentSubName {
    if (_selectedSubId == '__direct__') return widget.parentName;
    final sub = _allSubs.where((s) => s.categoryId == _selectedSubId).toList();
    return sub.isNotEmpty ? sub.first.name : '';
  }

  Future<void> _onRefresh() async {
    try {
      final token  = await SessionManager.getToken();
      final fetchId = _selectedSubId == '__direct__'
          ? (_allSubs.isNotEmpty ? _allSubs.first.categoryId : '')
          : _selectedSubId;
      if (fetchId.isEmpty) return;

      final result = await getCategoryData(token: token, categoryId: fetchId);
      if (!mounted) return;
      if (result['success'] == true) {
        final raw      = result['data'] as Map<String, dynamic>? ?? {};
        final rawProds = raw['products'] as List? ?? [];
        final freshProds = <_SubProduct>[];
        for (final p in rawProds) {
          final prod = _SubProduct.fromJson(p as Map<String, dynamic>);
          if (prod != null) freshProds.add(prod);
        }
        // Update the sub's product list
        final idx = _allSubs.indexWhere((s) => s.categoryId == fetchId);
        if (idx >= 0) {
          final updated = _ChildSub(
            categoryId: _allSubs[idx].categoryId,
            name:       _allSubs[idx].name,
            image:      _allSubs[idx].image,
            products:   freshProds,
          );
          final newSubs = List<_ChildSub>.from(_allSubs);
          newSubs[idx] = updated;
          setState(() {
            _allSubs = newSubs;
            _visible = _pageSize;
          });
        }
      }
    } catch (_) { }
  }

  @override
  Widget build(BuildContext context) {
    final screenW  = MediaQuery.of(context).size.width;
    const sidebarW = 88.0;
    const spacing  = 10.0;
    // const cols     = 2;
    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final int  cols     = isTablet ? 3 : 2;
    final cardW    = (screenW - sidebarW - 16 - spacing) / cols;
    final imgH     = cardW * 0.75;
    final cardH    = imgH + 126.0;
    final ratio    = cardW / cardH;

    final prods   = _currentProducts;
    final show    = prods.take(_visible).toList();
    final hasMore = _visible < prods.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: FloatingCartBar(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:       0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.parentName,
            style: const TextStyle(
                color:      Colors.black,
                fontWeight: FontWeight.bold,
                fontSize:   18)),
        actions: [
          // Manual refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF0080)),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
          Container(
            margin:  const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFB85C00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text('${prods.length}',
                style: const TextStyle(
                    color:      Color(0xFFB85C00),
                    fontSize:   12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: sidebarW,
          color: Colors.white,
          child: ListView(children: [
            if (_directProducts.isNotEmpty)
              _SidebarItem(
                label:      'All',
                imageUrl:   '',
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
        Container(width: 5, color: Colors.white),

        Expanded(
          child: prods.isEmpty
              ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2_outlined,
                    size: 60, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No products in $_currentSubName',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 14)),
              ]))
              : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(children: [
                    Container(
                        width: 3, height: 14,
                        decoration: BoxDecoration(
                            color: const Color(0xFFB85C00),
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(_currentSubName,
                            style: const TextStyle(
                                fontSize:   13,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFB85C00).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${prods.length}',
                          style: const TextStyle(
                              fontSize:   10,
                              color:      Color(0xFFB85C00),
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFB85C00),
                    onRefresh: _onRefresh,
                    child: GridView.builder(
                      controller: _rightScroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                      gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:   cols,
                        childAspectRatio: ratio,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing:  spacing,
                      ),
                      itemCount: show.length + (hasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == show.length) {
                          return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: Color(0xFFB85C00)),
                              ));
                        }
                        return RepaintBoundary(
                            child: _MtlProductCard(
                                p: show[i], imgH: imgH));
                      },
                    ),
                  ),
                ),
              ]),
        ),
      ]),
    );
  }
}

// ─── Sidebar item (unchanged) ──────────────────────────────────────────────────
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
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8F0) : Colors.white,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? const Color(0xFFB85C00)
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFB85C00).withOpacity(0.12)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.category,
                    color: isSelected
                        ? const Color(0xFFB85C00)
                        : Colors.grey[400],
                    size: 22))
                : Icon(Icons.category,
                color: isSelected
                    ? const Color(0xFFB85C00)
                    : Colors.grey[400],
                size: 22),
          ),
          const SizedBox(height: 5),
          Text(label,
            style: TextStyle(
              fontSize:   10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFFB85C00) : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines:  2,
            overflow:  TextOverflow.ellipsis,
          ),
        ]),
      ),
    );
  }
}

// ─── Search result model & popup (unchanged) ──────────────────────────────────
enum _SearchType { category, subcategory, product, offer }

class _SearchResult {
  final _SearchType  type;
  final String       label;
  final String       subtitle;
  final String       imageUrl;
  final VoidCallback onTap;

  const _SearchResult({
    required this.type,
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
    _SearchType.category:    Color(0xFF7B1FA2),
    _SearchType.subcategory: Color(0xFF1565C0),
    _SearchType.product:     Color(0xFF2E7D32),
    _SearchType.offer:       Color(0xFFB85C00),
  };

  static const _typeLabel = {
    _SearchType.category:    'Category',
    _SearchType.subcategory: 'Sub',
    _SearchType.product:     'Product',
    _SearchType.offer:       'Offer',
  };

  static const _typeIcon = {
    _SearchType.category:    Icons.grid_view,
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
                            color: Colors.grey[400], fontSize: 14)),
                  ),
                )
                    : ListView.separated(
                  padding:     EdgeInsets.zero,
                  shrinkWrap:  true,
                  itemCount:   results.length,
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
                            width:  42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: r.imageUrl.isNotEmpty
                                ? Image.network(r.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    _typeIcon[r.type],
                                    color: color, size: 20))
                                : Icon(_typeIcon[r.type],
                                color: color, size: 20),
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
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                    maxLines:  1,
                                    overflow:  TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(r.subtitle,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500]),
                                    maxLines:  1,
                                    overflow:  TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(_typeLabel[r.type]!,
                                style: TextStyle(
                                    fontSize:   9,
                                    color:      color,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios,
                              size: 11, color: Colors.grey[400]),
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

class _CategoryStripDelegate extends SliverPersistentHeaderDelegate {
  final Widget  child;
  final Widget? newDataBanner;
  final bool    hasBanner;

  _CategoryStripDelegate({
    required this.child,
    this.newDataBanner,
  }) : hasBanner = newDataBanner != null;

  // ── Heights ───────────
  static const double _stripH  = 90.0;
  static const double _bannerH =  56.0;

  @override
  double get minExtent => _stripH + (hasBanner ? _bannerH : 0);

  @override
  double get maxExtent => minExtent;

  @override
  bool shouldRebuild(_CategoryStripDelegate old) =>
      old.hasBanner != hasBanner || old.child != child;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (newDataBanner != null) SizedBox(height: _bannerH, child: newDataBanner!),
          SizedBox(height: _stripH, child: child),
        ],
      ),
    );
  }
}