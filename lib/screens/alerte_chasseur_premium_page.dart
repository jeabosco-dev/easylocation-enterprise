import 'package:flutter/material.dart';

class AlerteChasseurPremiumPage extends StatefulWidget {
  final String userId; // ✅ Ajout du champ userId

  const AlerteChasseurPremiumPage({super.key, required this.userId}); // ✅ Requis dans le constructeur

  @override
  State<AlerteChasseurPremiumPage> createState() => _AlerteChasseurPremiumPageState();
}

class _AlerteChasseurPremiumPageState extends State<AlerteChasseurPremiumPage> {
  // Variable pour simuler la sélection d'un forfait
  String _selectedPlanId = '1'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Chasseur Immo VIP",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER : ARGUMENT DE VENTE ---
            _buildHeroSection(),

            const SizedBox(height: 30),

            // --- SECTION 1 : RAPPEL DES FILTRES ---
            const Text(
              "Mes critères de recherche",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCriteriaSummary(),

            const SizedBox(height: 40),

            // --- SECTION 2 : CHOIX DU FORFAIT ---
            const Text(
              "Choisir ma durée d'abonnement",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildPricingGrid(),

            const SizedBox(height: 50),

            // --- BOUTON D'ACTION ---
            _buildSubmitButton(),

            const SizedBox(height: 20),
            const Center(
              child: Text(
                "Paiement sécurisé via Mobile Money",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 45, color: Colors.yellowAccent),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Service Prioritaire",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 4),
                Text(
                  "Recevez les alertes WhatsApp 2 minutes après la publication du bailleur.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCriteriaSummary() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSmallChip("Gombe", Icons.location_on),
        _buildSmallChip("3 Chambres", Icons.bed),
        _buildSmallChip("Eau permanente", Icons.water_drop),
        _buildSmallChip("Max 600\$", Icons.payments),
      ],
    );
  }

  Widget _buildSmallChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.deepPurple),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPricingGrid() {
    return Row(
      children: [
        _buildPriceCard("7 Jours", "1 \$", "1"),
        const SizedBox(width: 10),
        _buildPriceCard("1 Mois", "3 \$", "2"),
        const SizedBox(width: 10),
        _buildPriceCard("3 Mois", "7 \$", "3"),
      ],
    );
  }

  Widget _buildPriceCard(String title, String price, String id) {
    bool isSelected = _selectedPlanId == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlanId = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple.shade600 : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected ? [BoxShadow(color: Colors.deepPurple.withOpacity(0.2), blurRadius: 10)] : [],
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                price,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        onPressed: () {
          // TODO: Utiliser widget.userId pour lier le paiement à l'utilisateur
          debugPrint("Activation VIP pour l'utilisateur : ${widget.userId}");
        },
        child: const Text(
          "ACTIVER MON CHASSEUR VIP",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      ),
    );
  }
}
