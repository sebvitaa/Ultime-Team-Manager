# Ultimate Team Manager

Aplicación móvil tipo **FC Ultimate Team** desarrollada en **Flutter / Dart**. El
jugador arma su equipo de 11 con cartas de futbolistas, opera en un mercado de
compra/venta, simula partidos y compite en una liga que reparte monedas según los
resultados.

El proyecto parte de la app base de la Unidad 1 (un contador con `setState`) y se
construye **encima** de ella durante las clases de la unidad de Flutter.

> **Estado actual:** arranque. La app base incluye la pantalla `counter/`, que será
> reemplazada por el flujo real (login → home → plantilla / mercado / liga).

---

## Contexto del proyecto

El objetivo es llevar la idea a una app funcional en tres clases, cumpliendo los
requisitos mínimos de la unidad:

1. **Varias pantallas + navegación** — mínimo 3 pantallas conectadas (login → home → detalle/formulario).
2. **Una lista con CRUD** — el **mercado** y la **plantilla** permiten crear, ver, editar y eliminar cartas.
3. **Conexión a datos** — consumo de una API pública de fútbol y/o Supabase, con caché local para el modo offline.
4. **UI cuidada con widgets** — buen uso de widgets de layout, con estados de **carga** y de **vacío**.
5. **Repositorio en GitHub** — commits de ambos integrantes y ramas por tarea.

### Requerimientos funcionales

| # | Requerimiento | Descripción |
|---|---------------|-------------|
| RF1 | Login y sesión | Inicio de sesión con validación de campos. Sesión persistente. Offline hoy, escalable a online. |
| RF2 | Plantilla 11 (4-3-3) | Colocar futbolistas en sus posiciones sobre el campo, con la alineación 4-3-3 por defecto. |
| RF3 | Cartas | Cada futbolista es una carta con su valoración (rating) y atributos. Por ahora los atributo son su posición, que define en que posiciones puede jugar en el 4-3-3 y su precio, cantidad de monedas por las que se puede vender o comprar en el mercado.|
| RF4 | Monedas | Dinero que tiene el jugador y que puede gastar en jugadores o en partidos. 
| RF4 | Mercado | Comprar y vender cartas (CRUD sobre la colección del usuario). |
| RF5 | Simulación de partidos | Resultado en función de la valoración media de cada equipo. |
| RF6 | Liga | Varios equipos; cada partido reparte monedas según el resultado. |

> **Diseño offline-first, escalable a online:** toda la lógica de datos pasa por
> interfaces de repositorio (`domain/repositories`). Hoy se implementan contra
> almacenamiento local (Hive / JSON); mañana se añade una implementación contra
> Supabase **sin tocar** la capa de presentación.

---

## Stack tecnológico

| Área | Tecnología | Motivo |
|------|-----------|--------|
| Framework / lenguaje | **Flutter · Dart** | Requisito de la unidad; multiplataforma. |
| Gestión de estado | **Riverpod** (`flutter_riverpod`) | Escalable, testeable y desacoplado de la UI. |
| Navegación | **go_router** | Rutas declarativas para el flujo entre pantallas. |
| Persistencia local | **Hive** + **shared_preferences** | Cartas/plantilla/liga (Hive) y estado de sesión (prefs). |
| Backend online (futuro) | **Supabase** | Auth + Postgres para la versión online. |
| Origen de cartas | **JSON semilla** en `assets/data` + **API pública de fútbol** (p. ej. TheSportsDB) | Datos offline y consumo de API para la Clase 3. |
| Testing | **flutter_test** | Pruebas de widgets y de lógica. |
| Linting | **flutter_lints** | Buenas prácticas (`analysis_options.yaml`). |

---

## Arquitectura

Arquitectura por capas (inspirada en Clean Architecture), coherente con la ruta ya
presente en el proyecto base (`lib/presentation/screens/...`):

- **`domain`** — entidades y contratos de repositorio (reglas de negocio puras, sin Flutter).
- **`data`** — modelos, orígenes de datos (local/remoto) e implementaciones de los repositorios.
- **`presentation`** — pantallas, widgets y providers (Riverpod).
- **`core` / `config`** — utilidades, servicios, tema, rutas y constantes transversales.

---

## Estructura de carpetas

La estructura por capas ya está creada; los archivos de cada carpeta se irán añadiendo
conforme avance el proyecto.

```
Ultime-Team-Manager/
├── android/  ios/  web/  windows/  macos/  linux/   # proyectos nativos (Flutter)
├── build/                                           # artefactos de compilación
├── test/                                            # pruebas
├── docs/                                            # documentación del proyecto
│   └── planificacion/                               # planificación (LaTeX + PDF)
├── assets/                                         # recursos estáticos
│   ├── images/                                     #   escudos, fondos, cartas
│   ├── fonts/                                      #   tipografías
│   └── data/                                       #   semillas JSON (jugadores, equipos, liga)
├── lib/
│   ├── main.dart                                    # punto de entrada
│   ├── config/                                     # configuración transversal
│   │   ├── router/                                 #   rutas (go_router)
│   │   ├── theme/                                  #   tema y estilos
│   │   └── constants/                              #   constantes (formaciones, economía)
│   ├── core/                                       # núcleo compartido
│   │   ├── errors/                                 #   fallos y excepciones
│   │   ├── utils/                                  #   helpers (rating, simulación)
│   │   └── services/                               #   almacenamiento local, sesión
│   ├── data/                                       # capa de datos
│   │   ├── datasources/                            #   local (Hive/JSON) y remoto (API/Supabase)
│   │   ├── models/                                 #   DTOs y (de)serialización
│   │   └── repositories/                           #   implementaciones de los contratos
│   ├── domain/                                     # capa de dominio
│   │   ├── entities/                               #   Player, Card, Team, Match, League
│   │   ├── repositories/                           #   contratos (interfaces)
│   │   └── usecases/                               #   casos de uso (comprar, simular, alinear)
│   └── presentation/                               # capa de presentación
│       ├── screens/
│       │   ├── counter/                             # pantalla base (a eliminar)
│       │   ├── auth/                               #   login / registro
│       │   ├── home/                               #   dashboard (monedas, accesos)
│       │   ├── squad/                              #   armar el 11 (4-3-3)
│       │   ├── market/                             #   mercado (comprar/vender)
│       │   ├── league/                             #   liga y clasificación
│       │   └── match/                              #   simulación de partido
│       ├── widgets/                                # widgets reutilizables (PlayerCard, PitchView…)
│       └── providers/                              # providers de estado (Riverpod)
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

---

## Puesta en marcha

Requisitos: Flutter SDK (Dart `^3.12.2`).

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en un dispositivo/emulador
flutter run

# Ejecutar pruebas
flutter test
```

---

## Equipo

| Integrante | Rol principal |
|-----------|----------------|
| **Sebastián Ramírez** | Autenticación, plantilla (4-3-3), arquitectura base. |
| **Joaquín Parraud** | Mercado, simulación de partidos, liga y economía. |

> El trabajo se organiza con **ramas por tarea** (`feature/...`) y *pull requests*,
> asegurando commits de ambos integrantes.

---

## Planificación

El cronograma completo (hitos, sprints y diagrama de Gantt) está en:

- `docs/planificacion/planificacion.tex` — fuente LaTeX.
- `docs/planificacion/planificacion.pdf` — documento compilado.
