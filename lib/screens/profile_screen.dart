import 'dart:io';
import 'package:mtl_groceriesapp/screens/privacy_policy.dart';
import 'package:mtl_groceriesapp/screens/terms_conditions.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/screens/wishlist.dart';
import 'package:provider/provider.dart';
import 'package:mtl_groceriesapp/login/login_screen.dart';
import 'package:mtl_groceriesapp/screens/saved_address_screen.dart';
import '../config/app_color.dart';
import '../model/address_model.dart';
import '../model/favorites_model.dart';
import '../model/cart_model.dart';
import '../services/api_config_service.dart';
import '../services/get_address_service.dart';
import '../services/get_profile_service.dart';
import '../services/logout_service.dart';
import '../services/session_manager.dart';
import 'profile_edit_screen.dart';
import 'your_orders_screen.dart';
import 'rewards_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  String  _telephone        = '';
  String  _displayName      = 'Snack Sprint user';
  int     _addressCount     = 0;
  String? _profileImagePath;
  String? _serverImageUrl;
  String  _contact          = '';
  int     _rewardPoints     = 0;

  // ── Theme: Snack Sprint Blue / Cream ───────────────────────────────────────────────
  static const Color _primaryBlue  = AppColors.primaryBlue;
  static const Color _accentBlue   = AppColors.primaryBlue;
  static const Color _scaffoldBg   = AppColors.scaffoldBg;
  static const Color _cardBg       = AppColors.cardWhite;

  String _kName(String phone)  => 'profile_name_$phone';
  String _kImage(String phone) => 'profile_image_$phone';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshAddressCount();
  }
  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshAddressCount();
  }

  // ── Pull-to-refresh handler ────────────────────────────────────────────────
  Future<void> _onRefresh() async {
    await _loadUserData();
  }

  Future<void> refresh() async {
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    // First load from local so screen shows something immediately
    final telephone  = await SessionManager.getTelephone();
    final phone      = telephone ?? '';
    final savedName  = await SessionManager.getString(_kName(phone));
    final savedImage = await SessionManager.getString(_kImage(phone));
    if (mounted) {
      setState(() {
        _telephone        = phone;
        if (_displayName.isEmpty || _displayName == 'Snack Sprint user') {
          _displayName = (savedName != null && savedName.isNotEmpty)
              ? savedName
              : 'Snack Sprint user';
        }
        _profileImagePath = (savedImage != null && savedImage.isNotEmpty)
            ? savedImage
            : null;
      });
    }

    // Then call API to get fresh data
    try {
      final result = await ProfileGetApiService.getProfile();
      if (result['success'] == true) {
        final data      = result['data'] as Map<String, dynamic>;
        final firstName = data['firstname']     as String? ?? '';
        final lastName  = data['lastname']      as String? ?? '';
        final telephone = data['telephone']     as String? ?? '';
        final imgUrl    = data['profile_image'] as String? ?? '';
        final contact   = data['contact']       as String? ?? '';

        final fullName = [firstName, lastName]
            .where((s) => s.isNotEmpty)
            .join(' ');

        if (mounted) {
          setState(() {
            _telephone      = telephone;
            _displayName    = fullName.isNotEmpty ? fullName : 'Snack Sprint user';
            _serverImageUrl = imgUrl.isNotEmpty ? imgUrl : null;
            _contact        = contact;
          });
        }
      }
    } catch (_) {
      // silently keep local data if API fails
    }

    await _refreshAddressCount();
  }

  Future<void> _refreshAddressCount() async {
    try {
      final token = await SessionManager.getString('token') ?? '';
      final serverList = await GetAddressApi.getAddresses(token: token);
      if (serverList.isNotEmpty) {
        await AddressStorage.replaceAll(serverList);
        if (mounted) setState(() => _addressCount = serverList.length);
        return;
      }
      // Server returned empty — fall back to local cache (offline-safe)
      final list = await AddressStorage.load();
      if (mounted) setState(() => _addressCount = list.length);
    } catch (_) {
      // Network failed — fall back to local cache
      final list = await AddressStorage.load();
      if (mounted) setState(() => _addressCount = list.length);
    }
  }

  Future<void> _openWishlist() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WishlistScreen()),
    );
  }

  Future<void> _openOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const YourOrdersScreen()),
    );
  }

  Future<void> _openAddresses() async {
    final token      = await SessionManager.getString('token')       ?? '';
    final customerId = await SessionManager.getString('customer_id') ?? '';
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SavedAddressesScreen(
          selectMode: false,
          token:      token,
          customerId: customerId,
        ),
      ),
    );
    // Refresh twice: once immediately, once after a short delay
    // to account for async save operations completing
    await _refreshAddressCount();
    await Future.delayed(const Duration(milliseconds: 300));
    await _refreshAddressCount();
  }

  Future<void> _openProfileEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
    await _loadUserData();
  }

  Future<void> _openSupport() async {
    final number = _contact.isNotEmpty ? _contact : _telephone;
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support contact not available')),
      );
      return;
    }
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final e164   = digits.startsWith('91') ? digits : '91$digits';
    final uri    = Uri.parse('https://wa.me/$e164');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp is not installed')),
        );
      }
    }
  }

  Future<void> _openRewards() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RewardsScreen()),
    );
  }

  Future<void> _openTermsConditions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsConditionsScreen(fromProfile: true),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(fromProfile: true),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    context.read<FavoritesModel>().onLogout();
    context.read<CartModel>().clearCartMemoryOnly();

    await LogoutService.logout();
    await SessionManager.clearSession();

    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  void didPopNext() {
    // Called when coming back to this screen from any pushed route
    _refreshAddressCount();
  }

  @override
  Widget build(BuildContext context) {
    final addrLabel = _addressCount == 0
        ? 'No Addresses'
        : '$_addressCount ${_addressCount == 1 ? 'Address' : 'Addresses'}';

    return Scaffold(
      backgroundColor: AppColors.cardWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        title: const Text(
          'Settings',
          style: TextStyle(
              color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),

      // ── CHANGED: Column wraps fixed header + scrollable list ──────────────
      body: Column(
        children: [

          // ── FIXED: User Header (does NOT scroll) ──────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              GestureDetector(
                onTap: _openProfileEdit,
                child: Stack(children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                    backgroundImage: _profileImagePath != null &&
                        File(_profileImagePath!).existsSync()
                        ? FileImage(File(_profileImagePath!)) as ImageProvider
                        : _serverImageUrl != null
                        ? NetworkImage(
                      _serverImageUrl!.startsWith('http')
                          ? _serverImageUrl!
                          : '${ApiConfig.imageBase}$_serverImageUrl',
                    ) as ImageProvider
                        : null,
                    child: (_profileImagePath == null ||
                        !File(_profileImagePath!).existsSync()) &&
                        _serverImageUrl == null
                        ? const Icon(Icons.person, color: Colors.white, size: 36)
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: AppColors.buttonPrimary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_displayName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        // ── CHANGED: black text ───────────────────────────
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  _telephone.isEmpty ? 'Loading...' : '+91 $_telephone',
                  style: const TextStyle(
                      fontSize: 14,
                      // ── CHANGED: black text ───────────────────────────
                      color: Colors.black54),
                ),
              ]),
            ]),
          ),

          // ── FIXED: Icon Tabs: Orders | Wishlist | Support (does NOT scroll)
          // ── CHANGED: color is white, no brown border wrapper ──────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _iconTab(
                    Icons.shopping_bag_outlined,
                    'Orders',
                    // isActive: true,
                    onTap: _openOrders,
                  ),
                  _tabDivider(),
                  _iconTab(Icons.favorite_border, 'Wishlist', onTap: _openWishlist),
                  _tabDivider(),
                  _iconTab(Icons.chat_bubble_outline, 'Support', onTap: _openSupport),
                ],
              ),
            ),
          ),

          // ── Thin divider between fixed header and scrollable content ───────
          Divider(height: 1, color: Colors.grey[200]),

          // ── SCROLLABLE content below ───────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.floatingCartBg,
              backgroundColor: Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [

                  const SizedBox(height: 16),

                  // ── Your Information ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('YOUR INFORMATION',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.grey[600])),
                  ),
                  const SizedBox(height: 6),
                  _settingsCard([
                    _settingsRowWithSub(
                      Icons.location_on_outlined,
                      'Saved Addresses',
                      addrLabel,
                      onTap: _openAddresses,
                      badge: _addressCount > 0 ? '$_addressCount' : null,
                    ),
                    _divider(),
                    _settingsRow(Icons.person_outline, 'Profile',
                        onTap: _openProfileEdit),
                  ]),

                  const SizedBox(height: 16),

                  // ── Other Information ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('OTHER INFORMATION',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.grey[600])),
                  ),
                  const SizedBox(height: 6),
                  _settingsCard([
                    _settingsRow(Icons.favorite_border, 'Your Wishlist', onTap: _openWishlist),
                    _divider(),
                    _settingsRowWithSub(
                      Icons.card_giftcard,
                      'Rewards',
                      _rewardPoints == 0
                          ? 'Tap to check points'
                          : '$_rewardPoints points available',
                      onTap: _openRewards,
                    ),
                    _divider(),
                    _settingsRow(Icons.notifications_none, 'Notifications'),
                    _divider(),
                    _settingsRow(Icons.description_outlined, 'Terms & Conditions',
                        onTap: _openTermsConditions),
                    _divider(),
                    _settingsRow(Icons.lock_outline, 'Privacy Policy',
                        onTap: _openPrivacyPolicy),
                  ]),

                  const SizedBox(height: 16),

                  // ── Log Out ──────────────────────────────────────────────
                  Container(
                    color: _cardBg,
                    child: InkWell(
                      onTap: _logout,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text('Log Out',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── App Version ──────────────────────────────────────────
                  Center(
                    child: Column(children: [
                      Text('App version 1.0.0',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('Snack Sprint Groceries',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(height: 32),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _iconTab(IconData icon, String label,
      {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(8),
        )
            : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 24,
              color: isActive ? Colors.white : AppColors.primaryBlue),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.primaryBlue)),
        ]),
      ),
    );
  }

  Widget _tabDivider() =>
      Container(width: 1, height: 36, color: AppColors.primaryBlue.withOpacity(0.15));

  Widget _settingsCard(List<Widget> children) =>
      Container(color: _cardBg, child: Column(children: children));

  Widget _divider() =>
      Divider(height: 1, indent: 56, endIndent: 0, color: Colors.grey[200]);

  Widget _settingsRow(IconData icon, String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: AppColors.primaryBlue),
          const SizedBox(width: 16),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDark))),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  Widget _settingsRowWithSub(
      IconData icon,
      String title,
      String subtitle, {
        VoidCallback? onTap,
        String? badge,
      }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 22, color: AppColors.primaryBlue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ]),
          ),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.floatingCartBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}