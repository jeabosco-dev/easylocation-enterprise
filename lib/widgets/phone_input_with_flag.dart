// lib/widgets/phone_input_with_flag.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fonction pour masquer un numéro (ex: 0972123456 -> 972-XXX-XXX)
String masquerNumeroTelephone(String numero) {
  final numeroNettoye = numero.replaceAll(RegExp(r'[\s+\-]'), '');

  String numeroLocal = numeroNettoye;
  if (numeroLocal.startsWith('243')) {
    numeroLocal = numeroLocal.substring(3);
  } else if (numeroLocal.startsWith('0')) {
    numeroLocal = numeroLocal.substring(1);
  }

  if (numeroLocal.length < 9) {
    return numero;
  }

  final debut = numeroLocal.substring(0, 3);
  return '$debut-XXX-XXX';
}

class PhoneInputWithFlag extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final bool isMasked;
  final VoidCallback? onTapUnmask;

  const PhoneInputWithFlag({
    super.key,
    required this.controller,
    this.focusNode,
    this.validator,
    this.isMasked = false,
    this.onTapUnmask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormField(
          validator: (value) {
            if (validator != null) {
              return validator!(controller.text);
            }
            return null;
          },
          builder: (FormFieldState field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: field.hasError
                          ? theme.colorScheme.error
                          : Colors.grey.shade400,
                      width: field.hasError ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Drapeau RDC
                      const Text(
                        '🇨🇩',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),

                      // Indicatif +243
                      Text(
                        '+243',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Séparateur vertical
                      Container(
                        height: 28,
                        width: 1,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),

                      // Champ Saisie ou Numéro Masqué
                      Expanded(
                        child: isMasked
                            ? InkWell(
                                onTap: onTapUnmask,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        masquerNumeroTelephone(controller.text),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.1,
                                          color: theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType: TextInputType.phone,
                                onChanged: (val) => field.didChange(val),
                                decoration: const InputDecoration(
                                  hintText: '972 361 265',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(9),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // Message d'erreur
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 6),
                    child: Text(
                      field.errorText ?? '',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}