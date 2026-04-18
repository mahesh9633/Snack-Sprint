import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/home_banner_service.dart';
import '../services/session_manager.dart';

class HomeBannerSlider extends StatefulWidget {
  const HomeBannerSlider({super.key});

  @override
  State<HomeBannerSlider> createState() => _HomeBannerSliderState();
}

class _HomeBannerSliderState extends State<HomeBannerSlider> {
  List<BannerItem> _banners     = [];
  bool             _loading     = true;
  int              _currentPage = 0;

  late final PageController _pageController;
  Timer?                    _autoScrollTimer;

  static const Duration _autoScrollInterval = Duration(seconds: 4);
  static const Duration _animDuration       = Duration(milliseconds: 500);
  static const double   _bannerAspectRatio  = 1200 / 420;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    final token   = await SessionManager.getToken();
    final banners = await getBanners(token: token);
    if (!mounted) return;
    setState(() {
      _banners = banners;
      _loading = false;
    });
    if (_banners.length > 1) _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted || _banners.isEmpty) return;
      final next = (_currentPage + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: _animDuration,
        curve:    Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ── Banner tap → open link ─────────────────────────────────────────────────
  Future<void> _onBannerTap(BannerItem banner) async {
    if (banner.fullLink.isEmpty) return;
    final uri = Uri.parse(banner.fullLink);
    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
      );
      if (!launched) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      if (!launched) {
      }
    } catch (e) {
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── Loading state ────────────────────────────────────────────────────────
    if (_loading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: (MediaQuery.of(context).size.width - 32) / _bannerAspectRatio,
        decoration: BoxDecoration(
          color:        Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFB85C00)),
        ),
      );
    }

    // ── Empty — fall back to static banner ───────────────────────────────────
    if (_banners.isEmpty) return const _StaticMtlBanner();

    final bannerH =
        (MediaQuery.of(context).size.width - 32) / _bannerAspectRatio;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        // ── PageView ──────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 160,
            child: PageView.builder(
              controller:    _pageController,
              itemCount:     _banners.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) {
                final b = _banners[i];
                return Stack(fit: StackFit.expand, children: [

                  // ── Banner image ───────────────────────────────────────────
                  Positioned.fill(
                    child: b.imageUrl.isNotEmpty
                        ? Image.network(
                      b.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFB85C00)),
                        ),
                      ),
                      errorBuilder: (_, __, ___) =>
                      const _BannerPlaceholder(),
                    )
                        : const _BannerPlaceholder(),
                  ),

                  // ── Name at TOP ────────────────────────────────────────────
                  if (b.name.isNotEmpty)
                    Positioned(
                      left: 0, right: 0, top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin:  Alignment.topCenter,
                            end:    Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: Text(
                          b.name,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 6),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // ── Title at BOTTOM ────────────────────────────────────────
                  if (b.title.isNotEmpty)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin:  Alignment.bottomCenter,
                            end:    Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: Text(
                          b.title,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   14,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 6),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // ── Full-banner tap layer ──────────────────────────────────
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        splashColor: Colors.white.withOpacity(0.1),
                        onTap: () => _onBannerTap(b),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),

        // ── Dot indicators ────────────────────────────────────────────────────
        if (_banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width:  active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFB85C00)
                      : const Color(0xFFB85C00).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ]),
    );
  }
}

// ─── Fallback: shown when no banners returned from API ────────────────────────
class _StaticMtlBanner extends StatelessWidget {
  const _StaticMtlBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF7B3F00),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CELEBRATE',
              style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE8C49A),
                  fontWeight: FontWeight.w500)),
          Text('MTL DAY',
              style: TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFB85C00),
              borderRadius: BorderRadius.circular(20)),
          child: const Row(children: [
            Icon(Icons.favorite, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('MTL\nZone',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

// ─── Placeholder shown when image fails to load ───────────────────────────────
class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF3E0),
      child: const Center(
        child: Icon(Icons.image_not_supported,
            color: Color(0xFFB85C00), size: 40),
      ),
    );
  }
}