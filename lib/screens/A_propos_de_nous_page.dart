// Fichier : lib/screens/A_propos_de_nous_page.dart

import 'package:flutter/material.dart';

class AProposDeNousPage extends StatelessWidget {
  const AProposDeNousPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('EasyLocation'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              "L'immobilier réinventé.",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: primaryColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Une plateforme au service de votre sérénité.",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Divider(),
            ),

            // Section : Qui sommes-nous
            _buildSectionTitle("Qui sommes-nous ?", primaryColor),
            const SizedBox(height: 16),
            const Text(
              "Nous sommes EasyLocation, une plateforme technologique congolaise dédiée à la location immobilière résidentielle en RDC. Notre mission est de simplifier ce processus pour tous. Grâce à notre application, les propriétaires peuvent facilement mettre en valeur leurs biens, et les futurs résidents peuvent trouver leur prochain foyer en toute simplicité et avec une transparence totale.",
              style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.6),
            ),

            const SizedBox(height: 35),

            // SECTION : Notre Mission
            _buildSectionTitle("Notre Mission", primaryColor),
            const SizedBox(height: 16),
            const Text(
              "\"Digitaliser l'immobilier en RDC pour offrir une location fiable, rapide et au meilleur rapport qualité-prix.\"",
              style: TextStyle(
                fontSize: 17, 
                fontWeight: FontWeight.bold, 
                color: Colors.black, // Corrigé ici
                fontStyle: FontStyle.italic
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Comment nous transformons votre expérience :",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            _buildMissionStep(Icons.auto_awesome, "Home to You", "Ce n’est plus à vous de chercher : nos alertes et recommandations amènent la maison de vos critères jusqu'à vous."),
            _buildMissionStep(Icons.campaign, "Visibilité Bailleurs", "Nous connectons les propriétaires aux bons locataires, pour louer mieux, plus vite et en toute sécurité."),
            _buildMissionStep(Icons.phonelink_setup, "Gestion Connectée", "Suivez vos contrats, paiements et échéances en temps réel via notre application."),
            _buildMissionStep(Icons.verified_user, "Confiance Certifiée", "Chaque bien, bailleur et locataire subit une vérification rigoureuse pour garantir des transactions sécurisées."),
            _buildMissionStep(Icons.handshake, "Service Intégral", "De la visite à l'emménagement, EasyLocation vous assiste à chaque étape pour une expérience fluide et sans stress."),

            const SizedBox(height: 35),

            // Devise
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: primaryColor, width: 5)),
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NOTRE DEVISE",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "\"La location en toute confiance.\"",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Valeurs
            _buildSectionTitle("Nos Valeurs", primaryColor),
            const SizedBox(height: 20),
            _buildValueCard("Simplicité", "Une application intuitive pour une expérience sans tracas."),
            _buildValueCard("Transparence", "Des informations complètes et honnêtes pour bâtir la confiance."),
            _buildValueCard("Innovation", "Une approche technologique pour réinventer la location immobilière."),

            const SizedBox(height: 35),

            // Vision
            _buildSectionTitle("Notre Vision", primaryColor),
            const SizedBox(height: 16),
            Text(
              "Créer un avenir où trouver et louer un logement est une expérience de confiance, de simplicité et de sérénité.",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionStep(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14.5, color: Colors.black87, height: 1.4),
                children: [
                  TextSpan(text: "$title : ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: color.withOpacity(0.8),
      ),
    );
  }

  Widget _buildValueCard(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}