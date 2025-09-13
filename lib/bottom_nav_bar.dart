import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:raxxy/screens/dashboard_screen.dart';
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
      VehiclesScreen(controller: _controller,),
      SettingsScreen(controller: _controller,),
    ];
  }

  List<PersistentBottomNavBarItem> _navBarsItems() {
    return [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.dashboard),
        title: ("Dashboard"),
        activeColorPrimary: Color(0xff8f89ff),
        inactiveColorPrimary: Colors.grey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.directions_car),
        title: ("Vehicles"),
        activeColorPrimary: Color(0xff8f89ff),
        inactiveColorPrimary: Colors.grey,
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.settings),
        title: ("Settings"),
        activeColorPrimary: Color(0xff8f89ff),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navBarStyle: NavBarStyle.style1,
    );
  }
}

class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('This is the $title page')),
    );
  }
}
