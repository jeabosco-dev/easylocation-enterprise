import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart'; 
import 'package:cached_network_image/cached_network_image.dart';

import '../services/calculateur_expertise.dart';
import '../models/formulaire_publication_model.dart';
import '../models/property_model.dart'; 
import '../widgets/bouton_action_principale_louer.dart';
import '../widgets/reference_badge_widget.dart'; 
import 'details_paiement_page.dart'; 

class RapportExpertisePage extends StatelessWidget {
  final FormulairePublicationModel propriete;

  const RapportExpertisePage({
    super.key, 
    required this.propriete
  });

  @override
  Widget build(BuildContext context) {
    // ✅ ÉTAPE 1 : Création de la Property temporaire avec les VRAIES données d'images
    // On ne passe plus de listes vides pour que le calculateur puisse valider les options (cuisine, etc.)
    final propertyTemporaire = Property.fromMap(
      propriete.toMap(
        mainImageUrl: propriete.mainImage?.url ?? '', 
        chambresImageUrls: propriete.chambresImages
            .where((e) => e.url != null)
            .map((e) => e.url!)
            .toList(),
        specificImageUrls: propriete.specificImages.map(
          (key, value) => MapEntry(key, value.url ?? ''),
        ),
      ), 
      'temp_id',
    );

    // ✅ ÉTAPE 2 : Calculs via le moteur expert
    final int scoreMax = CalculateurExpertise.calculerScoreMax();
    final int scoreCalcule = CalculateurExpertise.calculerScore(propertyTemporaire);
    final OffrePack offre = CalculateurExpertise.obtenirOffre(scoreCalcule, scoreMax);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: ReferenceBadgeWidget(
                reference: propriete.numeroMaison ?? 'N/A', 
              ),
              background: _buildImageHeader(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "ANALYSE DE QUALITÉ TERMINÉE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 25),

                  CircularPercentIndicator(
                    radius: 85.0,
                    lineWidth: 18.0,
                    animation: true,
                    animationDuration: 1500,
                    percent: (scoreCalcule / scoreMax).clamp(0.0, 1.0),
                    center: Text(
                      "$scoreCalcule/$scoreMax", 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28.0),
                    ),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Column(
                        children: [
                          Text(
                            "OFFRE ${offre.nom.toUpperCase()}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold, 
                              color: offre.color, 
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            "Basée sur le barème officiel EasyLocation",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: offre.color,
                    backgroundColor: Colors.grey.shade200,
                  ),

                  const SizedBox(height: 40),
                  _buildPointsForts(propriete),
                  const SizedBox(height: 40),
                  _buildSectionPrix(context, offre, propriete),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12, 
              blurRadius: 10, 
              offset: Offset(0, -5),
            )
          ],
        ),
        child: SafeArea( 
          child: BoutonActionPrincipaleLouer(
            isLoading: false,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsPaiementPage(
                    propriete: propriete,
                    offre: offre, 
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader() {
    if (propriete.mainImage?.url != null && propriete.mainImage!.url!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: propriete.mainImage!.url!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade300, 
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade200, 
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  Widget _buildPointsForts(FormulairePublicationModel f) {
    List<Widget> pointsFortsListe = [];

    if (f.maisonEnEtage == true && f.niveauEtage == 2) {
      pointsFortsListe.add(_elementPoint("Vue & Prestige : Situé au 2ème étage", Icons.auto_awesome));
    }

    if (f.typeMaison?.toLowerCase().contains('durab') == true && !(f.typeMaison?.toLowerCase().contains('semi') ?? false)) {
      pointsFortsListe.add(_elementPoint("Qualité : Construction durable", Icons.domain_rounded));
    }
    if ((f.nombreChambres ?? 0) >= 3) {
      pointsFortsListe.add(_elementPoint("Espace : Grande capacité (${f.nombreChambres} ch)", Icons.bed_rounded));
    }
    if (f.bailleurHabiteAvec == false) {
      pointsFortsListe.add(_elementPoint("Intimité : Bailleur absent", Icons.no_accounts_rounded));
    }
    if (f.electricite?.toLowerCase().contains('cash') ?? false) {
      pointsFortsListe.add(_elementPoint("Énergie : Compteur Cash Power solo", Icons.bolt_rounded));
    }
    if (f.maisonEnclos == true) {
      pointsFortsListe.add(_elementPoint("Sécurité : Propriété sous enclos", Icons.security_rounded));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ANALYSE DES POINTS FORTS", 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Divider(),
        if (pointsFortsListe.isNotEmpty) ...pointsFortsListe
        else const Text("Analyse standard effectuée.", style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }

  Widget _elementPoint(String texte, IconData icone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icone, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 15),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildSectionPrix(BuildContext context, OffrePack offre, FormulairePublicationModel p) {
    final double loyer = p.price ?? 0.0;
    final double montantBailleur = loyer * (offre.comBailleur / 100);
    final double montantLocataire = loyer * (offre.comLocataire / 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _lignePrix("Frais de service globaux (${offre.totalApp}%)", "${(loyer * (offre.totalApp / 100)).toStringAsFixed(1)}\$"),
          _lignePrix("Pris en charge par le Bailleur", "- ${montantBailleur.toStringAsFixed(1)}\$", estRemise: true),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("VOTRE PARTICIPATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                "${montantLocataire.toStringAsFixed(1)}\$", 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: offre.color)
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Soit seulement ${offre.comLocataire}% du loyer au lieu de ${offre.totalApp}%",
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _lignePrix(String label, String montant, {bool estRemise = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: estRemise ? Colors.green.shade700 : Colors.black54, fontSize: 13)),
          Text(montant, style: TextStyle(fontWeight: FontWeight.bold, color: estRemise ? Colors.green.shade700 : Colors.black)),
        ],
      ),
    );
  }
}