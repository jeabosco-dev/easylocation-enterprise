import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:easylocation_mvp/widgets/admin/upsell_tab_widget.dart';
// ✅ IMPORT DES WIDGETS DÉPORTÉS
import 'package:easylocation_mvp/widgets/admin/referral_settings_widget.dart';
import 'package:easylocation_mvp/widgets/admin/loyalty_settings_widget.dart';
import 'package:easylocation_mvp/widgets/admin/location_editor_widget.dart';
import 'package:easylocation_mvp/widgets/admin/category_editor_widget.dart';
import 'package:easylocation_mvp/widgets/admin/wallet_limit_settings_widget.dart'; // <--- IMPORT AJOUTÉ

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // 1. Configuration Système
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _rccmController = TextEditingController();
  final TextEditingController _nifController = TextEditingController();
  final TextEditingController _idNatController = TextEditingController();

  // 2. Taux & Frais
  final TextEditingController _tauxUsdController = TextEditingController();
  final TextEditingController _refundFeeController = TextEditingController();

  // 3. ✅ MARKETING (Bienvenue, Parrainage & Fidélité)
  bool _isWelcomeBonusActive = false;
  final TextEditingController _welcomeAmountController = TextEditingController();
  final TextEditingController _welcomeDurationController = TextEditingController();

  bool _isReferralActive = false;
  final TextEditingController _referrerRewardController = TextEditingController();
  final TextEditingController _refereeRewardController = TextEditingController();

  // ✅ VARIABLES FIDÉLITÉ (LOYALTY)
  bool _isLoyaltyActive = false;
  final TextEditingController _locataireCashbackController = TextEditingController();
  final TextEditingController _bailleurDiscountController = TextEditingController();

  // 4. Expertise & Paiements
  Map<String, TextEditingController> bailleurControllers = {};
  Map<String, TextEditingController> locataireControllers = {};
  Map<String, TextEditingController> paymentNumControllers = {};
  Map<String, TextEditingController> paymentNameControllers = {};

  // 5. Services Upsell
  List<Map<String, dynamic>> upsellServiceControllers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('settings').doc('app_config').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _tauxUsdController.text = data['taux_usd_cdf']?.toString() ?? "2500";
          _refundFeeController.text = data['refund_service_fee']?.toString() ?? "5.0";

          // ✅ Chargement Bonus de Bienvenue
          if (data['welcome_bonus'] != null) {
            final bonus = data['welcome_bonus'] as Map<String, dynamic>;
            _isWelcomeBonusActive = bonus['is_active'] ?? false;
            _welcomeAmountController.text = bonus['amount']?.toString() ?? "5";
            _welcomeDurationController.text = bonus['duration_days']?.toString() ?? "30";
          }

          // ✅ Chargement Parrainage
          if (data['referral_config'] != null) {
            final ref = data['referral_config'] as Map<String, dynamic>;
            _isReferralActive = ref['is_active'] ?? false;
            _referrerRewardController.text = ref['referrer_reward']?.toString() ?? "5";
            _refereeRewardController.text = ref['referee_reward']?.toString() ?? "2";
          }

          // ✅ CHARGEMENT FIDÉLITÉ (LOYALTY)
          if (data['loyalty_config'] != null) {
            final loyalty = data['loyalty_config'] as Map<String, dynamic>;
            _isLoyaltyActive = loyalty['is_active'] ?? false;
            _locataireCashbackController.text = loyalty['locataire_cashback_percent']?.toString() ?? "5.0";
            _bailleurDiscountController.text = loyalty['bailleur_discount_percent']?.toString() ?? "10.0";
          }

          if (data['company_info'] != null) {
            final company = data['company_info'] as Map<String, dynamic>;
            _nameController.text = company['name'] ?? "";
            _addressController.text = company['adresse'] ?? "";
            _emailController.text = company['email'] ?? "";
            _telController.text = company['tel'] ?? "";
            _rccmController.text = company['rccm'] ?? "";
            _nifController.text = company['n_impot'] ?? "";
            _idNatController.text = company['id_nat'] ?? "";
          }

          if (data['taux_expertise'] != null) {
            Map<String, dynamic> expertise = data['taux_expertise'];
            expertise.forEach((niveau, taux) {
              bailleurControllers[niveau] = TextEditingController(text: taux['bailleur'].toString());
              locataireControllers[niveau] = TextEditingController(text: taux['locataire'].toString());
            });
          }

          if (data['payment_accounts'] != null) {
            Map<String, dynamic> accounts = data['payment_accounts'];
            accounts.forEach((key, val) {
              paymentNumControllers[key] = TextEditingController(text: val['number'] ?? "");
              paymentNameControllers[key] = TextEditingController(text: val['name'] ?? "");
            });
          }

          if (data['upsell_services'] != null) {
            List<dynamic> services = data['upsell_services'];
            upsellServiceControllers = services.map((s) {
              return {
                'id': s['id'] ?? '',
                'nom': TextEditingController(text: s['nom'] ?? ''),
                'prix': TextEditingController(text: s['prix']?.toString() ?? '0'),
                'description': TextEditingController(text: s['description'] ?? ''),
                'is_percentage': s['is_percentage'] ?? false,
              };
            }).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur de chargement: $e");
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> updatedExpertise = {};
      bailleurControllers.forEach((niveau, controller) {
        updatedExpertise[niveau] = {
          "bailleur": double.tryParse(controller.text) ?? 15.0,
          "locataire": double.tryParse(locataireControllers[niveau]?.text ?? "10.0") ?? 10.0,
        };
      });

      Map<String, dynamic> updatedAccounts = {};
      paymentNumControllers.forEach((key, controller) {
        updatedAccounts[key] = {
          "number": controller.text.trim(),
          "name": paymentNameControllers[key]?.text.trim() ?? "",
        };
      });

      List<Map<String, dynamic>> updatedUpsell = upsellServiceControllers.map((s) {
        return {
          'id': s['id'],
          'nom': (s['nom'] as TextEditingController).text.trim(),
          'prix': double.tryParse((s['prix'] as TextEditingController).text) ?? 0.0,
          'description': (s['description'] as TextEditingController).text.trim(),
          'is_percentage': s['is_percentage'],
        };
      }).toList();

      await _firestore.collection('settings').doc('app_config').set({
        'taux_usd_cdf': double.tryParse(_tauxUsdController.text) ?? 2500.0,
        'refund_service_fee': double.tryParse(_refundFeeController.text) ?? 5.0,
        
        'welcome_bonus': {
          'is_active': _isWelcomeBonusActive,
          'amount': double.tryParse(_welcomeAmountController.text) ?? 5.0,
          'duration_days': int.tryParse(_welcomeDurationController.text) ?? 30,
        },

        'referral_config': {
          'is_active': _isReferralActive,
          'referrer_reward': double.tryParse(_referrerRewardController.text) ?? 5.0,
          'referee_reward': double.tryParse(_refereeRewardController.text) ?? 2.0,
        },

        // ✅ SAUVEGARDE CONFIGURATION FIDÉLITÉ
        'loyalty_config': {
          'is_active': _isLoyaltyActive,
          'locataire_cashback_percent': double.tryParse(_locataireCashbackController.text) ?? 5.0,
          'bailleur_discount_percent': double.tryParse(_bailleurDiscountController.text) ?? 10.0,
        },

        'taux_expertise': updatedExpertise,
        'payment_accounts': updatedAccounts,
        'upsell_services': updatedUpsell,
        'company_info': {
          'name': _nameController.text.trim(),
          'adresse': _addressController.text.trim(),
          'email': _emailController.text.trim(),
          'tel': _telController.text.trim(),
          'rccm': _rccmController.text.trim(),
          'n_impot': _nifController.text.trim(),
          'id_nat': _idNatController.text.trim(),
        },
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Configuration enregistrée !"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Erreur: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 9, // Mis à jour de 8 à 9
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Paramètres Admin - EasyLocation"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.business), text: "Système"),
              Tab(icon: Icon(Icons.card_giftcard), text: "Marketing & Bonus"),
              Tab(icon: Icon(Icons.account_balance_wallet), text: "Paiements"),
              Tab(icon: Icon(Icons.show_chart), text: "Taux & Frais"),
              Tab(icon: Icon(Icons.assignment), text: "Expertise"),
              Tab(icon: Icon(Icons.add_shopping_cart), text: "Services Upsell"),
              Tab(icon: Icon(Icons.map), text: "Zones Géo"),
              Tab(icon: Icon(Icons.category), text: "Catégories Biens"),
              Tab(icon: Icon(Icons.wallet_travel), text: "Wallet"), // Nouvel onglet
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    _buildSystemTab(),
                    _buildMarketingTab(),
                    _buildPaymentTab(),
                    _buildRateTab(),
                    _buildExpertiseTab(),
                    UpsellTabWidget(
                      services: upsellServiceControllers,
                      onAddService: () {
                        setState(() {
                          upsellServiceControllers.add({
                            'id': 'SERVICE_${DateTime.now().millisecondsSinceEpoch}',
                            'nom': TextEditingController(),
                            'prix': TextEditingController(),
                            'description': TextEditingController(),
                            'is_percentage': false,
                          });
                        });
                      },
                      onRemoveService: (index) {
                        setState(() => upsellServiceControllers.removeAt(index));
                      },
                      onTogglePercentage: (index, value) {
                        setState(() => upsellServiceControllers[index]['is_percentage'] = value);
                      },
                    ),
                    const LocationEditorWidget(),
                    const CategoryEditorWidget(),
                    const WalletLimitSettingsWidget(), // Widget ajouté ici
                  ],
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  // ... [Le reste des méthodes reste identique] ...

  Widget _buildMarketingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SECTION 1 : BONUS DE BIENVENUE ---
          const Text("🎁 Bonus de Bienvenue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Ces crédits sont offerts automatiquement à chaque nouvel utilisateur inscrit.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Activer le bonus de bienvenue"),
                    subtitle: Text(_isWelcomeBonusActive ? "Le bonus est actuellement DISTRIBUÉ" : "Le bonus est actuellement DÉSACTIVÉ"),
                    value: _isWelcomeBonusActive,
                    onChanged: (val) => setState(() => _isWelcomeBonusActive = val),
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 20, runSpacing: 20,
                    children: [
                      _buildField(_welcomeAmountController, "Montant Offert (\$)", Icons.monetization_on, 300, isNumeric: true),
                      _buildField(_welcomeDurationController, "Durée de validité (Jours)", Icons.timer, 300, isNumeric: true),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // ✅ SECTION 2 : PARRAINAGE (WIDGET DÉPORTÉ)
          ReferralSettingsWidget(
            isActive: _isReferralActive,
            referrerController: _referrerRewardController,
            refereeController: _refereeRewardController,
            onToggle: (val) => setState(() => _isReferralActive = val),
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // ✅ SECTION 3 : FIDÉLITÉ / EASYCREDIT (WIDGET DÉPORTÉ)
          LoyaltySettingsWidget(
            isActive: _isLoyaltyActive,
            locataireController: _locataireCashbackController,
            bailleurController: _bailleurDiscountController,
            onToggle: (val) => setState(() => _isLoyaltyActive = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 20, runSpacing: 20,
        children: [
          _buildField(_nameController, "Nom de l'Entreprise", Icons.business, 400),
          _buildField(_addressController, "Adresse Physique", Icons.location_on, 400),
          _buildField(_emailController, "Email contact", Icons.email, 280),
          _buildField(_telController, "Téléphone", Icons.phone, 280),
          _buildField(_rccmController, "N° RCCM", Icons.app_registration, 190),
          _buildField(_nifController, "N° Impôt (NIF)", Icons.description, 190),
          _buildField(_idNatController, "ID National", Icons.fingerprint, 190),
        ],
      ),
    );
  }

  Widget _buildPaymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 20, runSpacing: 20,
        children: paymentNumControllers.keys.map((network) {
          return Container(
            width: 350, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(network.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const Divider(),
                _buildField(paymentNumControllers[network]!, "Numéro", Icons.phone_android, 320),
                const SizedBox(height: 10),
                _buildField(paymentNameControllers[network]!, "Nom titulaire", Icons.person, 320),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRateTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(
        spacing: 20, runSpacing: 20,
        children: [
          _buildField(_tauxUsdController, "Taux de change (1 USD = ? CDF)", Icons.currency_exchange, 350, isNumeric: true),
          _buildField(_refundFeeController, "Frais de Service (Retrait \$)", Icons.payments, 350, isNumeric: true),
        ],
      ),
    );
  }

  Widget _buildExpertiseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Colors.blueGrey),
            children: [
              Padding(padding: EdgeInsets.all(12), child: Text("NIVEAU", style: TextStyle(color: Colors.white))),
              Padding(padding: EdgeInsets.all(12), child: Text("BAILLEUR (%)", style: TextStyle(color: Colors.white))),
              Padding(padding: EdgeInsets.all(12), child: Text("LOCATAIRE (%)", style: TextStyle(color: Colors.white))),
            ],
          ),
          ...bailleurControllers.keys.map((niveau) {
            return TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(12), child: Text(niveau.toUpperCase())),
                _buildTableCellField(bailleurControllers[niveau]!),
                _buildTableCellField(locataireControllers[niveau]!),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, double width, {bool isNumeric = false}) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _buildTableCellField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity, height: 55,
        child: ElevatedButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save_alt),
          label: const Text("APPLIQUER LES MODIFICATIONS"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _rccmController.dispose();
    _nifController.dispose();
    _idNatController.dispose();
    _tauxUsdController.dispose();
    _refundFeeController.dispose();
    _welcomeAmountController.dispose();
    _welcomeDurationController.dispose();
    _referrerRewardController.dispose();
    _refereeRewardController.dispose();
    _locataireCashbackController.dispose();
    _bailleurDiscountController.dispose();
    bailleurControllers.forEach((_, c) => c.dispose());
    locataireControllers.forEach((_, c) => c.dispose());
    paymentNumControllers.forEach((_, c) => c.dispose());
    paymentNameControllers.forEach((_, c) => c.dispose());
    for (var s in upsellServiceControllers) {
      (s['nom'] as TextEditingController).dispose();
      (s['prix'] as TextEditingController).dispose();
      (s['description'] as TextEditingController).dispose();
    }
    super.dispose();
  }
}