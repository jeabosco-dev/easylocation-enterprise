import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EnteteProfilWidget extends StatelessWidget {
  final String nom;
  final String prenom;
  final String? genre;
  final String? imageUrl;
  final bool isVerified;
  final String typeEspace; 

  const EnteteProfilWidget({
    super.key,
    required this.nom,
    required this.prenom,
    this.genre,
    this.imageUrl,
    required this.isVerified,
    this.typeEspace = "Bailleur",
  });

  @override
  Widget build(BuildContext context) {
    // 1. Détermination de la civilité
    String civilite = (genre == 'Homme') 
        ? 'Monsieur' 
        : (genre == 'Femme' ? 'Madame' : '');

    // 2. ✅ LOGIQUE "NOM DE SECOURS" (Corrigée sans accents)
    String identiteAffichee = '';
    if (prenom.trim().isNotEmpty) {
      identiteAffichee = prenom;
    } else if (nom.trim().isNotEmpty) {
      identiteAffichee = nom;
    }

    // 3. Construction du texte de bienvenue
    final String texteBienvenue = identiteAffichee.isNotEmpty
        ? "Bienvenue, $civilite $identiteAffichee !".replaceFirst('  ', ' ')
        : "Bienvenue dans votre espace $typeEspace";

    final bool aUneImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: aUneImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      imageBuilder: (context, imageProvider) => CircleAvatar(
                        radius: 40,
                        backgroundImage: imageProvider,
                        backgroundColor: Colors.transparent,
                      ),
                      placeholder: (context, url) => CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: const Icon(Icons.person, size: 40, color: Colors.grey),
                      ),
                    )
                  : CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texteBienvenue,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Mon Espace $typeEspace",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        isVerified ? Icons.verified : Icons.error_outline,
                        size: 16,
                        color: isVerified ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isVerified ? "Compte vérifié" : "Vérification en attente",
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
