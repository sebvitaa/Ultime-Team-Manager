import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Reproduce en bucle la música de intro mientras esta pantalla esté montada, y
/// muestra un botón (arriba a la derecha) para silenciar/activar. La pista vive en
/// `assets/sounds/music/intro.mp3` (registrada en pubspec).
class IntroMusic extends StatefulWidget {
  final String asset;
  final double volume;

  const IntroMusic({
    super.key,
    this.asset = 'sounds/music/intro.mp3',
    this.volume = 0.6,
  });

  @override
  State<IntroMusic> createState() => _IntroMusicState();
}

class _IntroMusicState extends State<IntroMusic> {
  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;
  bool _ready = false; // true cuando play() arrancó al menos una vez

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged
        .listen((s) => debugPrint('IntroMusic estado: $s'));
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop); // reinicia al terminar
      await _player.setVolume(widget.volume);
      await _player.play(AssetSource(widget.asset));
      _ready = true;
      debugPrint('IntroMusic: play() OK ("${widget.asset}")');
    } catch (e) {
      debugPrint('IntroMusic: error al reproducir "${widget.asset}": $e');
    }
  }

  Future<void> _toggle() async {
    setState(() => _muted = !_muted);
    try {
      if (_muted) {
        await _player.pause();
      } else if (_ready) {
        await _player.resume();
      } else {
        await _init(); // reintenta si el primer play no arrancó
      }
    } catch (e) {
      debugPrint('IntroMusic toggle error: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose(); // detiene y libera al salir del login
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.black.withValues(alpha: 0.35),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: _muted ? 'Activar música' : 'Silenciar música',
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: _toggle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
