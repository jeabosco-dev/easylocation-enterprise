import 'package:flutter/material.dart';

class StatVisitesCard extends StatelessWidget {
  final int count;
  const StatVisitesCard({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return _buildCard("Visites", "$count", Icons.visibility, Colors.blue);
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}