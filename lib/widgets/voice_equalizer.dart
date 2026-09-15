import 'package:flutter/material.dart';

/// Animated 5-bar equalizer that moves only while audio is playing and
/// settles to a flat row when idle.
class VoiceEqualizer extends StatefulWidget {
  const VoiceEqualizer({super.key, required this.playing});

  final bool playing;

  @override
  State<VoiceEqualizer> createState() => _VoiceEqualizerState();
}

class _VoiceEqualizerState extends State<VoiceEqualizer>
    with SingleTickerProviderStateMixin {
  static const int _barCount = 5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant VoiceEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          height: 48,
          child: Align(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_barCount, (i) {
                final phase = (_controller.value + i * 0.19) % 1.0;
                // Triangle-wave in [0,1]: peaks in the middle of the cycle.
                final wave = 1.0 - (phase - 0.5).abs() * 2;
                final factor = widget.playing ? 0.30 + 0.70 * wave : 0.25;
                return Container(
                  width: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 44 * factor,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(
                      alpha: widget.playing ? 1.0 : 0.4,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
