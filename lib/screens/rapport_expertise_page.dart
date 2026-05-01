// lib/pages/rapport_expertise_page.dart
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

// ✅ Import des utilitaires pour le formatage des prix
import '../utils/ui_utils.dart';
import '../services/calculateur_expertise.dart';
import '../services/config_service.dart';
import '../models/formulaire_publication_model.dart';
import '../models/property_model.dart';
import '../widgets/bouton_action_principale_louer.dart';
import '../widgets/reference_badge_widget.dart';
import 'details_paiement_page.dart';

class RapportExpertisePage extends StatefulWidget {
  final FormulairePublicationModel propriete;

  const RapportExpertisePage({
    super.key,
    required this.propriete,
  });

  @override
  State<RapportExpertisePage> createState() => _RapportExpertisePageState();
}

class _RapportExpertisePageState extends State<RapportExpertisePage> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? "guest_${DateTime.now().millisecondsSinceEpoch}";

  @override
  void initState() {
    super.initState();
    _updateActiveStatus(true);
  }

  @override
  void dispose() {
    _updateActiveStatus(false);
    super.dispose();
  }

  void _updateActiveStatus(bool isEntering) {
    if (widget.propriete.id == null) return;
    
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('status_activite')
        .doc(widget.propriete.id);

    if (isEntering) {
      docRef.set({
        'consultants_ids': FieldValue.arrayUnion([userId]),
        'last_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      docRef.set({
        'consultants_ids': FieldValue.arrayRemove([userId]),
        'last_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final configService = Provider.of<ConfigService>(context);
    final Map<String, dynamic> tauxConfig = configService.tauxExpertise;
    final String companyName = configService.companyInfo['name'] ?? "EasyLocation";

    final propertyTemporaire = Property.fromMap(
      widget.propriete.toMap(
        mainImageUrl: widget.propriete.mainImage?.url ?? '',
        chambresImageUrls: widget.propriete.chambresImages
            .where((e) => e.url != null)
            .map((e) => e.url!)
            .toList(),
        specificImageUrls: widget.propriete.specificImages.map(
          (key, value) => MapEntry(key, value.url ?? ''),
        ),
      ),
      widget.propriete.id ?? 'temp_id',
    );

    final int scoreMax = CalculateurExpertise.calculerScoreMax();
    final int scoreCalcule = CalculateurExpertise.calculerScore(propertyTemporaire);
    final OffrePack offre = CalculateurExpertise.obtenirOffre(
        scoreCalcule, scoreMax,
        config: tauxConfig);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(propertyTemporaire),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                children: [
                  _buildHeaderExpertise(scoreCalcule, scoreMax, offre),
                  const SizedBox(height: 15),
                  _buildLiveActivity(widget.propriete.id ?? ''),
                  const SizedBox(height: 25),
                  _buildGarantiesConfiance(companyName),
                  const SizedBox(height: 30),
                  _buildPointsForts(widget.propriete),
                  const SizedBox(height: 30),
                  _buildSectionFinanciere(context, offre, companyName),
                  const SizedBox(height: 30),
                  _buildNoteAccompagnement(companyName),
                  _buildSurpriseTeasing(offre, companyName),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(context, offre),
    );
  }

  Widget _buildSliverAppBar(Property property) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: ReferenceBadgeWidget(
          // ✅ UTILISATION DE LA RÉFÉRENCE UNIQUE (Auto-adaptative)
          reference: property.referenceUnique, 
        ),
        background: _buildImageHeader(),
      ),
    );
  }

  Widget _buildSectionFinanciere(BuildContext context, OffrePack offre, String companyName) {
    final double loyer = widget.propriete.price ?? 0.0;
    final double tauxLocataire = offre.comLocataire;
    final double partLocataire = loyer * (tauxLocataire / 100);
    final double tauxBailleur = offre.comBailleur;
    final double partBailleur = loyer * (tauxBailleur / 100);
    final double totalImmediat = partLocataire + partBailleur;
    
    final int moisGarantie = widget.propriete.garantieMinimale ?? 3; 
    
    final double garantieTotale = loyer * moisGarantie;
    final double resteAPayerBailleur = garantieTotale - partBailleur;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("DÉTAILS DE VOTRE RÉSERVATION",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1)),
        const SizedBox(height: 15),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _ligneCalcul("Loyer mensuel du bien", "${UIUtils.formatPrice(loyer)}\$", isBold: true),
              const Divider(),
              _ligneCalcul("Vos Frais de Service ($tauxLocataire%)", "+ ${UIUtils.formatPrice(partLocataire, decimalDigits: 1)}\$"),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Expertise technique et transport offerts par $companyName", 
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
              const SizedBox(height: 12),

              _ligneCalcul("Avance Frais Bailleur ($tauxBailleur%)", "+ ${UIUtils.formatPrice(partBailleur, decimalDigits: 1)}\$"),
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "Le bailleur vous propose de régler sa part de service maintenant ; ce montant sera déduit de votre garantie locative le jour J. C'est une simple avance.",
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontStyle: FontStyle.italic),
                ),
              ),
              
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL À RÉGLER ICI", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  Text("${UIUtils.formatPrice(totalImmediat, decimalDigits: 1)}\$", 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: offre.color)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_outlined, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text("VOTRE SOLDE CHEZ LE BAILLEUR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 12),
              _ligneCalcul("Garantie totale ($moisGarantie mois)", "${UIUtils.formatPrice(garantieTotale)}\$"),
              _ligneCalcul("Soustraction de votre avance", "- ${UIUtils.formatPrice(partBailleur, decimalDigits: 1)}\$", color: Colors.red),
              const Divider(),
              _ligneCalcul("Reste à payer au propriétaire", "${UIUtils.formatPrice(resteAPayerBailleur, decimalDigits: 1)}\$", isBold: true, color: Colors.green.shade900),
              const SizedBox(height: 10),
              Text(
                "Information importante : Le propriétaire est déjà informé que vous avez réglé une partie de sa garantie via notre plateforme. Le jour de la remise des clés, vous ne lui verserez que le solde de ${UIUtils.formatPrice(resteAPayerBailleur, decimalDigits: 1)}\$ au lieu de ${UIUtils.formatPrice(garantieTotale)}\$ pour les $moisGarantie mois de garantie. Votre avance de ${UIUtils.formatPrice(partBailleur, decimalDigits: 1)}\$ est officiellement reconnue et déduite de votre contrat.",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligneCalcul(String label, String montant, {Color color = Colors.black, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          Text(montant, style: TextStyle(
            fontSize: 14, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color
          )),
        ],
      ),
    );
  }

  Widget _buildSurpriseTeasing(OffrePack offre, String companyName) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [offre.color.withOpacity(0.1), Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, color: offre.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Une surprise vous attend à l'étape suivante... Découvrez les privilèges exclusifs que $companyName a réservés pour votre emménagement !",
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: offre.color,
                fontStyle: FontStyle.italic
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActivity(String propertyId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('status_activite')
          .doc(propertyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        List<dynamic> ids = snapshot.data!.get('consultants_ids') ?? [];
        int count = ids.length;
        if (count <= 1) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  "$count locataires étudient actuellement cette propriété. Nous vous recommandons de confirmer rapidement si elle vous intéresse.",
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderExpertise(int score, int max, OffrePack offre) {
    return Column(
      children: [
        Text(
          "ANALYSE DE QUALITÉ TERMINÉE",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 20),
        CircularPercentIndicator(
          radius: 80.0,
          lineWidth: 12.0,
          animation: true,
          percent: (score / max).clamp(0.0, 1.0),
          center: Text(
            "$score/$max",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26.0),
          ),
          footer: Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Text(
              "PACK ${offre.nom.toUpperCase()}",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: offre.color),
            ),
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: offre.color,
          backgroundColor: Colors.grey.shade100,
        ),
      ],
    );
  }

  Widget _buildGarantiesConfiance(String companyName) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.apartment, 
            "Entreprise établie et certifiée",
            "$companyName est une entreprise établie et certifiée. Nous vous accueillons dans nos bureaux pour garantir la transparence de vos démarches et la protection de vos contrats."
          ),
          const Divider(),
          _infoRow(
            Icons.shield_outlined, 
            "Réservez l'esprit tranquille",
            "Si le bien ne correspond pas à vos attentes après visite, nous vous accompagnons pour trouver une alternative sur notre plateforme $companyName. Si aucune option ne vous satisfait, nous vous restituons 100 % de votre argent, sans aucune condition."
          ),
          const Divider(),
          _infoRow(
            Icons.directions_car_filled, 
            "Transport 100% à notre charge",
            "Profitez d'un transport gratuit vers la maison pour votre visite de confirmation. Nos équipes vous conduisent en véhicule privé et facilitent votre mise en relation directe avec le bailleur."
          ),
        ],
      ),
    );
  }

  Widget _buildNoteAccompagnement(String companyName) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.handshake, color: Colors.green.shade700, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              "Un expert $companyName vous accompagne jusqu'à la remise des clés pour sécuriser votre emménagement.",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade800, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12, 
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader() {
    if (widget.propriete.mainImage?.url != null &&
        widget.propriete.mainImage!.url!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: widget.propriete.mainImage!.url!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
            color: Colors.grey.shade100,
            child: const Center(child: CircularProgressIndicator())),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      );
    }
    return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported));
  }

  Widget _buildPointsForts(FormulairePublicationModel f) {
    List<Widget> list = [];
    if (f.maisonEnEtage == true) {
      list.add(_elementPoint(
          "Appartement en étage (Vue & Sécurité)", Icons.auto_awesome));
    }
    if (f.maisonEnclos == true) {
      list.add(_elementPoint("Propriété sécurisée (Sous enclos)", Icons.security));
    }
    if (f.bailleurHabiteAvec == false) {
      list.add(
          _elementPoint("Intimité totale (Bailleur absent)", Icons.no_accounts));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("ANALYSE DES POINTS FORTS",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        const Divider(),
        ...list,
      ],
    );
  }

  Widget _elementPoint(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.green),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 13))
      ]),
    );
  }

  Widget _buildBottomAction(BuildContext context, OffrePack offre) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5))
      ]),
      child: SafeArea(
        child: BoutonActionPrincipaleLouer(
          isLoading: false,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DetailsPaiementPage(
                      propriete: widget.propriete, offre: offre)),
            );
          },
        ),
      ),
    );
  }
}