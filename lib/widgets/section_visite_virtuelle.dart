// lib/widgets/section_visite_virtuelle.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:easylocation_mvp/models/property_model.dart';
import 'package:easylocation_mvp/services/config_service.dart';

class SectionVisiteVirtuelle extends StatelessWidget {
  final Property property;

  const SectionVisiteVirtuelle({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final videoUrl = property.videoUrl;

    // Si aucune vidéo n'est enregistrée, on ne s'affiche pas
    if (videoUrl == null || videoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => _ouvrirLecteurVideo(context, videoUrl),
        icon: const Icon(Icons.play_circle_fill_rounded, size: 28, color: Colors.white),
        label: const Text(
          "🎬 Voir la visite virtuelle (max 2 min)",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
      ),
    );
  }

  void _ouvrirLecteurVideo(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => _DialogLecteurVideo(videoUrl: url),
    );
  }
}

class _DialogLecteurVideo extends StatefulWidget {
  final String videoUrl;

  const _DialogLecteurVideo({required this.videoUrl});

  @override
  State<_DialogLecteurVideo> createState() => _DialogLecteurVideoState();
}

class _DialogLecteurVideoState extends State<_DialogLecteurVideo> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Récupération des infos entreprise pour le filigrane
    final config = Provider.of<ConfigService>(context);
    final String companyName = config.companyInfo['name'] ?? "EasyLocation";
    final String companyTel = config.companyInfo['tel'] ?? "";

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _isInitialized ? _controller.value.aspectRatio : 16 / 9,
            child: _hasError
                ? const Center(
                    child: Text(
                      "Erreur de lecture de la vidéo",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : _isInitialized
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoPlayer(_controller),
                          _buildWatermark(companyName, companyTel), // 👈 Filigrane superposé sur la vidéo
                        ],
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_isInitialized)
            Positioned(
              bottom: 20,
              child: FloatingActionButton(
                backgroundColor: Colors.white.withOpacity(0.7),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget du filigrane
  Widget _buildWatermark(String name, String phone) {
    return Center(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.18, // Légère opacité transparente
          child: RotationTransition(
            turns: const AlwaysStoppedAnimation(-35 / 360), // Inclinaison à -35°
            child: Text(
              "$name\n$phone",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(blurRadius: 3.0, color: Colors.black54, offset: Offset(1, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}