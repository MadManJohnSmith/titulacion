# Inventario de recursos — LoboApp

Fecha de recuperación: 2026-09-28

## 1. Dónde está la app

| Ruta | Qué es |
|---|---|
| `/home/alan/Documents/LoboApp/titulacion` | **El proyecto Flutter** (repo git, clonado de GitHub) |
| `/home/alan/Documents/LoboApp/LOBO APP PROTOTIPO V1.xd` | Prototipo Adobe XD (11 artboards) |
| `/home/alan/Documents/LoboApp/Documentos para aplicación LoboApp-...zip` | **116 assets de diseño** (la fuente de verdad del arte) |
| `/home/alan/Documents/LoboApp/lobito.eps`, `iconos inapp-4.eps` | Logos vectoriales sueltos |

Repo remoto: `https://github.com/MadManJohnSmith/titulacion.git`

## 2. Estado de las ramas

`main` = `18d42ed` (16 mar 2025), working tree limpio. **Esta es la app.**

Las otras 4 ramas remotas:

| Rama | Qué es | ¿Sirve? |
|---|---|---|
| `feat/music-library-scaffolding` | App **music_library** (Qobuz/Spotify, blocs, sqflite) | ❌ Otro proyecto |
| `feat/ui-improvements` | music_library,续 con más pantallas | ❌ Otro proyecto |
| `feat/core-integrations` | music_library + Qobuz/Spotify/lyrics | ❌ Otro proyecto |
| `perf-optimization-round1` | **Sí toca esta app** — borra código muerto, quita imports | ⚠️ Parcial, ver abajo |

**Decisión:** se ignoran las 3 de music_library. Se trabaja sobre `main`.

⚠️ `perf-optimization-round1` tiene un **bug**: quita el `Future.delayed` del splash
(`lib/splash_screen.dart`), lo que hace que la app salte directo a bienvenida sin
mostrar el logo. Si se recupera esa rama hay que restaurar ese delay.

## 3. Qué hay implementado hoy (1,216 líneas)

```
SplashScreen (3s, isotipo.svg)
  └─> WelcomeScreen ("¡Bienvenido a la Travesía del Titulado!")
        └─> HomeScreen — "Elige tu ruta" (3 rutas)
              ├─> PromedioScreen    → /levels
              ├─> CenevalScreen     → /levels   ┐ las 3 caen al MISMO
              └─> ProfesionalScreen → /levels   ┘ /levels
```

| Archivo | LOC | Estado |
|---|---|---|
| `lib/main.dart` | 81 | Rutas OK. Tiene el `MyHomePage` contador de ejemplo muerto |
| `lib/splash_screen.dart` | 53 | Bien |
| `lib/welcome_screen.dart` | 63 | Bien |
| `lib/home_screen.dart` | 120 | Bien |
| `lib/promedio_screen.dart` | 135 | Pergamino + `CurvedText` + lobo_aviador |
| `lib/ceneval_screen.dart` | 132 | Pergamino + `CurvedText` + lobo_aviador |
| `lib/profesional_screen.dart` | 132 | Pergamino + `CurvedText` + lobo_aviador |
| `lib/levels_screen.dart` | 385 | **Stub**: solo popups de links/contactos. No hay niveles |
| `lib/widgets/curved_text.dart` | 80 | Textos en arco, funciona |
| `lib/test.dart` | 35 | **Basura**: copia de SplashScreen, no se usa |

**Gap principal:** las 3 rutas apuntan al mismo `/levels`, que no tiene mapa, ni
niveles, ni mascota, ni progreso. El "juego" no existe todavía.

## 4. Assets: diseño vs repo

El repo tiene **12** assets. El zip de diseño tiene **116**. Faltan ~104.

### Ya en el repo
`isotipo.svg`, `lobo_aviador.svg`, `lobo_deportivo.svg`, `cloud.svg`,
`parchment_Open.png/.svg`, `parchment_ceneval.svg`, `parchment_ex_prof.svg`,
`parchment_title.svg`, `progress_point1/2.svg`, `world.svg`

### Faltan (por categoría, del zip)

| Categoría | Cantidad | Contenido |
|---|---|---|
| Mapas | 2+ | `mapa agua_examen ceneval.svg`, `Mapa tierra/` |
| Iconos de nivel | 7 | `Icono nivel 1..7` (agua y tierra) |
| Fondos CENEVAL | 10 | `Fondo nivel 1..7`, `Fondo examen ceneval`, `Fondo final`, `Fondo para pestañas externas` |
| Fondos Profesional | 6 | `fondo inicio_nivel 1`, `nivel 2_3_4`, `nivel 5`, `nivel 6`, `documentos` |
| Títulos CENEVAL | 20 | `nivel 1..7`, + un título por cada documento |
| Títulos Profesional | 22 | `nivel 1..6` + un título por cada documento |
| Mascotas | 17 | `lobo 1..9` (profesional), `Mascota nivel 1..7 + inicio + final` (CENEVAL) |
| Pergaminos | 6 | 3 por ruta (inicio, niveles, documentos) |
| Pantallas | 19 | Bienvenida, inicio, selección de titulación |
| Carpetas vacías | 2 | `Menú hamburguesa/`, `Pestañas secundarias/` — **sin assets, son pantallas sin diseño** |

> **Nota:** "Menú hamburguesa" y "Pestañas secundarias" están vacías en el zip.
> Esas pantallas hay que diseñarlas desde cero (o no hacerlas).

## 5. Tipografía

El diseño usa **Poppins** (pesos 400/500/600/700/800/900), **Bungee**,
**Bungee Spice** y **Tajawal**. **Ninguna está en el repo** — `pubspec.yaml` no
declara ninguna fuente. Hay que conseguirlas (Google Fonts,SIL OFL, libres)
y declararlas en `pubspec.yaml`.

## 6. Texto de los niveles — de dónde sale

El texto editorial (qué documentos pedir y cómo) está en:

```
Textos y títulos de niveles/mapa tierra/textos/EDITORIAL parte yuu con cambios -.indd
Textos y títulos de niveles/mapa tierra/textos/textos niveles ezamen profesional_1..9.eps
```

- Los **SVG del zip traen el texto contorneado a paths** → no se puede leer.
- Los **EPS son solo dibujo**, no texto.
- El **.indd sí tiene el texto real**, pero sale con acentos partidos
  (`n` = `ón`, `s` = `á`) y de forma intercalada con basura binaria.

Ya se extrajo y reconstruyó la mayor parte → ver `docs/CONTENIDO-NIVELES.md`.
**Falta que alguien valide el texto contra el diseño.**

## 7. Estado técnico

| Punto | Estado |
|---|---|
| Flutter / Dart SDK | ❌ **No instalados** en esta máquina |
| `pubspec.yaml` assets | Declara `assets/fonts/`, `assets/audio/`, `assets/json/` — **no existen** |
| `applicationId` | `com.example.titulacion` — placeholder |
| `android:label` | `titulacion` — hay que poner "LoboApp" |
| `test/widget_test.dart` | Test del contador de ejemplo — **falla**, ya no existe `MyHomePage` |
| `README.md` | Boilerplate de Flutter |

## 8. Datos de contacto ya existentes

Están hardcodeados en `lib/levels_screen.dart` (BUAP, Facultad de Arquitectura):
- CGAU: +52 (222) 229 5500 · jorge.avelinos@correo.buap.mx · @cgaubuap
- Titulación FAB: Maricarmen Lara · titulacion.fabuap@correo.buap.mx
- DAE: Víctor · +52 (221) 256 998

⚠️ Son de **Arquitectura**. Si la app es para toda la BUAP hay que hacerlo
configurable o sacar los datos de una BD.
