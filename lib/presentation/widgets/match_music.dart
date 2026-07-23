import 'package:flutter/material.dart';
import 'package:ultimate_team_manager/data/services/music_service.dart';

/// Enciende las 2 pistas superpuestas del partido mientras dure la pantalla.
/// Al terminar el partido (dispose), reanuda la música del lobby.
class MatchMusic extends StatefulWidget {
  const MatchMusic({super.key});

  @override
  State<MatchMusic> createState() => _MatchMusicState();
}

class _MatchMusicState extends State<MatchMusic> {
  @override
  void initState() {
    super.initState();
    MusicService.instance.playMatch();
  }

  @override
  void dispose() {
    // Volvemos al lobby -> reanuda su playlist.
    MusicService.instance.playLobby();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}