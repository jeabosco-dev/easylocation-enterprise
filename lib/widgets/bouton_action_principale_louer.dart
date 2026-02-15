import 'package:flutter/material.dart';

class BoutonActionPrincipaleLouer extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const BoutonActionPrincipaleLouer({
    super.key,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  State<BoutonActionPrincipaleLouer> createState() =>
      _BoutonActionPrincipaleLouerState();
}

class _BoutonActionPrincipaleLouerState
    extends State<BoutonActionPrincipaleLouer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Le bouton est considéré "actif" seulement si on a une fonction et qu'on ne charge pas
    final bool isEnabled = widget.onPressed != null && !widget.isLoading;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: isEnabled ? _scaleAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isEnabled
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.grey.shade400,
                        Colors.grey.shade500,
                      ],
                    ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(_glowAnimation.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                // On garde onPressed même si "visuellement désactivé" pour afficher le message d'erreur SnackBar
                onTap: widget.isLoading ? null : widget.onPressed,
                splashColor: isEnabled ? Colors.white24 : Colors.transparent,
                highlightColor: isEnabled ? Colors.white10 : Colors.transparent,
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_open_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            const Text(
                              "RÉSERVER CE LOGEMENT",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white, size: 16),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
