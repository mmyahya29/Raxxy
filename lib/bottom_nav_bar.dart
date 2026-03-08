import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/providers/theme_provider.dart';
import 'package:raxxy/screens/dashboard_screen.dart';
import 'package:raxxy/screens/maintenance_screen.dart';
import 'package:raxxy/screens/vehicles_screen.dart';
import 'package:raxxy/screens/settings_screen.dart';

class PersistentNavWrapper extends ConsumerStatefulWidget {
  const PersistentNavWrapper({super.key});

  @override
  ConsumerState<PersistentNavWrapper> createState() => _PersistentNavWrapperState();
}

class _PersistentNavWrapperState extends ConsumerState<PersistentNavWrapper> {
  late PersistentTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: 0);
  }

  List<Widget> _buildScreens() {
    return [
      DashboardScreen(controller: _controller),
      MaintenanceScreen(controller: _controller),
      VehiclesScreen(controller: _controller),
      SettingsScreen(controller: _controller),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems(bool isDark) {
    // Unified HUD Cyan for active states
    const activeColor = Color(0xFF00E5FF);
    final inactiveColor = isDark ? Colors.white30 : Colors.grey.shade400;

    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.dashboard_rounded),
        title: ("OVERVIEW"),
        textStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
        activeColorPrimary: activeColor,
        inactiveColorPrimary: inactiveColor,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.handyman_rounded),
        title: ("MAINTENANCE"),
        textStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
        activeColorPrimary: const Color(0xFF8B7CFF), // Purple accent for variety
        inactiveColorPrimary: inactiveColor,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.directions_car_rounded),
        title: ("FLEET"),
        textStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
        activeColorPrimary: const Color(0xFFFF9800), // Orange accent
        inactiveColorPrimary: inactiveColor,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.settings_suggest_rounded),
        title: ("SYSTEM"),
        textStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
        activeColorPrimary: const Color(0xFFFF5252), // Red accent
        inactiveColorPrimary: inactiveColor,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return PersistentTabView(
      context,
      controller: _controller,
      screens: _buildScreens(),
      items: _navBarsItems(isDark),
      confineToSafeArea: true,
      handleAndroidBackButtonPress: true,
      resizeToAvoidBottomInset: true,
      stateManagement: true,
      // hideNavigationBarWhenKeyboardShows: true,

      // Floating HUD Configuration
      margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
      backgroundColor: isDark ? const Color(0xFF1A1F3A).withOpacity(0.95) : Colors.white.withOpacity(0.95),

      decoration: NavBarDecoration(
        borderRadius: BorderRadius.circular(24.r),
        colorBehindNavBar: Colors.transparent,
        border: Border.all(
          color: isDark ? const Color(0xFF8B7CFF).withOpacity(0.3) : Colors.blue.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF00E5FF).withOpacity(0.08) : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      // Style 12 gives a highly animated, tech-focused look where the active icon pops
      navBarStyle: NavBarStyle.style12,
    );
  }
}