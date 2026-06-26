

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/config/app_color.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/home_banner_service.dart';
import '../services/session_manager.dart';

class HomeBannerSlider extends StatefulWidget {
  final void Function(BannerItem banner) onCategoryTap;

  const HomeBannerSlider({super.key, required this.onCategoryTap});

  @override
  State<HomeBannerSlider> createState() => _HomeBannerSliderState();
}

class _HomeBannerSliderState extends State<HomeBannerSlider>
    with AutomaticKeepAliveClientMixin {
  List<BannerItem> _banners     = [];
  bool             _loading     = true;
  int              _currentPage = 0;

  late final PageController _pageController;
  Timer?                    _autoScrollTimer;

  static const Duration _autoScrollInterval = Duration(seconds: 4);
  static const Duration _animDuration       = Duration(milliseconds: 500);

  // Adjust this ratio to control banner height:
  // wider number (e.g. 2.5) = shorter banner
  // smaller number (e.g. 1.8) = taller banner
  static const double _bannerAspectRatio = 2.2;

  @override
  bool get wantKeepAlive => true;

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

  // ── Banner tap → navigate to category in-app, or open external link ────
  // If the banner has a category_id, hand it off to the parent's
  // onCategoryTap callback (which fetches the category and opens the
  // full-category screen). Falls back to opening fullLink as a URL only
  // when there's no category_id at all.
  Future<void> _onBannerTap(BannerItem banner) async {
    if (banner.hasCategory) {
      widget.onCategoryTap(banner);
      return;
    }
    if (banner.fullLink.isEmpty) return;
    final uri = Uri.parse(banner.fullLink);
    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenW  = MediaQuery.of(context).size.width;
    final padH     = 12.0;
    final bannerW  = screenW - (padH * 2);
    final bannerH  = bannerW / _bannerAspectRatio;

    if (_loading) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: padH),
        height: bannerH,
        decoration: BoxDecoration(
          color:        Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.buttonPrimary),
        ),
      );
    }

    if (_banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── PageView with rounded corners ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: bannerH,
              child: PageView.builder(
                controller:    _pageController,
                itemCount:     _banners.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final b = _banners[i];
                  return Stack(fit: StackFit.expand, children: [

                    // ── Banner image — cover fills fully, no white gaps ────────
                    Positioned.fill(
                      child: b.imageUrl.isNotEmpty
                          ? Image.network(
                        b.imageUrl,
                        fit:       BoxFit.fill,
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryOrange),
                          ),
                        ),
                        errorBuilder: (_, __, ___) =>
                        const _BannerPlaceholder(),
                      )
                          : const _BannerPlaceholder(),
                    ),

                    // ── Tap layer ─────────────────────────────────────────────
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

          // ── Dot indicators (circular) ──────────────────────────────────────
          if (_banners.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width:  6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? AppColors.primaryOrange
                        : AppColors.primaryOrange.withOpacity(0.3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF3E0),
      child: const Center(
        child: Icon(Icons.image_not_supported,
            color: AppColors.primaryBlue, size: 40),
      ),
    );
  }
}