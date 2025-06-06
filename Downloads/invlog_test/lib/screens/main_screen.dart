import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'messages/conversations_screen.dart';
import 'checkin/checkin_screen.dart';
import 'explore/explore_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const SizedBox(), // Placeholder for check-in
    ConversationsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) async {
    if (index == 2) {
      // Show check-in screen as modal
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CheckInScreen(),
          fullscreenDialog: true,
        ),
      );
      
      // If check-in was successful, switch to home screen to see the new post
      if (result != null) {
        setState(() {
          _selectedIndex = 0; // Switch to home screen
        });
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Timeline',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_location),
            label: 'Check In',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
} 