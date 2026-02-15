// lib/donnees/localisation_donnees.dart

class Province {
  final String nom;
  // Ville -> Commune -> Quartier -> List<Avenue>
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
          'Nyawera': ['Avenue du Gouverneur', 'Autre'], // Muhumba retiré ici
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
