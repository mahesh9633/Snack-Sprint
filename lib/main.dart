import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login/splash_screen.dart';
import 'model/cart_model.dart';
import 'model/favorites_model.dart';


final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  // Pre-warm SharedPreferences once so all screens reuse the cache
  final prefs = await SharedPreferences.getInstance();

  final cart           = CartModel();
  final favoritesModel = FavoritesModel();

  // Show snackbar when stock limit is reached
  cart.onStockLimitReached = (message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      ),
    );
  };

  final savedUserId = prefs.getString('customer_id');
  if (savedUserId != null && savedUserId.isNotEmpty) {
    await cart.loadForUser(savedUserId);
    await favoritesModel.loadForUser(savedUserId);
  } else {
    await cart.loadCart();
  }

  // Disable all print() statements in release mode
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CartModel>.value(value: cart),
        ChangeNotifierProvider<FavoritesModel>.value(value: favoritesModel),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'MTL Groceries',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0080),
          brightness: Brightness.light,
        ).copyWith(
          background: Colors.white,
          surface: Colors.white,
          surfaceVariant: Colors.white,
          surfaceTint: Colors.transparent,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}