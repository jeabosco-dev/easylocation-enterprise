// lib/web_admin/sidebar_menu.dart

import 'package:flutter/material.dart';

class SidebarMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final List<Map<String, dynamic>> availableTabs;

  const SidebarMenu({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.availableTabs,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      // Extension automatique si l'écran est large (Desktop)
      extended: MediaQuery.of(context).size.width > 1100,
      backgroundColor: const Color(0xFF1E293B),
      unselectedIconTheme: const IconThemeData(color: Colors.white60),
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white60),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white, 
        fontWeight: FontWeight.bold
      ),
      destinations: availableTabs.map((tab) {
        return NavigationRailDestination(
          icon: Icon(tab['icon']),
          label: Text(tab['label']),
        );
      }).toList(),
    );
  }
}