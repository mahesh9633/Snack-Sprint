import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'config/app_color.dart';
import 'login/splash_screen.dart';
import 'model/cart_model.dart';
import 'model/favorites_model.dart';


final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Must be a top-level function — handles notifications when app is
// terminated or in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Avoid heavy work here. Firebase.initializeApp() is required if you
  // touch any other Firebase service inside this handler.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Background message: ${message.messageId}');
}

Future<void> _setupFCM() async {
  final messaging = FirebaseMessaging.instance;

  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional) {
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');
    // TODO: send this token to your PHP/OpenCart backend so you can
    // target this device later (e.g. save to a `device_tokens` table).
  }

  // Foreground notifications — app open and in use.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(notification.title ?? notification.body ?? ''),
            ),
          ]),
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        ),
      );
    }
  });

  // Tapped a notification while app was in background and is now opened.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    // TODO: navigate to a specific screen based on message.data, e.g.
    // an order details screen or a banner/category page.
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  // Initialize Firebase before anything else that depends on it.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the background handler as early as possible.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

  // Set up FCM listeners/permissions after the app has been launched
  // so the UI isn't blocked waiting on permission dialogs.
  _setupFCM();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Smile Basket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          secondary: AppColors.primaryOrange,
          brightness: Brightness.light,
        ).copyWith(
          surface: AppColors.cardWhite,
          surfaceTint: Colors.transparent,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.cardWhite,
          foregroundColor: AppColors.primaryBlue,
          elevation: 0,
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