import 'package:flutter/material.dart';
import 'package:ultimate_team_manager/data/services/music_service.dart';

/// Enciende la playlist del lobby mientras esta pantalla esté montada.
class LobbyMusic extends StatefulWidget {
  const LobbyMusic({super.key});

  @override
  State<LobbyMusic> createState() => _LobbyMusicState();
}

class _LobbyMusicState extends State<LobbyMusic> {
  @override
  void initState() {
    super.initState();
    MusicService.instance.playLobby();
  }

  @override
  void dispose() {
    // Al salir del lobby (logout), corta la música del lobby.
    MusicService.instance.stopLobby();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}