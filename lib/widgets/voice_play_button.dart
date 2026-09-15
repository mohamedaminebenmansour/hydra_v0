import 'package:flutter/material.dart';

/// The giant voice-note play/pause control on the Report screen: a full-width
/// blue bar with a 60px transport icon and a loud label, easy to hit one-handed.
class VoicePlayButton extends StatelessWidget {
  const VoicePlayButton({
    super.key,
    required this.playing,
    required this.onTap,
  });

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 96,
        width: double.infinity,
        child: Material(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    playing ? 'PAUSE' : 'PLAY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
