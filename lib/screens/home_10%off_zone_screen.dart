import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/see_all.dart';
import '../model/product_model.dart';
import '../products/product_card.dart';
import '../services/api_config_service.dart';
import '../services/api_server.dart';
import '../services/session_manager.dart';

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await SessionManager.getToken();

      // Step 1: get all categories
      final catResult = await getCategoryData(categoryId: null, token: token);
      if (!mounted) return;

      List<Map<String, dynamic>> allRawProducts = [];

      if (catResult['success'] == true) {
        final data = catResult['data'] as Map<String, dynamic>? ?? {};

        // collect parent products
        final parentProds = (data['products'] as List? ?? []);
        for (final p in parentProds) {
          allRawProducts.add(Map<String, dynamic>.from(p));
        }

        // collect subcategory products
        final subs = (data['subcategories'] as List? ?? []);
        for (final sub in subs) {
          final subProds = (sub['products'] as List? ?? []);
          for (final p in subProds) {
            allRawProducts.add(Map<String, dynamic>.from(p));
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

        return Product(
          id:                 p['product_id']?.toString() ?? '',
          name:               p['name']?.toString() ?? '',
          price:              actualPrice,
          originalPrice:      rp,
          image:              url,
          imageUrl:           url,
          category:           p['category_id']?.toString() ?? '',
          weight:             p['sku']?.toString() ?? '',
          discountPercentage: disc,
          quantity:           qty,
        );
      }).toList();

      if (!mounted) return;
      setState(() { _products = all; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12),
            itemCount: featured.length > 20 ? 20 : featured.length,
            itemBuilder: (_, i) => ProductCard(product: featured[i]),
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