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

        // Theme configuration with pale lilac and pastel blue color scheme
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFEBE3F4), // Pale lilac
          cardColor: Color(0xffe6e6e6),

          colorScheme: const ColorScheme.light(
            primary: Color(0xFF79399F), // Main accent (used in text/icons)
            onPrimary: Colors.white,
            secondary: Color(0xFFD4C1F0), // Pale lilac
            onSecondary: Color(0xFF2C3E6E),
            surface: Color(0xFFEBE3F4),
            onSurface: Color(0xFF2C3E6E),
            tertiary: Color(0xFF7986CB), // Darker blue for contrast
            error: Color(0xFFB00020),
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF79399F), // Deep purple
            titleTextStyle: TextStyle(
              color: Color(0xFFEBE3F4), // Light text on dark app bar
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            iconTheme: IconThemeData(color: Color(0xFFEBE3F4)),
            elevation: 3,
            shadowColor: Color(0xFF9FA8DA),
          ),

          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.transparent,
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
            color: const Color(0xFF9FA8DA),
            shadowColor: const Color(0xFF000000).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          textTheme: const TextTheme(
            bodyLarge: TextStyle(
              color: Color(0xFF2C3E6E), // Darker blue text
              fontSize: 16,
            ),
            bodyMedium: TextStyle(
              color: Color(0xFF3F51B5), // Accent blue
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
              shadowColor: const Color(0xFF9FA8DA).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
          ),
        ),

        // Dark Theme
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Color(0xFF0A0E27),
          cardColor: Color(0xff393939),

          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFFFFF), // Light blue-grey for dark mode primary
            onPrimary: Color(0xFF2C3E6E),
            secondary: Color(0xFF31293E), // Dark lilac
            onSecondary: Color(0xFFB8C5E6),
            surface: Color(0xFF36303A),
            onSurface: Color(0xFFB8C5E6),
            tertiary: Color(0xFF7986CB),
            error: Color(0xFFCF6679),
          ),

          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF68308A), // Dark grey-blue
            titleTextStyle: TextStyle(
              color: Color(0xFFB8C5E6),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            iconTheme: IconThemeData(color: Color(0xFFB8C5E6)),
            elevation: 3,
            shadowColor: Color(0xFF000000),
          ),

          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.transparent,
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
            color: Color(0xFF333333), // Slightly lighter than background
            shadowColor: Color(0xFF000000).withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          textTheme: const TextTheme(
            bodyLarge: TextStyle(
              color: Color(0xFFECDFF6),
              fontSize: 16,
            ),
            bodyMedium: TextStyle(
              color: Color(0xFFECDFF6),
              fontSize: 14,
            ),
            titleLarge: TextStyle(
              color: Color(0xFFECDFF6),
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
              shadowColor: const Color(0xFF000000).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
          ),
        ),

        debugShowCheckedModeBanner: false,

        home: authState.when(
          data: (user) => user != null ? PersistentNavWrapper() : LoginScreen(),
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