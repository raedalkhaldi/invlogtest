import 'package:flutter/material.dart';
import '../screens/profile/profile_screen.dart';

class NavigationUtils {
  static void navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }
} 