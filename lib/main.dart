import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

final FlutterLocalNotificationsPlugin _localNotifications =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important order and app notifications.',
  importance: Importance.high,
);

Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await _localNotifications.initialize(initSettings);

  await _localNotifications
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  // Tapped a notification while app was in background and is now opened.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initLocalNotifications();

  final prefs = await SharedPreferences.getInstance();

  final cart           = CartModel();
  final favoritesModel = FavoritesModel();

  cart.onStockLimitReached = (message) {
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
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


//==================================================================================
// import 'package:firebase_app_check/firebase_app_check.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'firebase_options.dart';
// import 'config/app_color.dart';
// import 'login/splash_screen.dart';
// import 'model/cart_model.dart';
// import 'model/favorites_model.dart';
//
// final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
//
// final FlutterLocalNotificationsPlugin _localNotifications =
// FlutterLocalNotificationsPlugin();
//
// const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
//   'high_importance_channel',
//   'High Importance Notifications',
//   description: 'Used for important order and app notifications.',
//   importance: Importance.high,
// );
//
// Future<void> _initLocalNotifications() async {
//   const androidSettings =
//   AndroidInitializationSettings('@mipmap/ic_launcher');
//
//   const initSettings = InitializationSettings(
//     android: androidSettings,
//   );
//
//   await _localNotifications.initialize(initSettings);
//
//   await _localNotifications
//       .resolvePlatformSpecificImplementation<
//       AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(_androidChannel);
// }
//
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(
//     RemoteMessage message) async {
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
// }
//
// Future<void> _setupFCM() async {
//   final messaging = FirebaseMessaging.instance;
//
//   final settings = await messaging.requestPermission(
//     alert: true,
//     badge: true,
//     sound: true,
//   );
//
//   if (settings.authorizationStatus == AuthorizationStatus.authorized ||
//       settings.authorizationStatus == AuthorizationStatus.provisional) {
//     final token = await messaging.getToken();
//   }
//
//   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//     final notification = message.notification;
//
//     if (notification != null) {
//       _localNotifications.show(
//         notification.hashCode,
//         notification.title,
//         notification.body,
//         NotificationDetails(
//           android: AndroidNotificationDetails(
//             _androidChannel.id,
//             _androidChannel.name,
//             channelDescription: _androidChannel.description,
//             importance: Importance.high,
//             priority: Priority.high,
//             icon: '@mipmap/ic_launcher',
//           ),
//         ),
//       );
//     }
//   });
//
//   // Tapped a notification while app was in background and is now opened.
//   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});
// }
//
// // ------------------------------------------------------------
// // TEMPORARY APP CHECK TEST
// // ------------------------------------------------------------
// Future<void> testAppCheck() async {
//   try {
//     final token = await FirebaseAppCheck.instance.getToken(true);
//
//     if (token == null || token.isEmpty) {
//       debugPrint('APP CHECK: TOKEN IS NULL OR EMPTY');
//     } else {
//       debugPrint('APP CHECK: TOKEN RECEIVED SUCCESSFULLY');
//     }
//   } catch (e) {
//     debugPrint('APP CHECK ERROR: $e');
//   }
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//
//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       systemNavigationBarColor: Colors.transparent,
//       statusBarColor: Colors.transparent,
//     ),
//   );
//
//   // ------------------------------------------------------------
//   // FIREBASE INITIALIZATION
//   // ------------------------------------------------------------
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   // ------------------------------------------------------------
//   // FIREBASE APP CHECK
//   // LOCAL DEVELOPMENT = DEBUG PROVIDER
//   // ------------------------------------------------------------
//   await FirebaseAppCheck.instance.activate(
//     // androidProvider: AndroidProvider.playIntegrity,
//     androidProvider: AndroidProvider.debug,
//   );
//
//   // Test that Flutter can obtain an App Check token.
//   await testAppCheck();
//
//   // ------------------------------------------------------------
//   // FIREBASE MESSAGING
//   // ------------------------------------------------------------
//   FirebaseMessaging.onBackgroundMessage(
//     _firebaseMessagingBackgroundHandler,
//   );
//
//   await _initLocalNotifications();
//
//   final prefs = await SharedPreferences.getInstance();
//
//   final cart = CartModel();
//   final favoritesModel = FavoritesModel();
//
//   cart.onStockLimitReached = (message) {
//     scaffoldMessengerKey.currentState
//       ?..clearSnackBars()
//       ..showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               const Icon(
//                 Icons.warning_amber_rounded,
//                 color: Colors.white,
//                 size: 18,
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(message),
//               ),
//             ],
//           ),
//           backgroundColor: Colors.red[600],
//           duration: const Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//           margin: const EdgeInsets.fromLTRB(
//             12,
//             0,
//             12,
//             80,
//           ),
//         ),
//       );
//   };
//
//   final savedUserId = prefs.getString('customer_id');
//
//   if (savedUserId != null && savedUserId.isNotEmpty) {
//     await cart.loadForUser(savedUserId);
//     await favoritesModel.loadForUser(savedUserId);
//   } else {
//     await cart.loadCart();
//   }
//
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider<CartModel>.value(
//           value: cart,
//         ),
//         ChangeNotifierProvider<FavoritesModel>.value(
//           value: favoritesModel,
//         ),
//       ],
//       child: const MyApp(),
//     ),
//   );
//
//   // Set up FCM listeners/permissions after the app has been launched
//   // so the UI isn't blocked waiting on permission dialogs.
//   _setupFCM();
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       scaffoldMessengerKey: scaffoldMessengerKey,
//       title: 'Snack Sprint',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         scaffoldBackgroundColor: AppColors.scaffoldBg,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: AppColors.primaryBlue,
//           primary: AppColors.primaryBlue,
//           secondary: AppColors.primaryOrange,
//           brightness: Brightness.light,
//         ).copyWith(
//           surface: AppColors.cardWhite,
//           surfaceTint: Colors.transparent,
//         ),
//         textTheme: GoogleFonts.poppinsTextTheme(),
//         appBarTheme: const AppBarTheme(
//           backgroundColor: AppColors.cardWhite,
//           foregroundColor: AppColors.primaryBlue,
//           elevation: 0,
//           systemOverlayStyle: SystemUiOverlayStyle(
//             statusBarColor: Colors.transparent,
//             statusBarIconBrightness: Brightness.dark,
//             systemNavigationBarColor: Colors.transparent,
//           ),
//         ),
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }