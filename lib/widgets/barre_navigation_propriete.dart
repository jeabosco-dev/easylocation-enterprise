import 'package:flutter/material.dart';

class BarreNavigationPropriete extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final PageController pageController;

  const BarreNavigationPropriete({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPrevious = currentIndex > 0;
    final bool hasNext = currentIndex < totalCount - 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // BOUTON PRÉCÉDENT (Largeur fixe pour éviter la disparition)
          SizedBox(
            width: 110, 
            child: TextButton.icon(
              onPressed: hasPrevious
                  ? () {
                      pageController.previousPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    }
                  : null,
              icon: const Icon(Icons.arrow_back_ios, size: 14),
              label: const Text("Précédent",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor: hasPrevious ? Colors.black87 : Colors.grey.withOpacity(0.3),
              ),
            ),
          ),

          // INDICATEUR (1 / X)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300)),
            child: Text(
              '${currentIndex + 1} / $totalCount',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
            ),
          ),

          // BOUTON SUIVANT (Largeur fixe pour éviter la disparition)
          SizedBox(
            width: 110,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: TextButton.icon(
                onPressed: hasNext
                    ? () {
                        pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut);
                      }
                    : null,
                icon: const Icon(Icons.arrow_back_ios, size: 14),
                label: const Text("Suivant",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: hasNext ? Colors.black87 : Colors.grey.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
