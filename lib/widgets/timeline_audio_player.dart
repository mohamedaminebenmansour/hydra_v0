import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/report_local_service.dart';

/// Self-contained audio player for a single timeline event voice note.
///
/// Each instance owns its own [AudioPlayer], so multiple timeline bubbles can
/// play back simultaneously without competing for a shared player state.
class TimelineAudioPlayer extends StatefulWidget {
  const TimelineAudioPlayer({
    super.key,
    required this.voicePath,
    this.voiceUrl = '',
  });

  final String voicePath;
  final String voiceUrl;

  @override
  State<TimelineAudioPlayer> createState() => _TimelineAudioPlayerState();
}

class _TimelineAudioPlayerState extends State<TimelineAudioPlayer> {
  late final AudioPlayer _player;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _attach();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _attach() {
    _posSub = _player.onPositionChanged.listen((d) {
      if (!mounted) return;
      setState(() => _position = d);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _position = _duration;
        }
      });
    });
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    final media = ReportLocalService.resolveMedia(
      widget.voicePath,
      widget.voiceUrl,
    );
    if (media.origin == MediaOrigin.none) return;
    try {
      if (_duration > Duration.zero && _position >= _duration) {
        await _player.seek(Duration.zero);
        _position = Duration.zero;
      }
      await _player.play(
        media.origin == MediaOrigin.localFile
            ? DeviceFileSource(media.location)
            : UrlSource(media.location),
      );
    } catch (e) {
      debugPrint('TimelineAudio: play failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration > Duration.zero
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _toggle,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        // The button's child is a plain Row: the transport icon, the progress
        // bar that fills the space and the label. (An `Expanded` inside a
        // `FilledButton.icon` label is invalid — its label sits in a `Flexible`,
        // not a Flex — and threw a ParentData error whenever this player was
        // rendered.)
        child: Row(
          children: [
            Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _playing ? 'PAUSE' : 'PLAY VOICE',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
