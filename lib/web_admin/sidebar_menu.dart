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
    return Container(
      color: const Color(0xFF1E293B), // Préserve ton fond sombre d'origine
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // S'assure que le menu occupe au moins toute la hauteur de l'écran disponible
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical,
            ),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                // Extension automatique si l'écran est large (Desktop) - Gardé intact
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}