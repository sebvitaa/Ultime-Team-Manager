# Personalización: ícono, splash y música

Tutorial específico para **Ultime Team Manager** (`contador_app`). Cubre tres cosas:

1. [Cambiar el ícono de la app](#1-cambiar-el-ícono-de-la-app)
2. [Cambiar la pantalla de carga inicial (splash) en móviles](#2-cambiar-el-splash-pantalla-de-carga-inicial)
3. [Música: 3 canciones en bucle en el lobby + 2 superpuestas en el partido](#3-música)

> Todos los comandos se corren desde la raíz del proyecto:
> `/Users/seba/Documents/Visual Studio/Proyectos Académicos/Ultime-Team-Manager`

---

## 1. Cambiar el ícono de la app

El ícono vive en decenas de tamaños (Android `mipmap-*`, iOS `AppIcon.appiconset`). En vez de reemplazarlos a mano, usamos el paquete **`flutter_launcher_icons`**, que los genera todos desde **una sola imagen**.

### 1.1 Imagen fuente (ya está lista)

El logo ya está exportado como imagen a partir de `lib/presentation/widgets/crest_logo.dart` y vive en `assets/icon/`:

| Archivo | Qué es | Uso en la config |
|---|---|---|
| `assets/icon/icon.png` | 1024×1024, escudo sobre fondo oscuro **opaco** | `image_path` (ícono principal Android + iOS) |
| `assets/icon/icon_foreground.png` | 1024×1024, escudo **transparente** con margen | `adaptive_icon_foreground` (Android adaptativo) |
| `assets/icon/crest_only.png` | solo el escudo sobre transparente | uso libre (splash, marketing) |

No hace falta preparar nada más: pasa directo al [paso 1.2](#12-agrega-el-paquete-dev-dependency).

> **¿Quieres regenerar el logo?** (por ejemplo con otro tamaño o color de fondo) usa el script `scripts/gen_icon.py` — reproduce el `CrestLogo` con Pillow. Ajusta `crest_frac` (tamaño del escudo, actual `0.66`) o `BG` (color de fondo) y corre `python3 scripts/gen_icon.py`.
>
> Requisitos del formato, por si cambias la imagen a mano: **PNG cuadrado ≥ 1024×1024** y el `icon.png` **sin transparencia** (iOS rechaza el canal alfa en el ícono principal).

### 1.2 Agrega el paquete (dev dependency)

```bash
flutter pub add dev:flutter_launcher_icons
```

### 1.3 Configúralo en `pubspec.yaml`

Agrega este bloque **al final** del archivo, alineado a la izquierda (mismo nivel que `flutter:`):

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"

  # --- Ícono adaptativo de Android (recomendado) ---
  # foreground = tu logo con márgenes; background = color liso o imagen.
  adaptive_icon_background: "#0B0F0D"      # color de fondo (tu verde/carbón)
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"

  # Opcional: quitar el alfa para iOS automáticamente
  remove_alpha_ios: true
```

> **Ícono adaptativo:** Android recorta el ícono en círculo/cuadrado/gota según el launcher. El `foreground` debe ser el logo con **~25% de margen** alrededor para que no se corte. Si no quieres lidiar con esto todavía, borra las 3 líneas `adaptive_icon_*` y solo usa `image_path`.

### 1.4 Genera los íconos

```bash
dart run flutter_launcher_icons
```

Esto sobrescribe:
- `android/app/src/main/res/mipmap-*/ic_launcher.png` (y el adaptativo en `mipmap-anydpi-v26/`)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### 1.5 Reconstruye

```bash
flutter clean && flutter run
```

> El ícono viejo puede quedar cacheado en el emulador/dispositivo. Si lo sigues viendo, **desinstala la app** del dispositivo y vuelve a instalar.

### Alternativa manual (sin paquete)

Si prefieres no usar el paquete: reemplaza directamente cada `ic_launcher.png` en las carpetas `android/app/src/main/res/mipmap-hdpi`, `-mdpi`, `-xhdpi`, `-xxhdpi`, `-xxxhdpi` (48, 48, 96, 144, 192 px respectivamente) y el set de iOS. Es tedioso y propenso a errores — usa el paquete.

---

## 2. Cambiar el splash (pantalla de carga inicial)

El splash es lo que se ve **mientras el sistema operativo carga Flutter** (antes de tu primer `Widget`). Se configura con el paquete **`flutter_native_splash`**.

> Ojo: esto es distinto de tu pantalla de login con la cancha animada. El splash nativo aparece **antes**, durante el arranque frío.

### 2.1 Agrega el paquete

```bash
flutter pub add dev:flutter_native_splash
```

### 2.2 Imagen del splash (ya la tienes)

Tu imagen de carga ya está en el proyecto: `assets/images/pantallaCarga.png` — es un **fondo vertical a pantalla completa** (1440×2560, aspecto 9:16).

Dos cosas que hay que saber por el formato:

- `flutter_native_splash` **solo acepta PNG** (no JPG). Por eso se convirtió el `pantallaCarga.jpg` original a `.png`. Si vuelves a cambiar la imagen, guárdala como PNG.
- Como es un fondo que llena la pantalla (no un logo centrado), se usa la clave **`background_image`** (que estira para llenar), **no** `image` (que centra).

> **Peso:** el JPG original era 2700×4800 (~16 MB en PNG). Se redimensionó a 1440×2560 (~6 MB) porque más resolución que la pantalla no aporta nada y solo infla el APK. Si quieres regenerarla con otro tamaño, ajusta el `resize(...)` del snippet que la creó.

### 2.3 Crea `flutter_native_splash.yaml` en la raíz

```yaml
flutter_native_splash:
  color: "#0B0F0D"                                 # se ve en los bordes si sobra
  background_image: assets/images/pantallaCarga.png # fondo a pantalla completa

  # Android 12+ NO soporta imagen a pantalla completa en el splash del sistema:
  # solo dibuja un ícono centrado sobre un color. Ahí usamos el escudo.
  android_12:
    color: "#0B0F0D"
    image: assets/icon/icon_foreground.png

  # Plataformas a generar.
  android: true
  ios: true

  # Opcional: modo oscuro
  # color_dark: "#000000"
  # background_image_dark: assets/images/pantallaCarga.png
```

> **Importante (Android 12+):** desde Android 12 el splash del sistema es un ícono centrado sobre un color liso — **no** admite fondo a pantalla completa (es limitación del SO, no del paquete). Por eso tu `pantallaCarga.png` se verá completa en **iOS y Android ≤ 11**, mientras que en **Android 12+** verás el escudo centrado sobre `#0B0F0D`. Si quieres la imagen completa también ahí, hay que mostrarla como primer `Widget` de Flutter (una pantalla propia), no vía splash nativo — avísame y lo montamos.

### 2.4 Genera el splash

```bash
dart run flutter_native_splash:create
```

Esto modifica archivos nativos:
- Android: `android/app/src/main/res/drawable*/`, `values/styles.xml`, `values-night/`
- iOS: `ios/Runner/Assets.xcassets/LaunchImage.imageset/`, `Base.lproj/LaunchScreen.storyboard`

### 2.5 Reconstruye

```bash
flutter clean && flutter run
```

### Notas importantes

- **Android 12+** ignora imágenes grandes: solo muestra el ícono centrado sobre el color. Por eso hay una sección `android_12` aparte. Mantén el logo simple.
- Para **quitar** el splash y volver al blanco por defecto:
  ```bash
  dart run flutter_native_splash:remove
  ```
- Si quieres que el splash se mantenga hasta que termine tu init (cargar `.env`, Supabase), se puede usar `flutter_native_splash.preserve()` + `remove()` en `main.dart`. Avísame si lo quieres y lo agregamos.

---

## 3. Música

### Estado actual

Hoy **solo el login** tiene música: el widget `IntroMusic` (`lib/presentation/widgets/intro_music.dart`) reproduce `intro.mp3` en bucle. El lobby (`HomeScreen`) y el partido (`MatchScreen`) **no tienen música**.

Ya tienes los archivos listos en `assets/sounds/music/`:

| Archivo | Uso |
|---|---|
| `intro.mp3` | Login (ya funciona) |
| `lobby1.mp3`, `lobby2.mp3`, `lobby3.mp3` | Lobby: suenan **en secuencia**, una tras otra, en bucle |
| `match.mp3` + `peopleingame.mp3` | Partido: suenan **superpuestas** (mezcladas) al mismo tiempo |

Lo que vamos a construir:

- **Lobby** → una *playlist* de 3 pistas que se encadenan (`lobby1 → lobby2 → lobby3 → lobby1 …`).
- **Partido** → dos reproductores simultáneos mezclados (música + ambiente de gente).
- Un **servicio central** (`MusicService`) que evita que dos músicas suenen a la vez al cambiar de pantalla.

### 3.0 Registra los assets en `pubspec.yaml`

Ahora mismo solo `intro.mp3` está registrado. Cambia el bloque `assets:` para incluir **toda la carpeta**:

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
    - assets/data/squad.json
    - assets/sounds/music/
    - assets/sounds/sound_effects/
```

> El `/` final incluye todos los archivos de esa carpeta (no recursivo). Corre `flutter pub get` después.

### 3.1 El servicio central de música

Este objeto es el **dueño único** de todos los reproductores. Cuando entras al partido, apaga el lobby; cuando sales, lo reanuda. Así nunca se superponen lobby y partido.

Crea `lib/data/services/music_service.dart`:

```dart
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
```

### 3.2 Lobby: 3 canciones en bucle

Crea un widget invisible que enciende la playlist mientras el lobby esté en pantalla. Créalo en `lib/presentation/widgets/lobby_music.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:contador_app/data/services/music_service.dart';

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
```

**Dónde ponerlo:** en `lib/presentation/screens/home/home_screen.dart`, el `body` es un `SafeArea`. Envuélvelo en un `Stack` para colgar el widget de música. Cambia:

```dart
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Padding(
          // ... todo tu contenido actual ...
        ),
      ),
    );
```

por:

```dart
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              // ... todo tu contenido actual, SIN cambios ...
            ),
          ),
          const LobbyMusic(), // 🎵 playlist del lobby
        ],
      ),
    );
```

Y agrega el import arriba:

```dart
import 'package:contador_app/presentation/widgets/lobby_music.dart';
```

### 3.3 Partido: 2 canciones superpuestas

Widget análogo para el partido. Créalo en `lib/presentation/widgets/match_music.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:contador_app/data/services/music_service.dart';

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
```

**Dónde ponerlo:** en `lib/presentation/screens/match/match_screen.dart`, el `body` ya es un `Stack`. Solo agrega el widget como un hijo más (al final de la lista de `children` del `Stack`):

```dart
        body: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ArenaPainter())),
            SafeArea(
              // ... contenido actual ...
            ),
            const MatchMusic(), // 🎵 música + ambiente superpuestos
          ],
        ),
```

Y el import:

```dart
import 'package:contador_app/presentation/widgets/match_music.dart';
```

### 3.4 ¿Por qué no se superponen lobby y partido?

Porque `MusicService` es un **singleton** (una sola instancia) dueño de todos los reproductores:

- Al entrar al partido → `playMatch()` llama a `stopLobby()` **antes** de sonar.
- Al salir del partido → `MatchMusic.dispose()` llama a `playLobby()`, que llama a `_stopMatch()` primero.

El `HomeScreen` sigue montado "debajo" del partido, pero su `LobbyMusic` no se vuelve a inicializar; el control lo tiene el servicio. Resultado: **siempre suena un solo contexto**.

> El login usa su propio `IntroMusic` (otro `AudioPlayer`). Como el login se desmonta al entrar al home, no se pisa con el lobby. Si algún día quieres unificarlo, se puede mover `intro.mp3` también dentro de `MusicService` con un `playIntro()`.

### 3.5 Ajustar volúmenes de la mezcla del partido

En `music_service.dart`, dentro de `playMatch()`:

```dart
await _matchMain.setVolume(muted ? 0 : 0.7);   // pista principal (más alta)
await _matchCrowd.setVolume(muted ? 0 : 0.45); // ambiente de gente (de fondo)
```

Sube/baja esos números (0.0 – 1.0) hasta que la mezcla te guste. La idea es que `peopleingame.mp3` (la gente) quede **por debajo** de `match.mp3`.

### 3.6 (Opcional) Botón de silencio global

Tu `IntroMusic` ya tiene botón de mute propio. Si quieres uno para lobby/partido, llama a `MusicService.instance.toggleMute()` desde un `IconButton` y refleja `MusicService.instance.muted` en el ícono.

---

## Chuleta de comandos

```bash
# Íconos
flutter pub add dev:flutter_launcher_icons
dart run flutter_launcher_icons

# Splash
flutter pub add dev:flutter_native_splash
dart run flutter_native_splash:create
dart run flutter_native_splash:remove   # para revertir

# Después de tocar assets o dependencias
flutter pub get
flutter clean && flutter run
```

## Checklist de verificación

- [ ] `assets/sounds/music/` registrado en `pubspec.yaml` y `flutter pub get` corrido.
- [ ] Ícono nuevo se ve tras **desinstalar** la app y reinstalar.
- [ ] Splash nuevo aparece en arranque frío (cierra la app del todo y ábrela).
- [ ] En el lobby suenan `lobby1 → lobby2 → lobby3` y vuelve a empezar.
- [ ] En el partido se oyen las **dos** pistas a la vez (música + gente).
- [ ] Al salir del partido vuelve la música del lobby, sin quedar dos sonando.
```
