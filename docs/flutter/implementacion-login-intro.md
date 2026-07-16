# Implementación del login / pantalla de intro (Flutter)

Documento técnico de la pantalla de intro de **Ultime Team Manager**: un login estilo
EA SPORTS FC sobre una **cancha animada** con un balón que da pases y **rueda en 3D**.
Aquí se explica **qué hace cada archivo y la lógica** que emplea.

> Stack: Flutter · Dart · Riverpod · go_router · shared_preferences.
> Arquitectura por capas: `domain` (reglas), `data` (implementaciones),
> `presentation` (UI + estado), `config` (tema y navegación).

## Mapa de archivos

| Capa | Archivo | Rol |
|------|---------|-----|
| config | `config/theme/app_colors.dart` | Paleta (verde de cancha + carbón mate). |
| config | `config/router/app_router.dart` | Rutas y **guardia de sesión**. |
| domain | `domain/entities/app_user.dart` | Entidad del usuario. |
| domain | `domain/repositories/auth_repository.dart` | Contrato de autenticación. |
| data | `data/repositories/auth_repository_local.dart` | Login **offline** + sesión. |
| presentation | `presentation/providers/auth_provider.dart` | Estado con Riverpod. |
| presentation | `presentation/widgets/crest_logo.dart` | Escudo vectorial (CustomPaint). |
| presentation | `presentation/widgets/pitch_background.dart` | Cancha + balón 3D animados. |
| presentation | `presentation/screens/auth/login_screen.dart` | Tarjeta de login estilo EA. |
| presentation | `presentation/screens/home/home_screen.dart` | Destino tras entrar. |
| raíz | `main.dart` | Arranque (`ProviderScope` + `MaterialApp.router`). |

---

## `config/theme/app_colors.dart`
**Rol:** un único punto para los colores del proyecto, así el verde y el carbón son
consistentes en toda la UI.

**Lógica:** clase con constructor privado (`AppColors._()`) y solo constantes
`static const`. Define el acento **verde** (`#2FE27A`), el verde de la píldora del
botón, el **fondo casi negro**, el **carbón mate** de la tarjeta (color con alfa
`0xE6…` ≈ 90 % opaco) y los grises de texto. No hay lógica de ejecución: es
configuración.

---

## `domain/entities/app_user.dart`
**Rol:** representar al usuario autenticado dentro de la app, sin depender de Flutter
ni de cómo se guardan los datos.

**Lógica:** objeto **inmutable** (`final id`, `final email`, constructor `const`). No
contiene contraseñas: es el dato que viaja por la UI.

---

## `domain/repositories/auth_repository.dart`
**Rol:** el **contrato** de autenticación. La UI depende de esta abstracción, no de
una implementación concreta (hoy local, mañana Supabase).

**Lógica:**
- Clase `abstract` con tres operaciones: `currentUser()` (restaurar sesión),
  `signIn({email, password})` y `signOut()`.
- Define `AuthException`, un error de dominio para credenciales incorrectas, que
  permite distinguir un fallo esperado de un *bug*.

---

## `data/repositories/auth_repository_local.dart`
**Rol:** implementación **offline** del contrato, con sesión persistente.

**Lógica:**
- Implementa `AuthRepository`.
- Valida contra un **usuario de demo** (`demo@ultime.com` / `123456`).
- `signIn`: normaliza el correo, simula latencia de red (`Future.delayed`), y si las
  credenciales aciertan **guarda** `id` y `email` con `shared_preferences`.
- `currentUser`: reconstruye el `AppUser` desde lo guardado (o `null`).
- `signOut`: borra las claves.
- **Escalable a online:** para usar Supabase basta crear otra clase que implemente el
  mismo contrato y cambiar una línea en el provider (ver abajo); la UI no se entera.

---

## `presentation/providers/auth_provider.dart`
**Rol:** el estado de autenticación con **Riverpod**. Es el cerebro del login.

**Lógica:**
- `authRepositoryProvider`: expone la implementación concreta. **Único punto** a
  cambiar para pasar a online.
- `AuthStatus` (enum): `unknown` / `authenticated` / `unauthenticated`.
- `AuthState`: estado **inmutable** que observa la UI (status, user, `isSubmitting`,
  `errorMessage`) con un `copyWith`. El `errorMessage` se limpia en cada copia que no
  lo pase (es un error transitorio).
- `AuthController extends Notifier<AuthState>`:
  - `build()` lanza `_restoreSession()` al crearse (restaura sesión al arrancar).
  - `signIn()` enciende `isSubmitting`, llama al repositorio y actualiza el estado;
    devuelve `true`/`false` y captura `AuthException` para mostrar el mensaje.
  - `signOut()` limpia la sesión.

---

## `presentation/widgets/crest_logo.dart`
**Rol:** el **escudo/logo** de "Ultime Team Manager" dibujado vectorialmente, sin
emojis ni paquetes externos.

**Lógica:**
- `CrestLogo` es un `StatelessWidget` que envuelve un `CustomPaint`.
- `_CrestPainter` dibuja en un lienzo lógico de `100×112` y **escala** a la medida
  real (`sx`, `sy`), de modo que el escudo se ve nítido a cualquier tamaño.
- Composición: (1) el **shield** como `Path` (relleno oscuro + borde con degradado
  verde), (2) un **balón lineal** (círculo + 5 costuras + pentágono central), y
  (3) el monograma **"UTM"** con un `TextPainter`.
- `shouldRepaint` devuelve `false`: es estático.

---

## `presentation/widgets/pitch_background.dart`
**Rol:** el fondo animado. Es la pieza con más lógica: cancha en neón verde, **balón
que da pases y rueda en 3D**, barrido de luz, brillo y viñeta. Todo con `CustomPaint`.

### Arquitectura de la animación
- `PitchBackground` es un `StatefulWidget` con `SingleTickerProviderStateMixin`.
- Un **`Ticker`** (`createTicker(_onTick)`) llama a `_onTick(elapsed)` en cada frame.
  Se calcula el **delta-time real** (`dt`) entre frames para que el movimiento sea
  independiente de los FPS; `dt` se limita a `0.05 s` para evitar saltos tras pausas.
- El repintado se dispara con un `ValueNotifier<int>` pasado como `repaint:` al
  `CustomPainter`. Así **solo se repinta el canvas**, sin reconstruir widgets.
- Un objeto `_Scene` (balón + tiempo + rectángulo del campo) se **muta en el sitio** y
  es leído por el pintor en cada frame.
- El rectángulo del campo `_computePitch(size)` se calcula en `build` (vía
  `LayoutBuilder`): un rectángulo 16:10 centrado que se reduce si no cabe en alto.

### Física de los pases
- **Elección de destino** (`_siguiente`): con probabilidad **0.2** un **pase largo** a
  un sector aleatorio (`_destinoLargo`), y con **0.8** un **pase corto** dentro de un
  **radio mínimo/máximo** alrededor del balón (`_destinoCorto`, entre 12 % y 30 % del
  ancho del campo).
- **Duración** (`_duracion`): velocidad de partido. El corto es casi instantáneo
  (`dist/330`, 0.38–0.85 s) y el largo un poco más lento con recuperación
  (`dist/470`, 0.55–1.05 s).
- **Interpolación**: `easeOut` (salida rápida, llegada frenada) → sensación de golpeo
  y recepción. La posición es `lerp(from, to, easeOut(prog))`.
- **Delay entre pases** (`_delay`): **más** tras un corto (0.28–0.54 s, control) y
  **menos** tras un largo (0.09–0.26 s). El ciclo medio queda ~1 pase/segundo.

### Rodadura en 3D (lo clave)
- El balón se modela como una **esfera**. Sus 12 pentágonos negros son los **vértices
  de un icosaedro** (`_sphere`), normalizados a vectores unitarios.
- La orientación es una **matriz de rotación 3×3** (`_Ball.R`, inicia en la identidad).
- En cada frame que el balón se mueve, se compone una rotación incremental sobre el
  **eje perpendicular al movimiento** en el plano `(-dy, dx, 0)`, con
  `ángulo = distancia / radio` → **rodadura física real** (no un giro plano).
  - `_rotAxis(x,y,z,ang)`: matriz eje-ángulo (fórmula de Rodrigues).
  - `_mul(A,B)`: producto de matrices 3×3.
  - `R = _mul(rotAxis(eje, ang), R)`.
- Al pintar, cada pentágono `p` se transforma con `_applyR(R, p)` y **solo se dibuja
  si mira al frente** (`z > 0.02`). El tamaño y la opacidad dependen de la profundidad
  `z`, de modo que los pentágonos se comprimen y desvanecen hacia el borde → volumen
  esférico convincente.

### El pintor `_PitchPainter`
Dibuja, en orden: fondo (degradado radial verde-carbón), **brillo** que respira
(`sin` del tiempo), rejilla de puntos, **líneas del campo** (borde, medio campo,
círculo central, áreas, porterías, puntos de penalti y **arcos de córner**), el
**barrido de luz** (`_drawScan`, una banda que recorre el campo de izq. a der. según
`t`), la **viñeta**, y por último el **balón** (`_drawBall`: sombra en el césped,
cuerpo con degradado esférico y los pentágonos 3D recortados al círculo).
`shouldRepaint` devuelve `false` porque el repintado lo gobierna el `ValueNotifier`.

---

## `presentation/screens/auth/login_screen.dart`
**Rol:** la pantalla de intro: la **tarjeta de login estilo EA** sobre la cancha
animada, con validación y estado de carga.

**Lógica:**
- `ConsumerStatefulWidget`: necesita estado local (los `TextEditingController` y el
  toggle `_obscure`) y además observar providers.
- **Composición**: un `Stack` con `PitchBackground` a pantalla completa y, encima, la
  tarjeta centrada dentro de un `SingleChildScrollView` (para pantallas pequeñas) con
  `maxWidth: 400`.
- **Tarjeta** (`_card`): `Container` **carbón mate** con borde sutil y sombra; dentro
  un `Form` con: `CrestLogo`, título (dos líneas, blanco, bold), subtítulo gris, los
  dos campos y el botón.
- **Campos**: `_dec()` centraliza la decoración estilo EA (fondo oscuro, esquinas
  redondeadas de 16, icono lineal de Material, borde que se pone **verde al enfocar**,
  y borde rojo en error). Cada `TextFormField` usa su `validator` (correo con regex,
  contraseña mínimo 6). El campo de contraseña lleva el **ojo** (mostrar/ocultar) como
  `suffixIcon`.
- **Envío** (`_submit`): oculta el teclado, valida el formulario, llama a
  `authController.signIn(...)` y, si falla, muestra un `SnackBar` con el error. Si
  acierta, **no navega**: de eso se encarga la guardia del router.
- **Estado de carga**: se observa solo `isSubmitting`
  (`ref.watch(authControllerProvider.select(...))`); mientras es `true`, los campos se
  deshabilitan y el botón muestra un spinner.
- **Botón "Entrar"**: `FilledButton` verde con forma de **píldora** (`StadiumBorder`)
  y una flecha, al estilo EA.

---

## `presentation/screens/home/home_screen.dart`
**Rol:** el destino tras iniciar sesión.

**Lógica:** `ConsumerWidget` que **lee** el usuario del provider y lo saluda; el botón
de la `AppBar` llama a `signOut()`, lo que cambia el estado y hace que el router
devuelva al login.

---

## `config/router/app_router.dart`
**Rol:** la navegación con `go_router` y la **guardia de sesión**.

**Lógica:**
- `routerProvider` crea el `GoRouter`.
- Un `ValueNotifier<AuthStatus>` alimentado por `ref.listen(...)` actúa como
  `refreshListenable`: cuando cambia el estado de sesión, el router **re-evalúa** el
  `redirect` (así login y logout navegan solos).
- `redirect`: si el estado es `unknown` (restaurando sesión) no decide nada; si no hay
  sesión manda a `/login`; si la hay y estás en el login, te lleva a `/home`.
- Rutas: `/login → LoginScreen`, `/home → HomeScreen`.

---

## `main.dart`
**Rol:** el arranque.

**Lógica:** `runApp(const ProviderScope(child: MyApp()))` envuelve la app en el
contenedor de Riverpod. `MyApp` es un `ConsumerWidget` que **observa** el
`routerProvider` y monta un `MaterialApp.router` con tema Material 3 y semilla de
color verde.

---

## Cómo probarlo

Este proyecto está en una carpeta de iCloud, así que las builds de **macOS/iOS fallan**
por CodeSign; el **emulador Android** funciona:

```bash
flutter run -d emulator-5554
```

Entra con **demo@ultime.com / 123456** para ver la transición login → home. El fondo
de cancha y el balón 3D se animan de forma continua detrás de la tarjeta.
