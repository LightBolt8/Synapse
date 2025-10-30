import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  final int currentIndex; // 0: Home, 1: AI, 2: Grades, 3: Notes, 4: Account

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppTheme.iosBlue,
        unselectedItemColor: AppTheme.systemGray,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
        ),
        onTap: (int index) {
          if (index == currentIndex) return;
          final String route = switch (index) {
            0 => '/my-classes',
            1 => '/ai',
            2 => '/grades',
            3 => '/notes',
            4 => '/account',
            _ => '/my-classes',
          };
          Navigator.of(context).pushReplacementNamed(route);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grading_outlined),
            activeIcon: Icon(Icons.grading),
            label: 'Grades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notes_outlined),
            activeIcon: Icon(Icons.notes),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}


