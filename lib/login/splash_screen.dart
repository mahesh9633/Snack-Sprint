import 'package:flutter/material.dart';
import 'package:mtl_groceriesapp/login/login_screen.dart';
import 'package:mtl_groceriesapp/screens/location_gateway.dart';

import '../config/app_color.dart';
import '../services/api_server.dart';
import '../services/session_manager.dart';
import '../services/store_profile_cache.dart';
import '../services/update_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeIn,
      ),
    );

    _animController.forward();
    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    // Keep the logo visible for the intended splash duration.
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    await UpdateService.checkForUpdate();

    if (!mounted) return;

    await _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    final isLoggedIn = await SessionManager.isLoggedIn();
    final token = await SessionManager.getToken();
    final telephone = await SessionManager.getTelephone();
    final customerId = await SessionManager.getCustomerId();

    if (!mounted) return;

    if (!isLoggedIn || token == null || token.isEmpty) {
      StoreProfileCache.clear();
      _goToLogin();
      return;
    }

    final profileFuture = StoreProfileCache.preload();

    final isValid = await ApiService.validateToken(
      token: token,
      customerId: customerId ?? '',
    );

    if (!mounted) return;

    if (!isValid) {
      await SessionManager.clearSession();
      StoreProfileCache.clear();

      if (!mounted) return;
      _goToLogin();
      return;
    }

    await profileFuture;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LocationGateway(
          telephone: telephone ?? '',
          customerId: customerId ?? '',
          authToken: token,
          isNewCustomer: false,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _goToLogin() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.cardWhite,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.cardWhite,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Image.asset(
                'assets/images/smile_logo.png',
                height: size.height * 0.3,
                width: size.width * 0.6,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
