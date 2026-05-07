import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/see_all.dart';
import '../model/product_model.dart';
import '../products/product_card.dart';
import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../services/session_manager.dart';

class OffZoneTabBody extends StatefulWidget {
  const OffZoneTabBody({super.key});

  @override
  State<OffZoneTabBody> createState() => _OffZoneTabBodyState();
}

class _OffZoneTabBodyState extends State<OffZoneTabBody> {
  bool          _loading    = false;
  List<Product> _products   = [];
  String        _searchText = '';
  String?       _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<String, String> _catNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _buildImageUrl(String img, String base) {
    if (img.isEmpty || img == 'no_image.png') return '';
    if (img.startsWith('http://') || img.startsWith('https://')) return img;
    final clean = img.startsWith('/') ? img.substring(1) : img;
    return '$base$clean';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await SessionManager.getToken();

      final results = await Future.wait([
        getInitialData(customerId: null, token: token),
        ApiService.getCategoryData(token: token),
      ]);

      if (!mounted) return;

      final productResult  = results[0] as Map<String, dynamic>;
      final categoryResult = results[1] as Map<String, dynamic>;

      final String base = ApiConfig.imageBase;
      final List<Product> all = [];

      // ── Deduplication sets ──────────────────────────────────────────────
      final Set<String> addedIds   = {};
      final Set<String> addedNames = {};

      // ── SOURCE 1: random_products from getInitialData ───────────────────
      if (productResult['success'] == true) {
        final raw   = productResult['data'] as Map<String, dynamic>?
            ?? productResult as Map<String, dynamic>;
        final prods = raw['random_products'] as List? ?? [];

        for (final p in prods) {
          final mrp     = double.tryParse(p['price']?.toString()           ?? '0') ?? 0;
          final selling = double.tryParse(p['wholesale_price']?.toString() ?? '0') ?? 0;
          final special = double.tryParse(p['special_price']?.toString()   ?? '0') ?? 0;
          final img     = p['image']?.toString() ?? '';
          final url     = _buildImageUrl(img, base);

          // ── Parse quantity correctly ──────────────────────────────────
          final stockStatus = p['stock_status']?.toString().toLowerCase() ?? '';
          final subtract    = p['subtract']?.toString() ?? '';
          final rawQty      = p['pos_quentity']?.toString()
              ?? p['quantity']?.toString()
              ?? '';
          int qty;
          if (stockStatus == 'out of stock' || stockStatus == '0' || stockStatus == 'outofstock') {
            qty = 0;
          } else if (stockStatus.contains('in stock') || stockStatus == '1' || stockStatus == '2') {
            qty = int.tryParse(rawQty) ?? 1;
            if (qty == 0) qty = 1;
          } else if (subtract == '0') {
            qty = 1;
          } else if (rawQty.isEmpty || rawQty == 'null') {
            qty = 1;
          } else {
            qty = int.tryParse(rawQty) ?? 1;
            if (qty == 0 && stockStatus.isEmpty && subtract.isEmpty) qty = 1;
          }

          double disc = 0;
          if (special > 0 && special < mrp) {
            disc = ((mrp - special) / mrp * 100).clamp(0.0, 100.0);
          } else if (mrp > selling && selling > 0) {
            disc = ((mrp - selling) / mrp * 100).clamp(0.0, 100.0);
          } else if (selling > mrp && mrp > 0) {
            disc = ((selling - mrp) / selling * 100).clamp(0.0, 100.0);
          }

          // Only show products with 50% or more discount
          if (disc < 50) continue;

          final pid   = p['product_id']?.toString() ?? '';
          final pname = p['name']?.toString() ?? '';

          // ── Dedup check ───────────────────────────────────────────────
          if (pid.isNotEmpty && addedIds.contains(pid)) continue;
          if (pid.isEmpty && pname.isNotEmpty && addedNames.contains(pname)) continue;

          all.add(Product(
            id:                 pid,
            name:               pname,
            price:              special > 0 ? special : (selling > 0 ? selling : mrp),
            originalPrice:      mrp,
            image:              url,
            imageUrl:           url,
            category:           p['category_id']?.toString() ?? '',
            weight:             p['sku']?.toString()          ?? '',
            discountPercentage: disc,
            quantity:           qty,
          ));

          if (pid.isNotEmpty) addedIds.add(pid);
          if (pname.isNotEmpty) addedNames.add(pname);
        }
      }

      // ── SOURCE 2: products inside subcategories from getCategoryData ────
      if (categoryResult['success'] == true) {
        final rawSubs = categoryResult['subcategories'] as List? ?? [];

        for (final s in rawSubs) {
          final sub     = s as Map<String, dynamic>;
          final catId   = sub['category_id']?.toString() ?? '';
          final catName = sub['name']?.toString()        ?? '';

          if (catId.isNotEmpty && catName.isNotEmpty) {
            _catNames[catId] = catName;
          }

          final subProds = sub['products'] as List? ?? [];
          for (final p in subProds) {
            final mrp     = double.tryParse(p['price']?.toString()         ?? '0') ?? 0;
            final special = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0;
            final img     = p['image']?.toString() ?? '';
            final url     = _buildImageUrl(img, base);
            final pCatId  = p['category_id']?.toString() ?? catId;
            final qty     = int.tryParse(p['pos_quentity']?.toString() ?? '0') ?? 0;

            double disc = 0;
            if (special > 0 && special < mrp) {
              disc = ((mrp - special) / mrp * 100).clamp(0.0, 100.0);
            }

            // Only show products with 50% or more discount
            if (disc < 50) continue;

            final pid   = p['product_id']?.toString() ?? '';
            final pname = p['name']?.toString() ?? '';

            // ── Dedup check (by ID or by name as fallback) ────────────
            if (pid.isNotEmpty && addedIds.contains(pid)) continue;
            if (pname.isNotEmpty && addedNames.contains(pname)) continue;

            all.add(Product(
              id:                 pid,
              name:               pname,
              price:              special > 0 ? special : mrp,
              originalPrice:      mrp,
              image:              url,
              imageUrl:           url,
              category:           pCatId,
              weight:             p['piece']?.toString() ?? '',
              discountPercentage: disc,
              quantity:           qty,
            ));

            if (pid.isNotEmpty) addedIds.add(pid);
            if (pname.isNotEmpty) addedNames.add(pname);
          }
        }
      }

      all.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
      setState(() { _products = all; _loading = false; });

    } catch (e, st) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getCategoryName(String catId) {
    if (catId.isEmpty) return 'Other';
    return _catNames[catId] ?? 'Category $catId';
  }

  List<String> get _allCategoryIds {
    final seen = <String>{};
    final cats = <String>[];
    for (final p in _products) {
      if (p.category.isNotEmpty && seen.add(p.category)) cats.add(p.category);
    }
    return cats;
  }

  List<Product> get _displayed {
    var list = _products;
    if (_selectedCategory != null) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchText.isNotEmpty) {
      final q = _searchText.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _groupedProducts {
    final displayed = _displayed;
    final Map<String, List<Product>> grouped = {};
    for (final p in displayed) {
      final key = p.category.isNotEmpty ? p.category : 'other';
      grouped.putIfAbsent(key, () => []).add(p);
    }
    return grouped.entries.map((e) => {
      'categoryId':   e.key,
      'categoryName': _getCategoryName(e.key),
      'products':     e.value,
      'maxDiscount':  e.value
          .map((p) => p.discountPercentage)
          .reduce((a, b) => a > b ? a : b),
    }).toList()
      ..sort((a, b) =>
          (b['maxDiscount'] as double).compareTo(a['maxDiscount'] as double));
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupedProducts;
    final cats   = _allCategoryIds;

    final List<Widget> children = [
      _buildBanner(_products.length),
      _buildSearchBar(),
    ];

    if (_loading) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1))),
        ),
      );
    } else {
      if (cats.isNotEmpty) {
        children.add(_buildCategoryHeader());
        children.add(_buildCategoryChips(cats));
        children.add(const SizedBox(height: 8));
      }

      children.add(_buildAllDealsHeader(context, _displayed));

      if (_displayed.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_offer_outlined,
                    size: 56, color: Colors.pink),
                const SizedBox(height: 12),
                Text(
                  _searchText.isNotEmpty || _selectedCategory != null
                      ? 'No products match your filter.'
                      : 'No 50%+ offers right now.\nCheck back soon!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                if (_selectedCategory != null || _searchText.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedCategory = null;
                      _searchText = '';
                      _searchCtrl.clear();
                    }),
                    child: const Text('Clear filters',
                        style: TextStyle(color: Color(0xFF6366F1))),
                  ),
              ]),
            ),
          ),
        );
      } else {
        for (final group in groups) {
          final catName  = group['categoryName'] as String;
          final catId    = group['categoryId']   as String;
          final products = group['products']     as List<Product>;

          children.add(
              _buildCategorySectionHeader(catName, catId, products.length));
          children.add(
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   2,
                childAspectRatio: 0.65,
                crossAxisSpacing: 12,
                mainAxisSpacing:  12,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => _ProductCardWithBadge(
                product:      products[i],
                categoryName: catName,
              ),
            ),
          );
        }
      }

      children.add(const SizedBox(height: 100));
    }

    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }

  Widget _buildBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFFFF0080)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(children: [
        Positioned(
          right: -20, top: -20,
          child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('LIMITED TIME',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
            const SizedBox(height: 8),
            const Text('50% OFF',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1)),
            const Text('ZONE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    height: 1)),
            const SizedBox(height: 8),
            Text('Half the price, double the joy!',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$count Products',
                  style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
          ],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: Color(0xFFFF0080), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchText = v),
              decoration: InputDecoration(
                hintText: 'Search in 50% OFF Zone…',
                hintStyle: TextStyle(color: Colors.black87, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchText.isNotEmpty)
            GestureDetector(
              onTap: () =>
                  setState(() { _searchText = ''; _searchCtrl.clear(); }),
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.close, size: 18, color: Colors.pink),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildCategoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Shop by Category',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (_selectedCategory != null)
          GestureDetector(
            onTap: () => setState(() => _selectedCategory = null),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Clear',
                  style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }

  Widget _buildCategoryChips(List<String> cats) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final catId      = cats[i];
          final catName    = _getCategoryName(catId);
          final isSelected = _selectedCategory == catId;
          final catCount   =
              _products.where((p) => p.category == catId).length;

          return GestureDetector(
            onTap: () => setState(() =>
            _selectedCategory = isSelected ? null : catId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF6366F1).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF6366F1).withValues(alpha: 0.25),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(catName,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF6366F1))),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$catCount',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF6366F1))),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllDealsHeader(BuildContext context, List<Product> displayed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('All Deals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.pink,)),
          Text('${displayed.length} items with 50%+ off',
              style: TextStyle(fontSize: 11, color: Colors.black87)),
        ]),
        TextButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SeeAllScreen(
                      title: '50% OFF Zone', products: displayed))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('See all',
                style: TextStyle(color: Colors.pink, fontSize: 16)),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: Colors.pink),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCategorySectionHeader(
      String catName, String catId, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(catName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count items',
              style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _ProductCardWithBadge extends StatelessWidget {
  final Product product;
  final String  categoryName;

  const _ProductCardWithBadge({
    required this.product,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProductCard(product: product),
        if (categoryName.isNotEmpty)
          Positioned(
            top: 6, right: 6,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(maxWidth: 90),
              child: Text(
                categoryName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}