import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login/splash_screen.dart';
import 'model/cart_model.dart';
import 'model/favorites_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cart          = CartModel();
  final favoritesModel = FavoritesModel();
  final prefs         = await SharedPreferences.getInstance();

  final savedUserId = prefs.getString('customer_id');
  if (savedUserId != null && savedUserId.isNotEmpty) {
    await cart.loadForUser(savedUserId);
    await favoritesModel.loadForUser(savedUserId);
  } else {
    await cart.loadCart();
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
      title: 'MTL Groceries',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}