// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:mtl_groceriesapp/model/cart_model.dart';
// import 'home_tab.dart';
// import 'categories_screen.dart';
// import 'trending_screen.dart';
// import 'cart_screen.dart';
//
// class HomeScreen extends StatefulWidget {
//   final bool    isNewCustomer;
//   final String? telephone;
//   final String? authToken;
//   final String? customerId;
//
//   const HomeScreen({
//     super.key,
//     this.isNewCustomer = false,
//     this.telephone,
//     this.authToken,
//     this.customerId,
//   });
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   int _selectedNavIndex = 0;
//   final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
//
//   late final List<Widget> _screens;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _screens = [
//       HomeTab(
//         key:           _homeTabKey,
//         isNewCustomer: widget.isNewCustomer,
//         mobile:        widget.telephone,
//         authToken:     widget.authToken,
//       ),
//       const CategoriesScreen(),
//       const TrendingScreen(),
//       CartScreen(
//         token:      widget.authToken   ?? '',
//         customerId: widget.customerId  ?? '',
//         onGoToHome: () => setState(() => _selectedNavIndex = 0),
//       ),
//     ];
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<CartModel>().loadCart();
//     });
//   }
//
//   void _onNavItemTapped(int index) {
//     setState(() => _selectedNavIndex = index);
//     if (index == 0) {
//       _homeTabKey.currentState?.resetToHome();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: IndexedStack(
//         index: _selectedNavIndex,
//         children: _screens,
//       ),
//       bottomNavigationBar: _buildBottomNav(),
//     );
//   }
//
//   Widget _buildBottomNav() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.1),
//             blurRadius: 10,
//             offset: const Offset(0, -2),
//           )
//         ],
//       ),
//       child: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: Row(
//             children: [
//               _buildNavItem(Icons.home,        'Home',       0),
//               _buildNavItem(Icons.grid_view,   'Categories', 1),
//               _buildNavItem(Icons.trending_up, 'Trending',   2),
//               _buildCartNavItem(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildNavItem(IconData icon, String label, int index) {
//     final selected = _selectedNavIndex == index;
//     return Expanded(
//       child: GestureDetector(
//         behavior: HitTestBehavior.opaque,
//         onTap: () => _onNavItemTapped(index),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(vertical: 4),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(icon, color: selected ? const Color(0xFFFF0080) : Colors.grey),
//               const SizedBox(height: 4),
//               Text(
//                 label,
//                 style: TextStyle(
//                   color:      selected ? const Color(0xFFFF0080) : Colors.grey,
//                   fontSize:   12,
//                   fontWeight: selected ? FontWeight.bold : FontWeight.normal,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCartNavItem() {
//     final selected = _selectedNavIndex == 3;
//     return Expanded(
//       child: GestureDetector(
//         behavior: HitTestBehavior.opaque,
//         onTap: () => _onNavItemTapped(3),
//         child: Consumer<CartModel>(
//           builder: (context, cart, _) {
//             final count = cart.totalQuantity;
//             return Padding(
//               padding: const EdgeInsets.symmetric(vertical: 4),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Stack(
//                     clipBehavior: Clip.none,
//                     children: [
//                       Icon(Icons.shopping_cart,
//                           color: selected ? const Color(0xFFFF0080) : Colors.grey),
//                       if (count > 0)
//                         Positioned(
//                           right: -6,
//                           top:   -6,
//                           child: Container(
//                             width:  16,
//                             height: 16,
//                             decoration: const BoxDecoration(
//                               color: Color(0xFFFF0080),
//                               shape: BoxShape.circle,
//                             ),
//                             alignment: Alignment.center,
//                             child: Text(
//                               count > 9 ? '9+' : '$count',
//                               style: const TextStyle(
//                                   color:      Colors.white,
//                                   fontSize:   9,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Cart',
//                     style: TextStyle(
//                       color:      selected ? const Color(0xFFFF0080) : Colors.grey,
//                       fontSize:   12,
//                       fontWeight: selected ? FontWeight.bold : FontWeight.normal,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
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

  late final List<Widget> _screens;

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
      const ProfileScreen(),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedNavIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
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