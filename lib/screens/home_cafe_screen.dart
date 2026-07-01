import 'package:flutter/material.dart';

class CafeTabBody extends StatelessWidget {
  const CafeTabBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([

        _buildBanner(),
        _buildSearchBar(),
        _buildFilterChips(),

        // ── FASHION COMING SOON ─────────────────────────────────────────────
        const SizedBox(height: 60),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👗', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 20),
              const Text(
                'FASHION COMING SOON',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "We're styling something special for you.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ]),
    );
  }

  // ── Banner ───────────────────────────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF6366F1)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(children: [
        Positioned(
          right: -20, bottom: -20,
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.checkroom, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('STYLED FOR YOU',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 10),
              const Text('fashion',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      height: 1)),
              const SizedBox(height: 6),
              Text('Shop the latest trends',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14)),
              const SizedBox(height: 12),
              Row(children: [
                _fashionBadge('👗 Apparel'),
                const SizedBox(width: 8),
                _fashionBadge('👟 Footwear'),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _fashionBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600)),
  );

  // ── Search Bar ────────────────────────────────────────────────────────────
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
                color: Colors.black.withOpacity(0.06), blurRadius: 8)
          ],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search in fashion…',
                hintStyle:
                TextStyle(color: Colors.grey[400], fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Filter Chips ──────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = ['All', 'Men', 'Women', 'Kids', 'Footwear', 'Accessories'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(right: 8),
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: i == 0 ? const Color(0xFF6366F1) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: i == 0
                  ? const Color(0xFF6366F1)
                  : Colors.grey[300]!,
            ),
          ),
          child: Text(filters[i],
              style: TextStyle(
                  color: i == 0 ? Colors.white : Colors.grey[700],
                  fontSize: 13,
                  fontWeight: i == 0
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
      ),
    );
  }
}