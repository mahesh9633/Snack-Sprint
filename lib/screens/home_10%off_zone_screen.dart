

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/see_all.dart';
import '../model/product_model.dart';
import '../products/product_card.dart';
import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../services/session_manager.dart';
import '../widgets/piece_selector_sheet.dart';

// ── Resolve the correct piece/unit label for a raw product JSON map ────────
// Same helper as off_zone_tab_body.dart / home_mtl_screen.dart's
// _SubProduct.fromJson, so every screen shows the same unit text instead of
// falling back to SKU.
String _resolvePieceUnit(Map<String, dynamic> p) {
  final piecesList = (p['pieces'] as List? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .toList();

  Map<String, dynamic>? defaultPieceMap;
  for (final pc in piecesList) {
    if (pc['piece_default']?.toString() == '1') {
      defaultPieceMap = pc;
      break;
    }
  }
  if (defaultPieceMap == null && piecesList.isNotEmpty) {
    defaultPieceMap = piecesList.reduce((a, b) {
      final aP = double.tryParse(a['price']?.toString() ?? '0') ?? 0;
      final bP = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
      return aP >= bP ? a : b;
    });
  }

  final String rawUnit =
  defaultPieceMap?['piece']?.toString().isNotEmpty == true
      ? defaultPieceMap!['piece'].toString()
      : (p['piece']?.toString() ?? '').isNotEmpty
      ? p['piece'].toString()
      : (p['barcode_type']?.toString() ?? '');

  return rawUnit;
}

class SuperMallTabBody extends StatefulWidget {
  const SuperMallTabBody({super.key});

  @override
  State<SuperMallTabBody> createState() => _SuperMallTabBodyState();
}

class _SuperMallTabBodyState extends State<SuperMallTabBody> {
  bool          _loading  = false;
  List<Product> _products = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String        _searchText = '';

  // ── Category names, so cards can show the same badge as the 50% zone ────
  final Map<String, String> _catNames = {};

  // ── Silent background refresh, same pattern as the MTL home tab ──────────
  Timer? _autoRefreshTimer;
  static const Duration _kAutoRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(_kAutoRefreshInterval, (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── UPDATED: supports `silent` background refresh (no spinner flicker) ───
  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final token = await SessionManager.getToken();

      // Step 1: get all categories
      final catResult = await getCategoryData(categoryId: null, token: token);
      if (!mounted) return;

      List<Map<String, dynamic>> allRawProducts = [];
      // productId -> categoryId, so we can attach a category badge/filter
      final Map<String, String> productCatId = {};

      if (catResult['success'] == true) {
        final data = catResult['data'] as Map<String, dynamic>? ?? {};

        // collect parent products (no subcategory of their own)
        final parentProds = (data['products'] as List? ?? []);
        for (final p in parentProds) {
          final pm = Map<String, dynamic>.from(p);
          allRawProducts.add(pm);
        }

        // collect subcategory products + names
        final subs = (data['subcategories'] as List? ?? []);
        for (final sub in subs) {
          final subMap = sub as Map<String, dynamic>;
          final catId  = subMap['category_id']?.toString() ?? '';
          final catNm  = subMap['name']?.toString()        ?? '';
          if (catId.isNotEmpty && catNm.isNotEmpty) {
            _catNames[catId] = catNm;
          }

          final subProds = (subMap['products'] as List? ?? []);
          for (final p in subProds) {
            final pm = Map<String, dynamic>.from(p);
            final pid = pm['product_id']?.toString() ?? '';
            if (pid.isNotEmpty) productCatId[pid] = catId;
            allRawProducts.add(pm);
          }
        }
      }

      final String base = ApiConfig.imageBase;

      final all = allRawProducts.map<Product>((p) {
        final rp  = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
        final sp  = double.tryParse(p['special_price']?.toString() ?? '0') ?? 0;
        final img = p['image']?.toString() ?? '';
        final url = (img.isNotEmpty && img != 'no_image.png') ? '$base$img' : '';

        final actualPrice = (sp > 0 && sp < rp) ? sp : rp;
        final disc = (sp > 0 && sp < rp)
            ? ((rp - sp) / rp * 100).clamp(0, 100).toDouble()
            : 0.0;
        final qty = int.tryParse(p['pos_quentity']?.toString() ?? '0') ?? 0;

        final pid = p['product_id']?.toString() ?? '';
        final resolvedCatId = productCatId[pid] ?? p['category_id']?.toString() ?? '';

        return Product(
          id:                 pid,
          name:               p['name']?.toString() ?? '',
          price:              actualPrice,
          originalPrice:      rp,
          image:              url,
          imageUrl:           url,
          category:           resolvedCatId,
          // ✅ FIXED: use the resolved piece/unit label, not SKU
          weight:             _resolvePieceUnit(p),
          discountPercentage: disc,
          quantity:           qty,
          pieces: (p['pieces'] as List? ?? [])
              .map((e) => ProductPiece.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _products = all;
        if (!silent) _loading = false;
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  String _getCategoryName(String catId) {
    if (catId.isEmpty) return '';
    return _catNames[catId] ?? '';
  }

  List<Product> get _displayed {
    final discounted = _products.where((p) => p.discountPercentage >= 10 && p.discountPercentage <= 40).toList();
    if (_searchText.isEmpty) return discounted;
    final q = _searchText.toLowerCase();
    return discounted.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final featured = _displayed;
    return SliverList(
      delegate: SliverChildListDelegate([
        _buildBanner(),
        _buildSearchBar(),
        _buildPromoCard(),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
          )
        else ...[
          _buildAllProductsHeader(context, featured),
          // mainAxisExtent (not childAspectRatio) pins each cell to a fixed
          // pixel height matching the real ProductCard content height —
          // same fix as the 50% OFF Zone grid, so both screens look
          // identical with no leftover gap under the price/button.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   2,
                mainAxisExtent:   215,
                crossAxisSpacing: 12,
                mainAxisSpacing:  12),
            itemCount: featured.length > 20 ? 20 : featured.length,
            itemBuilder: (_, i) => _ProductCardWithBadge(
              product:      featured[i],
              categoryName: _getCategoryName(featured[i].category),
            ),
          ),
        ],
        const SizedBox(height: 100),
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
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: Color(0xFF1B5E20), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchText = v),
              decoration: InputDecoration(
                hintText: 'Search in 10% - 40% OFF ZONE…',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                border: InputBorder.none,
                isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchText.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() { _searchText = ''; _searchCtrl.clear(); }),
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(children: [
        Positioned(right: -15, top: -15,
            child: Container(width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07)))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(children: [
                Icon(Icons.local_offer, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('10% - 40% OFF ZONE', style: TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 10),
            const Text('10%-40%', style: TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, height: 1)),
            const Text('OFF ZONE', style: TextStyle(
                color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, height: 1)),
            const SizedBox(height: 8),
            Text('Products with 10% to 40% discount',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Grab the best deals!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('All products with 10% to 40% off',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(20)),
          child: const Text('Shop ▶',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildAllProductsHeader(BuildContext context, List<Product> featured) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('10% - 40% Off Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SeeAllScreen(title: '10% OFF ZONE', products: featured))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('See all', style: TextStyle(color: Colors.green[700], fontSize: 13)),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.green[700]),
          ]),
        ),
      ]),
    );
  }
}

// ── Same badge overlay pattern as the 50% OFF Zone screen, so cards match ──
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
        ProductCard(product: product, imageHeight: 100),
        if (categoryName.isNotEmpty)
          Positioned(
            top: 6, right: 6,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.90),
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
