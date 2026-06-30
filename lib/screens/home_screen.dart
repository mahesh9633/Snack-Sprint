import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mtl_groceriesapp/model/cart_model.dart';
import '../config/app_color.dart';
import 'home_tab.dart';
import 'categories_screen.dart';
import 'trending_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool    isNewCustomer;
  final String? telephone;
  final String? authToken;
  final String? customerId;

  const HomeScreen({
    super.key,
    this.isNewCustomer = false,
    this.telephone,
    this.authToken,
    this.customerId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  late final List<Widget> _screens;

  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();

    _screens = [
      HomeTab(
        key:           _homeTabKey,
        isNewCustomer: widget.isNewCustomer,
        mobile:        widget.telephone,
        authToken:     widget.authToken,
      ),
      const CategoriesScreen(),
      const TrendingScreen(),
      ProfileScreen(key: _profileKey),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartModel>().loadCart();
    });
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedNavIndex = index);
    if (index == 0) {
      _homeTabKey.currentState?.resetToHome();
    }
    if (index == 3) {
      _profileKey.currentState?.refresh();
    }
  }

  Future<bool> _handleBackPress() async {
    // If not on Home tab, go back to Home tab instead of closing
    if (_selectedNavIndex != 0) {
      setState(() => _selectedNavIndex = 0);
      _homeTabKey.currentState?.resetToHome();
      return false;
    }

    // Already on Home tab -> require double back-press to exit
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedNavIndex,
          children: _screens,
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildNavItem(Icons.home,        'Home',       0),
              _buildNavItem(Icons.grid_view,   'Categories', 1),
              _buildNavItem(Icons.trending_up, 'Trending',   2),
              _buildNavItem(Icons.person,      'Profile',    3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final selected = _selectedNavIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onNavItemTapped(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? AppColors.activeNav : AppColors.inactiveNav,
                  size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.activeNav : AppColors.inactiveNav,
                  fontSize:   12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}