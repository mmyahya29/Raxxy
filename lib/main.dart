import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:raxxy/providers/provider.dart';
import 'package:raxxy/authorization_screens/login_screen.dart';
import 'package:raxxy/firebase_options.dart';
import 'package:raxxy/services/notifications_services.dart';
import 'package:raxxy/services/vehicle_monitor_service.dart';

import 'bottom_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initNotifications();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return ScreenUtilInit(
      designSize: const Size(360, 740),
      builder:
          (_, __) => MaterialApp(
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xff434343),
              primaryColor: Colors.blueGrey[900],
              colorScheme: ColorScheme.dark(
                primary: Colors.blueAccent,
                secondary: Colors.tealAccent,
              ),
            ),
            debugShowCheckedModeBanner: false,
            home: authState.when(
              data:
                  (user) =>
                      user != null
                          ? const PersistentNavWrapper()
                          : const LoginScreen(),
              loading:
                  () => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
              error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
            ),
          ),
    );
  }
}
