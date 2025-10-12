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
import 'package:workmanager/workmanager.dart';
import 'services/crash_detector.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initNotifications();

  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  await Workmanager().registerPeriodicTask(
    "1",
    "crashCheckTask",
    frequency: Duration(minutes: 1),
  );

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
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          primaryColor: Colors.blueGrey[50],
          colorScheme: const ColorScheme.light(
            primary: Colors.black,
            secondary: Colors.teal,
          ),
        ),
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
