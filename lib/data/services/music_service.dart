import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Dueño único de la música del juego. Un solo "contexto" suena a la vez:
/// - Lobby: playlist de 3 pistas encadenadas en bucle.
/// - Partido: 2 pistas superpuestas (mezcladas) en bucle.
class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  // --- Lobby: un solo player que va avanzando de pista ---
  final AudioPlayer _lobby = AudioPlayer();
  static const List<String> _lobbyPlaylist = [
    'sounds/music/lobby1.mp3',
    'sounds/music/lobby2.mp3',
    'sounds/music/lobby3.mp3',
  ];
  int _lobbyIndex = 0;
  bool _lobbyRunning = false;

  // --- Partido: dos players simultáneos (superposición) ---
  final AudioPlayer _matchMain = AudioPlayer();   // match.mp3
  final AudioPlayer _matchCrowd = AudioPlayer();  // peopleingame.mp3
  bool _matchRunning = false;

  bool muted = false;

  // ----------------- LOBBY -----------------

  Future<void> playLobby() async {
    await _stopMatch();
    if (_lobbyRunning) return; // ya está sonando
    _lobbyRunning = true;
    // Al terminar una pista, avanza a la siguiente (y vuelve al inicio).
    _lobby.onPlayerComplete.listen((_) {
      if (!_lobbyRunning) return;
      _lobbyIndex = (_lobbyIndex + 1) % _lobbyPlaylist.length;
      _playCurrentLobbyTrack();
    });
    await _playCurrentLobbyTrack();
  }

  Future<void> _playCurrentLobbyTrack() async {
    try {
      // ReleaseMode.stop => dispara onPlayerComplete al terminar (no repite sola).
      await _lobby.setReleaseMode(ReleaseMode.stop);
      await _lobby.setVolume(muted ? 0 : 0.6);
      await _lobby.play(AssetSource(_lobbyPlaylist[_lobbyIndex]));
    } catch (e) {
      debugPrint('MusicService lobby error: $e');
    }
  }

  Future<void> stopLobby() async {
    _lobbyRunning = false;
    _lobbyIndex = 0;
    try {
      await _lobby.stop();
    } catch (_) {}
  }

  // ----------------- PARTIDO -----------------

  Future<void> playMatch() async {
    await stopLobby();
    if (_matchRunning) return;
    _matchRunning = true;
    try {
      // Los dos en bucle, sonando a la vez (superpuestos).
      await _matchMain.setReleaseMode(ReleaseMode.loop);
      await _matchCrowd.setReleaseMode(ReleaseMode.loop);
      // Volúmenes distintos: la música principal manda, la gente va de fondo.
      await _matchMain.setVolume(muted ? 0 : 0.7);
      await _matchCrowd.setVolume(muted ? 0 : 0.45);
      await _matchMain.play(AssetSource('sounds/music/match.mp3'));
      await _matchCrowd.play(AssetSource('sounds/music/peopleingame.mp3'));
    } catch (e) {
      debugPrint('MusicService match error: $e');
    }
  }

  Future<void> _stopMatch() async {
    _matchRunning = false;
    try {
      await _matchMain.stop();
      await _matchCrowd.stop();
    } catch (_) {}
  }

  // ----------------- SILENCIAR -----------------

  Future<void> toggleMute() async {
    muted = !muted;
    final v = muted ? 0.0 : 1.0;
    await _lobby.setVolume(0.6 * v);
    await _matchMain.setVolume(0.7 * v);
    await _matchCrowd.setVolume(0.45 * v);
  }
}