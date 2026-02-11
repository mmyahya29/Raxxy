import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/screens/dashboard_screen.dart';
import 'package:raxxy/screens/maintenance_screen.dart';
import 'package:raxxy/screens/vehicles_screen.dart';
import 'package:raxxy/screens/settings_screen.dart';

class PersistentNavWrapper extends StatefulWidget {
  const PersistentNavWrapper({super.key});

  @override
  State<PersistentNavWrapper> createState() => _PersistentNavWrapperState();
}

class _PersistentNavWrapperState extends State<PersistentNavWrapper> {
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
      VehiclesScreen(controller: _controller,),
      SettingsScreen(controller: _controller,),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems() {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.dashboard),
        title: ("Dashboard"),
        activeColorPrimary: Color(0xFFFFFFFF),
        inactiveColorPrimary: Colors.grey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.build),
        title: ("Maintenance"),
        activeColorPrimary: Color(0xFFFFFFFF),
        inactiveColorPrimary: Colors.grey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.directions_car),
        title: ("Vehicles"),
        activeColorPrimary: Color(0xFFFFFFFF),
        inactiveColorPrimary: Colors.grey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.settings),
        title: ("Settings"),
        activeColorPrimary: Color(0xFFFFFFFF),
        inactiveColorPrimary: Colors.grey,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      context,
      controller: _controller,
      screens: _buildScreens(),
      items: _navBarsItems(),
      confineToSafeArea: true,
      decoration: NavBarDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff6a11cb), Color(0xff2575fc)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2575fc).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor!,
      navBarStyle: NavBarStyle.style1,
    );
  }
}
