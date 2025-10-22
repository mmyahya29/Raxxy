import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final featureNotifierProvider =
StateNotifierProvider<featureNotifier, bool>((ref) => featureNotifier());

class featureNotifier extends StateNotifier<bool> {

  featureNotifier() : super(false) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final featureIndex = prefs.getInt("safety");

    if (featureIndex != null) {
      state = false;
    }
  }

  Future<void> togglefeature() async {
    final prefs = await SharedPreferences.getInstance();

    if (state == false) {
      state = true;
    } else {
      state = false;
    }
    print(state);
    await prefs.setString("safety", state.toString());
  }
}
