import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/safety_feature_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:raxxy/authorization_screens/login_screen.dart';
import 'package:raxxy/firebase_options.dart';
import 'package:raxxy/providers/theme_provider.dart';
import 'package:raxxy/services/notifications_services.dart';
import 'bottom_nav_bar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "raxxy.env");

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  await initNotifications();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Sync emergency contact on app start
    _syncEmergencyContact();
  }

  Future<void> _syncEmergencyContact() async {
    // Listen to the emContactProvider once to get the value
    ref.listen(emergencyContactProvider, (previous, next) {
      next.whenData((contact) {
        if (contact != null) {
          // Save to SharedPreferences
          final prefs = ref.read(sharedPreferencesProvider);
          prefs.setString('emergency_contact', contact);
          print('Emergency contact synced to SharedPreferences: $contact');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    return ScreenUtilInit(
      designSize: const Size(360, 740),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigatorKey,
        themeMode: themeMode,

        // --- RAXXY LIGHT THEME ---
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF4F5F9), // Clean tech grey
          cardColor: Colors.white,

          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8B7CFF), // RAXXY Purple
            onPrimary: Colors.white,
            secondary: Color(0xFF00E5FF), // RAXXY Cyan
            onSecondary: Color(0xFF0A0E27),
            surface: Colors.white,
            onSurface: Colors.black87,
            error: Color(0xFFFF5252), // Alert Red
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF4F5F9),
            elevation: 0,
            iconTheme: IconThemeData(color: Color(0xFF0A0E27)),
            titleTextStyle: TextStyle(
              color: Color(0xFF0A0E27),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),

          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
              side: BorderSide(color: Colors.black.withOpacity(0.05)),
            ),
          ),

          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
            bodyMedium: TextStyle(color: Colors.black54, fontSize: 14),
            titleLarge: TextStyle(
              color: Color(0xFF0A0E27),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        // --- RAXXY DARK THEME ---
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0E27), // Deep Space
          cardColor: const Color(0xFF1A1F3A), // Elevated Space

          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF), // RAXXY Cyan
            onPrimary: Color(0xFF0A0E27),
            secondary: Color(0xFF8B7CFF), // RAXXY Purple
            onSecondary: Colors.white,
            surface: Color(0xFF1A1F3A),
            onSurface: Colors.white,
            error: Color(0xFFFF5252), // Alert Red
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0A0E27),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),

          cardTheme: CardThemeData(
            elevation: 0,
            color: const Color(0xFF1A1F3A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
              side: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),

          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
            bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
            titleLarge: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        debugShowCheckedModeBanner: false,

        home: authState.when(
          data: (user) => user != null ? const PersistentNavWrapper() : const LoginScreen(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('System Error: $e')),
          ),
        ),
      ),
    );
  }
}