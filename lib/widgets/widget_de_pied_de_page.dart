import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';

class WidgetDePiedDePage extends StatelessWidget {
  const WidgetDePiedDePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigService>(context);
    final company = config.companyInfo;
    final theme = Theme.of(context);

    // Extraction des valeurs dynamiques
    final String nomEntreprise = company['name'] ?? 'EasyLocation Enterprise';
    final String nif = company['n_impot'] ?? 'A2301893J';
    final String rccm = company['rccm'] ?? 'CD/BKV/RCCM/22-B-03012';
    final String idNat = company['id_nat'] ?? '22-F4300-N24678A';
    final String tel = company['tel'] ?? '+243 980 361 265';
    final String email = company['email'] ?? 'contact@easylocationrdc.com';
    
    // --- LOGIQUE DE LONGÉVITÉ ---
    const int startYear = 2025; 
    final int currentYear = DateTime.now().year;
    
    final String copyrightText = currentYear > startYear 
        ? '$startYear - $currentYear' 
        : '$startYear';

    return Container(
      // ✅ Padding vertical réduit à 12.0 pour aérer le bouton du dessus
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ Prend le minimum de place nécessaire
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LIGNE 1 : COPYRIGHT (Taille légèrement réduite)
          Text(
            '© $copyrightText $nomEntreprise. Tous droits réservés.',
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 11.0, 
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6.0), // ✅ Espace réduit

          // LIGNE 2 : INFOS LÉGALES (Taille réduite pour gagner de l'espace)
          Text(
            'N° Impôt : $nif | N° RCCM : $rccm | Id. Nat. : $idNat',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 9.0),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6.0),

          // LIGNE 3 : IDENTITÉ NATIONALE
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 0.5, color: Colors.white30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Text(
                  'RÉPUBLIQUE DÉMOCRATIQUE DU CONGO',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9), 
                    fontSize: 8.5, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(width: 10, height: 0.5, color: Colors.white30),
            ],
          ),
          const SizedBox(height: 12.0), // ✅ Espace réduit avant les contacts

          // LIGNE 4 : CONTACTS (ÉPURÉE)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20.0,
            runSpacing: 8.0,
            children: [
              _buildContactItem(Icons.phone_android_rounded, tel),
              _buildContactItem(Icons.email_outlined, email),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 13.0),
        const SizedBox(width: 6.0),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 11.0,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}