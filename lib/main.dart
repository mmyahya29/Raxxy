import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:raxxy/authorization_screens/login_screen.dart';
import 'package:raxxy/firebase_options.dart';
import 'package:raxxy/providers/theme_provider.dart';
import 'package:raxxy/services/notifications_services.dart';
import 'bottom_nav_bar.dart';
import 'services/crash_detector.dart';
import 'package:telephony/telephony.dart';

final Telephony telephony = Telephony.instance;
bool smsPermissionGranted = false;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  smsPermissionGranted = await telephony.requestPhoneAndSmsPermissions ?? false;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initNotifications();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    return ScreenUtilInit(
      designSize: const Size(360, 740),
      builder: (_, __) => MaterialApp(
      navigatorKey: navigatorKey,
      themeMode: themeMode,

      // Theme configuration with pale lilac and pastel blue color scheme
      theme: ThemeData(
        brightness: Brightness.light,

        // Background color (pale lilac)
        scaffoldBackgroundColor: const Color(0xFFF0E6FF),

        // Main accent color (pastel blue)
        primaryColor: const Color(0xFFB8C5E6),

        colorScheme: const ColorScheme.light(
          primary: Color(0xFFB8C5E6),    // pastel blue
          secondary: Color(0xFFD4C1F0),   // pale lilac
          // NOTE: 'tertiary' may not exist on older SDKs; if there's an error remove this line.
          tertiary: Color(0xFF7986CB),    // darker blue for contrast
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB8C5E6),
          titleTextStyle: TextStyle(
            color: Color(0xFF2C3E6E),    // darker blue text
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2C3E6E)),
          elevation: 3,
          shadowColor: Color(0xFF9FA8DA),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.transparent, // 👈 Yeh sabse important change!
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(30)),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(30)),
            borderSide: BorderSide(color: Colors.transparent),
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: Color(0xFF9FA8DA).withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),


        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Color(0xFF2C3E6E),
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFF3F51B5),
            fontSize: 14,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF2C3E6E),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB8C5E6),
            foregroundColor: const Color(0xFF2C3E6E),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            elevation: 3,
            shadowColor: Color(0xFF9FA8DA).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ), // <-- important comma here

      // Dark Theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff434343),
        primaryColor: Colors.blueGrey[900],
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.tealAccent,
        ),
      ),

      debugShowCheckedModeBanner: false,

      home: authState.when(
        data: (user) =>
        user != null ? PersistentNavWrapper() : LoginScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('Error: $e')),
        ),
      ),
    ),
    );
  }
}