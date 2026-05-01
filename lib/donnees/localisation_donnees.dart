// lib/donnees/localisation_donnees.dart

class Province {
  final String nom;
  // Structure : Ville -> Commune -> Quartier -> List<Avenue>
  final Map<String, Map<String, Map<String, List<String>>>> villes;

  Province({required this.nom, required this.villes});
}

final List<Province> provincesCongo = [
  Province(
    nom: 'Sud-Kivu',
    villes: {
      'Bukavu': {
        'Ibanda': {
          'Nyamoma-la Botte': ['Autre'],
          'Nyawera': ['Avenue du Gouverneur', 'Autre'],
          'Nyofu': ['Autre'],
          'Muhumba': ['Autre'],
          'Mukukwe': ['Autre'],
          'ISP': ['Autre'],
          'Nguba': ['Autre'],
          'Hippodrome': ['Autre'],
          'Nyalukemba': ['Autre'],
          'Ndendere': ['Autre'],
          'Panzi': ['Avenue de la Paix', 'Autre'],
          'Autre': ['Autre'],
        },
        'Kadutu': {
          'Kasali': ['Autre'],
          'Limanga': ['Autre'],
          'Mosala': ['Autre'],
          'Nyamugo': ['Avenue Industrielle', 'Autre'],
          'Cimpunda': ['Autre'],
          'Kajangu': ['Autre'],
          'Nyakaliba': ['Autre'],
          'Buholi I': ['Autre'],
          'Buholi II': ['Autre'],
          'Buholi III': ['Autre'],
          'Buholi IV': ['Autre'],
          'Buholi V': ['Autre'],
          'Buholi VI': ['Autre'],
          'Autre': ['Autre'],
        },
        'Bagira': {
          'Quartier A': ['Autre'],
          'Quartier B': ['Autre'],
          'Quartier C': ['Autre'],
          'Quartier D': ['Autre'],
          'Mushekere': ['Autre'],
          'Autre': ['Autre'],
        },
        'Autre': {
          'Autre': ['Autre'],
        },
      },
      'Autre': {
        'Autre': {
          'Autre': ['Autre'],
        }
      },
    },
  ),
];

/**
 * ✅ FONCTION UTILITAIRE : Récupère toutes les villes disponibles 
 * pour les menus déroulants (Dropdown) de l'application.
 */
List<String> getAllVilles() {
  // Utilisation d'un Set pour éviter les doublons si plusieurs provinces ont une clé 'Autre'
  Set<String> villesSet = {};
  
  for (var province in provincesCongo) {
    // Récupère les clés du premier niveau de la Map 'villes'
    villesSet.addAll(province.villes.keys);
  }

  // Conversion en liste pour pouvoir trier
  List<String> villesList = villesSet.toList();

  // Nettoyage et tri
  villesList.remove('Autre'); // On le retire temporairement pour trier le reste alphabétiquement
  villesList.sort();          // Tri (Bukavu, Goma, etc.)
  villesList.add('Autre');    // On le rajoute à la fin pour une meilleure UX
  
  return villesList;
}