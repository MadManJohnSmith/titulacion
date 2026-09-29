# Plan de finalización — LoboApp

> **Estado: ejecutado.** Todas las fases 0–8 están hechas. `flutter analyze` sale
> limpio y los 26 tests pasan. Lo que quedó fuera está en `PENDIENTES.md`.
> Este documento se conserva como registro de cómo se ordenó el trabajo.

**Objetivo:** convertir el prototype actual en la app jugable del diseño
(mapa con islas, niveles, mascota, pergaminos y progreso guardado).
**Rama:** `main`. **Las 3 ramas `music_library` se ignoran** (son otro proyecto).

---

## Fase 0 — Base limpia (antes de tocar features)

Sin esto, todo lo demás se compila sobrevertedura.

- [ ] Instalar Flutter SDK (`^3.7.0` según `pubspec.yaml`); agregar al PATH.
- [ ] `flutter pub get` y `flutter analyze` para ver la línea base real.
- [ ] Borrar código muerto: `lib/test.dart`, `MyHomePage`/`_MyHomePageState` en `main.dart`.
- [ ] Arreglar `test/widget_test.dart` (hoy testea el contador que ya no existe → falla).
- [ ] Arreglar `pubspec.yaml`: quitar `assets/fonts/`, `assets/audio/`, `assets/json/`
      (no existen y Flutter avienta) — se re-agrega `assets/json/` en Fase 2.
- [ ] Cambiar `android:label` de `titulacion` a `LoboApp`.
- [ ] Renombrar el paquete de `com.example.titulacion` (decidir con el usuario;
      afecta el bundle id publicado).

## Fase 1 — Datos: el modelo de niveles

El contenido de los niveles no puede vivir hardcodeado en widgets: son 3 rutas
× 6-7 niveles × listas de documentos, y va a cambiar.

- [ ] `assets/json/routes.json` — 3 rutas, cada una con sus niveles.
      Cada nivel: `id`, `titulo`, `descripcion`, `mascota` (path),
      `fondo` (path), `iconoNivel` (path), `pasos[]`, `documentos[]`.
- [ ] Llenar desde `docs/CONTENIDO-NIVELES.md` (ya extraído del `.indd`).
- [ ] `lib/models/` — `Ruta`, `Nivel`, `Documento`, `Paso` (fromJson).
- [ ] `lib/services/level_repository.dart` — carga el JSON con `rootBundle`.

**Decisión pendiente:** los títulos de nivel en el diseño son SVG con texto
contorneado (imágenes, no texto). O se usan como imagen, o se transcriben a
texto real con `CurvedText` (mejor para accesibilidad y para traducir).

## Fase 2 — Estado y persistencia

- [ ] `lib/state/progress_provider.dart` — `ChangeNotifier` (sin paquete extra).
- [ ] `shared_preferences` para guardar: ruta elegida, nivel actual, niveles
      completados, documentos marcados por el usuario.
- [ ] `lib/models/level_state.dart` — `locked` / `unlocked` / `current` / `done`.

## Fase 3 — Mapa de niveles (la pantalla que falta)

Es el corazón de la app. Hoy `/levels` es un stub.

- [ ] Copiar los ~104 assets faltantes del zip a `assets/images/`, organizados:
      ```
      assets/images/
        maps/{agua,tierra}/
        icons/level_1..7.svg
        levels/{ceneval,profesional,promedio}/bg_*.svg
        mascot/{ceneval,profesional}/*.svg
        parchment/*.svg
      ```
- [ ] `lib/screens/map_screen.dart` — fondo del mapa + 7 islas posicionadas.
      Las islas salen de `Mapas/`; los iconos de `Iconos de nivel 1..7.svg`.
- [ ] `lib/widgets/level_island.dart` — estado visual (bloqueada=gris, actual=pulsa,
      hecha=check) con animación al tocar.
- [ ] **Renombrar la ruta:** las 3 rutas hoy van al mismo `/levels`. Pasar el
      argumento: `Navigator.pushNamed(context, '/levels', arguments: rutaId)`.
- [ ] Navegación: al tocar la isla actual → `LevelDetailScreen`.

## Fase 4 — Pantallas de nivel

- [ ] `lib/screens/level_detail_screen.dart` — fondo del nivel + mascota +
      título en arco (`CurvedText` ya existe y funciona).
- [ ] Lista de documentos con checkboxes (lo marca el usuario a mano).
- [ ] Botón "Marcar como completado" → desbloquea el siguiente nivel.

## Fase 5 — Perseguir el diseño

- [ ] Pantalla de bienvenida con el texto real del `.indd`
      ("¡Bienvenido, futuro titulado!" + párrafo) en vez del texto actual.
- [ ] Pantalla de selección de titulación con las flechas `FLECHA ATRAS` /
      `FLECHA SIGUIENTE` del zip (hoy se navega con una lista vertical).
- [ ] Fuentes: bajar **Poppins**, **Bungee**, **Bungee Spice**, **Tajawal**
      (Google Fonts, licencia OFL) y declararlas en `pubspec.yaml`.
- [ ] Tema: quitar `ColorScheme.fromSeed(deepPurple)`; los colores del diseño
      son `#0B233A`, `#002D4C`, `#496D83`, `#033d5e`, `#083b5b`.

## Fase 6 — Contactos y links (reorganizar)

Hoy está todo hardcodeado en `levels_screen.dart` con `GestureDetector`.
- [ ] Mover los datos a `assets/json/contactos.json` y `links.json`.
- [ ] `lib/screens/contacts_screen.dart` y `links_screen.dart` separados.
- [ ] `url_launcher` con `launchUrl(mode: LaunchMode.externalApplication)`.
      **Bug actual:** se llama `launchUrl(url)` sin `mode`, y nunca se checa
      el retorno — si falla no pasa nada visible.
- [ ] ⚠️ Los contactos son de la **Facultad de Arquitectura**. Si es para toda la
      BUAP hay que hacerlo configurable por facultad.

## Fase 7 — Tests y entrega

- [ ] Tests de widget del flujo: inicio → ruta → mapa → nivel → completar.
- [ ] Test de que el JSON de niveles parsea y todas las rutas de assets existen
      (esto se rompe fácil al renombrar archivos).
- [ ] README real: qué es la app, cómo correr, cómo cambiar el contenido.

---

## Riesgos / decisiones que necesito de vos

| # | Tema | Por qué importa |
|---|---|---|
| 1 | **Flutter no está instalado** | Sin SDK no puedo verificar que compile nada. Hay que instalarlo primero. |
| 2 | **¿Cuántos niveles por ruta?** | El diseño no cuadra: 7 iconos, 7 fondos CENEVAL, 6 fondos profesionales, **9 lobos** y 9 EPS de texto. |
| 3 | **¿El texto de los niveles es correcto?** | Salió de un binario con acentos rotos. Hay que validarlo. |
| 4 | **Assets como imagen o como texto real?** | Los títulos son SVG con texto contorneado. Afecta accesibilidad y traducción. |
| 5 | **¿App para toda la BUAP o solo Arquitectura?** | Los contactos están hardcodeados de una facultad. |
| 6 | **Bundle id y nombre de paquete** | `com.example.titulacion` es placeholder; hay que elegir antes de publicar. |
| 7 | **"Menú hamburguesa" y "Pestañas secundarias"** | Son carpetas **vacías** en el zip: no hay diseño. ¿Se inventan o se omiten? |
| 8 | **Cuentas / sincronización** | ¿El progreso es solo local o hay login en la BUAP? Cambia la arquitectura. |

## Orden sugerido

```
Fase 0 (base) → Fase 1+2 (datos y estado) → Fase 3 (mapa)
   → Fase 4 (nivel) → Fase 5 (pulido) → Fase 6 (contactos) → Fase 7 (tests)
```

Fase 0 es bloqueante: sin Flutter instalado no se puede validar nada.
