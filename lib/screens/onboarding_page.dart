// lib/screens/onboarding_page.dart

import 'package:flutter/material.dart';
import '../widgets/widget_de_pied_de_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateTo(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("EasyLocation"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: FadeTransition(
          opacity: _animation,
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Image.asset(
              'assets/images/logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.house),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: theme.colorScheme.primary),
            onPressed: () => _navigateTo(context, '/connexion'),
            tooltip: 'Accéder à mon profil',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _animation,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0), // Padding vertical réduit
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // --- Section 1: Bienvenue ---
                      Text(
                        "Bienvenue sur EasyLocation !",
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "L'immobilier simplifié : trouvez votre futur chez-vous ou gérez vos locations en un clic.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      
                      const SizedBox(height: 25), // Réduit (était à 40)

                      // --- Section 2: Choix du Profil ---
                      Text(
                        "Comment souhaitez-vous utiliser l'application ?",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Bouton Locataire
                      OutlinedButton.icon(
                        onPressed: () => _navigateTo(context, '/inscription-locataire'),
                        icon: const Icon(Icons.person_search),
                        label: const Text(
                          'Je cherche un logement (Locataire)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.primary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Accédez à des milliers de maisons disponibles et réservez en ligne.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),

                      const SizedBox(height: 15), // Réduit (était à 20)

                      // Bouton Bailleur
                      OutlinedButton.icon(
                        onPressed: () => _navigateTo(context, '/inscription-bailleur'),
                        icon: const Icon(Icons.business_center),
                        label: const Text(
                          'Je propose un logement (Bailleur)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: theme.colorScheme.secondary,
                          side: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Publiez vos maisons et trouvez rapidement des locataires.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),

                      const SizedBox(height: 20), // Réduit (était à 50) - C'est ici que ça remonte !

                      // --- Section 3: Connexion ---
                      const Divider(),
                      const SizedBox(height: 15),
                      Text(
                        "Déjà inscrit ?",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _navigateTo(context, '/connexion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Se connecter à mon compte'),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            const WidgetDePiedDePage(),
          ],
        ),
      ),
    );
  }
}
