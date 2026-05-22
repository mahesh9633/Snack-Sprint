import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtl_groceriesapp/screens/profile_screen.dart';
import 'package:mtl_groceriesapp/screens/quick_tab_enum.dart';
import 'package:mtl_groceriesapp/screens/select_location_screen.dart';
import '../model/cart_model.dart';
import '../services/api_config_service.dart';
import '../services/get_profile_service.dart';
import 'home_mtl_screen.dart';
import 'home_offzone_screen.dart';
import 'home_10%off_zone_screen.dart';
import 'home_cafe_screen.dart';
import 'cart_screen.dart';

class HomeTab extends StatefulWidget {
  final bool    isNewCustomer;
  final String? mobile;
  final String? authToken;

  const HomeTab({
    super.key,
    this.isNewCustomer = false,
    this.mobile,
    this.authToken,
  });

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  QuickTab _activeTab = QuickTab.mtl;

  String _addressLabel    = '';
  String _addressSubtitle = '';

  // ── Profile image ──────────────────────────────────────────────────────────
  String? _profileImagePath;
  String? _profileServerImageUrl;

  final TextEditingController _searchCtrl  = TextEditingController();
  final FocusNode             _searchFocus = FocusNode();

  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey<State<MtlTabBody>> _mtlKey = GlobalKey<State<MtlTabBody>>();

  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadProfileImage();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void resetToHome() {
    setState(() {
      _activeTab = QuickTab.mtl;
    });
    _searchCtrl.clear();
    _searchFocus.unfocus();
  }

  Future<void> _loadProfileImage() async {
    try {
      final result = await ProfileGetApiService.getProfile();
      if (result['success'] == true) {
        final data   = result['data'] as Map<String, dynamic>;
        final imgUrl = data['profile_image'] as String? ?? '';
        if (mounted) {
          setState(() {
            _profileServerImageUrl = imgUrl.isNotEmpty ? imgUrl : null;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final label    = prefs.getString('saved_address_label')    ?? '';
    final subtitle = prefs.getString('saved_address_subtitle') ?? '';
    if (label.isNotEmpty && mounted) {
      setState(() {
        _addressLabel    = label;
        _addressSubtitle = subtitle;
      });
    }
  }

  Future<void> _saveAddress(SelectedAddress address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_address_label',    address.label);
    await prefs.setString('saved_address_subtitle', address.subtitle);
  }

  // ── Pull-to-refresh handler ────────────────────────────────────────────────
  Future<void> _onRefresh() async {
    final state = _mtlKey.currentState;
    if (state != null) {
      await (state as dynamic).refresh();
    }
  }

  // ── Location ───────────────────────────────────────────────────────────────
  void _showLocationSheet() {
    _searchFocus.unfocus();
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectLocationSheet(
        onUseCurrentLocation: (SelectedAddress address) {
          setState(() {
            _addressLabel    = address.label;
            _addressSubtitle = address.subtitle;
          });
          _saveAddress(address);
          _searchFocus.unfocus();
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Location set: ${address.subtitle}'),
            backgroundColor: const Color(0xFF388E3C),
          ));
        },
        onAddressSelected: (SelectedAddress address) {
          setState(() {
            _addressLabel    = address.label;
            _addressSubtitle = address.subtitle;
          });
          _saveAddress(address);
          _searchFocus.unfocus();
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
      ),
    ).then((_) {
      _searchFocus.unfocus();
      FocusScope.of(context).unfocus();
    });
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color:       const Color(0xFFFF0080),
              strokeWidth: 2.5,
              displacement: 80,
              onRefresh:   _onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _buildAddressBar()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildQuickTabBar(),
                    ),
                  ),
                  if (_activeTab == QuickTab.mtl)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SearchBarDelegate(
                        child: _buildSearchBar(),
                        isTablet: isTablet,
                      ),
                    ),
                  if (_activeTab == QuickTab.mtl)
                    MtlTabBody(
                      key: _mtlKey,
                      externalSearchController: _searchCtrl,
                      searchFocusNode: _searchFocus,
                      searchLayerLink: _searchLayerLink,
                    ),
                  if (_activeTab == QuickTab.offZone)
                    const OffZoneTabBody(),
                  if (_activeTab == QuickTab.superMall)
                    const SuperMallTabBody(),
                  if (_activeTab == QuickTab.cafe)
                    const CafeTabBody(),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left:   16,
              right:  16,
              child:  _buildFloatingCartBar(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Address bar ────────────────────────────────────────────────────────────
  Widget _buildAddressBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(isTablet ? 24 : 16, isTablet ? 20 : 16, isTablet ? 24 : 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _showLocationSheet,
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF0080).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.home, color: Color(0xFFFF0080), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_addressLabel,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(_addressSubtitle,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[900]),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ],
                ),
              ),
            ]),
          ),
        ),
        GestureDetector(
          onTap: () {
            _searchFocus.unfocus();
            FocusScope.of(context).unfocus();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) {
              _loadProfileImage();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFFF0080).withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFFF0080),
              backgroundImage: _profileImagePath != null &&
                  File(_profileImagePath!).existsSync()
                  ? FileImage(File(_profileImagePath!)) as ImageProvider
                  : _profileServerImageUrl != null
                  ? NetworkImage(
                _profileServerImageUrl!.startsWith('http')
                    ? _profileServerImageUrl!
                    : '${ApiConfig.imageBase}$_profileServerImageUrl',
              ) as ImageProvider
                  : null,
              child: (_profileImagePath == null ||
                  !File(_profileImagePath!).existsSync()) &&
                  _profileServerImageUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                  : null,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Quick tab bar ──────────────────────────────────────────────────────────
  Widget _buildQuickTabBar() {
    final double tabWidth = isTablet ? 120 : 80;

    // ── DBM tab colors ─────────────────────────────────────────────────────
    const Color dbmSelectedBg       = Color(0xFFDEDEDE); // ← change selected bg
    const Color dbmUnselectedBg     = Colors.white;       // ← change unselected bg
    const Color dbmSelectedText     = Colors.black87;       // ← change selected text
    const Color dbmUnselectedText   = Color(0xFFB85C00);  // ← change unselected text
    const Color dbmBorderColor      = Color(0xFFFFB3D9);  // ← change border color

    // ── 50% OFF ZONE tab colors ────────────────────────────────────────────
    const Color offZoneSelectedBg       = Color(0xFFDEDEDE); // ← change selected bg
    const Color offZoneUnselectedBg     = Colors.white;       // ← change unselected bg
    const Color offZoneSelectedText     = Colors.black87;       // ← change selected text
    const Color offZoneUnselectedText   = Color(0xFFB85C00);  // ← change unselected text
    const Color offZoneBorderColor      = Color(0xFFFFB3D9);  // ← change border color

    // ── 10% OFF ZONE tab colors ────────────────────────────────────────────
    const Color superMallSelectedBg     = Color(0xFFDEDEDE); // ← change selected bg
    const Color superMallUnselectedBg   = Colors.white;       // ← change unselected bg
    const Color superMallSelectedText   = Colors.black87;       // ← change selected text
    const Color superMallUnselectedText = Color(0xFF1B5E20);  // ← change unselected text
    const Color superMallBorderColor    = Color(0xFFFFB3D9);  // ← change border color

    // ── Café tab colors ────────────────────────────────────────────────────
    const Color cafeSelectedBg       = Color(0xFFDEDEDE); // ← change selected bg
    const Color cafeUnselectedBg     = Colors.white;       // ← change unselected bg
    const Color cafeSelectedText     = Colors.black87;       // ← change selected text
    const Color cafeUnselectedText   = Color(0xFFB85C00);  // ← change unselected text
    const Color cafeBorderColor      = Color(0xFFFFB3D9);  // ← change border color

    return SizedBox(
      height: isTablet ? 60 : 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 12),
        children: [
          SizedBox(
            width: tabWidth,
            child: _tabItem(
              tab: QuickTab.mtl,
              label: 'DBM',
              selectedColor:       dbmSelectedBg,
              unselectedBg:        dbmUnselectedBg,
              selectedTextColor:   dbmSelectedText,
              unselectedTextColor: dbmUnselectedText,
              borderColor:         dbmBorderColor,
              isBold:   true,
              isItalic: true,
              isTablet: isTablet,
            ),
          ),
          const SizedBox(width: 8),

          SizedBox(
            width: tabWidth,
            child: _tabItem(
              tab: QuickTab.offZone,
              label: '50%\nOFF ZONE',
              selectedColor:       offZoneSelectedBg,
              unselectedBg:        offZoneUnselectedBg,
              selectedTextColor:   offZoneSelectedText,
              unselectedTextColor: offZoneUnselectedText,
              borderColor:         offZoneBorderColor,
              isBold:      true,
              bigTopLine:  true,
              isTablet:    isTablet,
            ),
          ),
          const SizedBox(width: 8),

          SizedBox(
            width: tabWidth,
            child: _tabItem(
              tab: QuickTab.superMall,
              label: '10%\nOFF ZONE',
              selectedColor:       superMallSelectedBg,
              unselectedBg:        superMallUnselectedBg,
              selectedTextColor:   superMallSelectedText,
              unselectedTextColor: superMallUnselectedText,
              borderColor:         superMallBorderColor,
              isBold:     true,
              bigTopLine: true,
              isTablet:   isTablet,
            ),
          ),
          const SizedBox(width: 8),

          SizedBox(
            width: tabWidth,
            child: _tabItem(
              tab: QuickTab.cafe,
              label: 'café',
              selectedColor:       cafeSelectedBg,
              unselectedBg:        cafeUnselectedBg,
              selectedTextColor:   cafeSelectedText,
              unselectedTextColor: cafeUnselectedText,
              borderColor:         cafeBorderColor,
              isItalic: true,
              isTablet: isTablet,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab item ───────────────────────────────────────────────────────────────
  Widget _tabItem({
    required QuickTab tab,
    required String   label,
    required Color    selectedColor,
    required Color    unselectedBg,
    required Color    selectedTextColor,
    required Color    unselectedTextColor,
    required Color    borderColor,
    bool isBold     = false,
    bool isItalic   = false,
    bool isTablet   = false,
    bool bigTopLine = false,
  }) {
    final isSelected = _activeTab == tab;
    final isMtl      = tab == QuickTab.mtl;

    return GestureDetector(
      onTap: () {
        _searchFocus.unfocus();
        FocusScope.of(context).unfocus();
        setState(() => _activeTab = tab);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          minHeight: isTablet ? 52 : 42,
          maxHeight: isTablet ? 56 : 44,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 10,
          vertical:   isTablet ? 10 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedBg,         // ← bg color
          borderRadius: BorderRadius.circular(14),                   // ← corner shape
          border: Border.all(
              color: isSelected ? selectedColor : borderColor,       // ← border color
              width: 1.5),                                           // ← border width
          boxShadow: isSelected
              ? [BoxShadow(
              color: selectedColor.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3))]
              : [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1))],
        ),
        child: Center(
          child: bigTopLine
              ? RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: [
              TextSpan(
                text: '${label.split('\n').first}\n',
                style: TextStyle(
                  fontSize:   isTablet ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  height: 1.2,
                ),
              ),
              TextSpan(
                text: label.split('\n').length > 1
                    ? label.split('\n').sublist(1).join('\n')
                    : '',
                style: TextStyle(
                  fontSize:   isTablet ? 9 : 8,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  height: 1.2,
                ),
              ),
            ]),
          )
              : Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:      isMtl ? (isTablet ? 24 : 18) : (isTablet ? 15 : 12),
              fontWeight:    isBold ? FontWeight.bold : FontWeight.w500,
              fontStyle:     isItalic ? FontStyle.italic : FontStyle.normal,
              color: isSelected ? selectedTextColor : unselectedTextColor,
              height:        1.25,
              letterSpacing: isMtl ? 0.5 : 0,
            ),
          ),
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return CompositedTransformTarget(
      link: _searchLayerLink,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
        child: Container(
          height: isTablet ? 56 : 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: Colors.black87, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode:  _searchFocus,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search products, categories, offers…',
                  hintStyle: TextStyle(color: Colors.black87, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _searchFocus.unfocus();
                  setState(() {});
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.close, size: 18, color: Colors.black87),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ── Floating cart bar ──────────────────────────────────────────────────────
  Widget _buildFloatingCartBar() {
    return Consumer<CartModel>(
      builder: (context, cart, _) {
        final totalQty   = cart.totalQuantity;
        final totalPrice = cart.totalPrice;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeInOut,
          offset:   totalQty == 0
              ? const Offset(0, 1.5)
              : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity:  totalQty == 0 ? 0.0 : 1.0,
            child: GestureDetector(
              onTap: totalQty == 0 ? null : () {
                _searchFocus.unfocus();
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartScreen(
                      token:      widget.authToken ?? '',
                      customerId: '',
                      onGoToHome: () => Navigator.pop(context),
                    ),
                  ),
                );
              },
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0080), Color(0xFFFF0080)],
                    begin:  Alignment.centerLeft,
                    end:    Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:      const Color(0xFFFF0080).withOpacity(0.4),
                      blurRadius: 16,
                      offset:     const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalQty ${totalQty == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'View Cart',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:         Colors.white,
                          fontSize:      16,
                          fontWeight:    FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      '₹${totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Search bar delegate ────────────────────────────────────────────────────
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool   isTablet;

  const _SearchBarDelegate({required this.child, required this.isTablet});

  double get _height => isTablet ? 72.0 : 64.0;

  @override double get minExtent => _height;
  @override double get maxExtent => _height;

  @override
  bool shouldRebuild(_SearchBarDelegate old) =>
      old.isTablet != isTablet || old.child != child;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: child,
      ),
    );
  }
}