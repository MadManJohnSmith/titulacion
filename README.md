# 🐺 LoboApp

<p align="center">
  <img src="screenshots/bienvenida.png" alt="Pantalla de bienvenida de LoboApp" width="260"/>
</p>

<h3 align="center">Tu titulación en la BUAP, como una aventura</h3>

<p align="center">
  <a href="https://github.com/MadManJohnSmith/LoboApp/actions/workflows/ci.yml"><img src="https://github.com/MadManJohnSmith/LoboApp/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
  <img src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/plataforma-Android_%C2%B7_Web-0B233A" alt="Android y Web"/>
  <img src="https://img.shields.io/badge/licencia-todos_los_derechos_reservados-E0A93B" alt="Licencia"/>
</p>

**LoboApp** acompaña a los alumnos de la [BUAP](https://www.buap.mx) durante su
proceso de **titulación**: eliges la ruta de titulación que te corresponde,
avanzas por un mapa nivel por nivel, y cada nivel te explica exactamente qué
trámites hacer, qué documentos pedir y a quién acudir.

Funciona **100% sin conexión y sin cuenta**: tu progreso se guarda únicamente
en tu dispositivo.

<p align="center">
  🌐 <a href="https://madmanjohnsmith.github.io/LoboApp/"><strong>Pruébala en el navegador (demo)</strong></a>
  — versión de muestra sin buscadores; la app completa va en la instalación de abajo.
</p>

---

## 📱 Capturas

| Bienvenida | Registro | Elige tu ruta |
|:---:|:---:|:---:|
| ![Bienvenida](screenshots/bienvenida.png) | ![Registro](screenshots/registro_facultades.png) | ![Rutas](screenshots/rutas.png) |

| Tu ruta | Mapa de niveles | Detalle del nivel |
|:---:|:---:|:---:|
| ![Pergamino](screenshots/ruta_pergamino.png) | ![Mapa](screenshots/mapa.png) | ![Nivel](screenshots/nivel.png) |

<p align="center">
  <img src="screenshots/perfil.png" alt="Perfil con tu avance" width="260"/><br/>
  <em>Tu perfil guarda la facultad elegida y el avance de cada ruta.</em>
</p>

## 🗺️ ¿Cómo funciona?

1. **Entras con tu matrícula** — la app te busca en la base de alumnos de la
   BUAP (318,374 registros) y toma tu nombre. Si no estás o prefieres no
   buscarla, puedes continuar como invitado.
2. **Eliges tu unidad académica** — las 33 facultades y escuelas de la BUAP
   están precargadas con su contacto de titulación.
3. **Eliges tu ruta de titulación** — titulación por **promedio** (7 niveles),
   por **CENEVAL** (8 niveles) o por **examen profesional** (6 niveles).
4. **Recorres el mapa** — cada isla es un nivel de tu trámite, desbloqueado en
   orden, con tu mascota lobo avanzando contigo.
5. **Completas cada nivel** — pasos explicados uno por uno y una lista de
   documentos para marcar como recogidos. Al terminar todos los niveles, tu
   expediente está listo.

## ✨ Características

- 🎮 **Gamificado**: rutas, niveles, mascotas y mapa — el trámite deja de ser
  un laberinto de PDFs.
- 📋 **49 documentos y 54 pasos** explicados en lenguaje claro, recopilados de
  la normativa de la BUAP.
- 🏛️ **Las 33 unidades académicas** con su coordinación de titulación.
- 🔍 **Buscador de matrícula offline** sobre 318,374 alumnos: la base va
  comprimida dentro de la app y solo se descomprime la cohorte que toca.
- 📇 **Directorio BUAP**: búsqueda de 43,025 trabajadores por nombre o
  matrícula.
- ☎️ **Contactos y enlaces útiles**: DAE, CGAU, trámites en línea.
- 🔒 **Privado por diseño**: sin servidor, sin cuenta, sin analítica. Nada
  sale de tu teléfono. [Detalles de privacidad](docs/PRIVACIDAD.md).

## 📲 Instalación

Todas las versiones se publican en la página de
[**Releases**](https://github.com/MadManJohnSmith/LoboApp/releases).

### Android (recomendado)

Descarga el APK más reciente (`LoboApp-x.y.z-android-arm64.apk` para
teléfonos modernos, `armv7` para equipos antiguos), ábrelo en tu teléfono y
acepta la instalación (necesitas permitir "instalar apps de fuentes
desconocidas" la primera vez).

### Windows

Descarga `LoboApp-x.y.z-windows-x64.zip`, descomprímelo donde quieras y
ejecuta `LoboApp.exe`. No requiere instalación.

### macOS

Descarga `LoboApp-x.y.z-macos.zip`, descomprímelo y arrastra `LoboApp.app` a
Aplicaciones. Como la app no está firmada con certificado de Apple, la
primera vez haz clic derecho → **Abrir**.

### Linux

Descarga `LoboApp-x.y.z-linux-x64.tar.gz`, descomprímelo y ejecuta
`./bundle/LoboApp` (requiere GTK 3, que cualquier escritorio moderno trae).

### Web

No requiere instalación: usa la
[demo en el navegador](https://madmanjohnsmith.github.io/LoboApp/), o
compílalo tú (pasos abajo).

### Compilar desde el código fuente

Necesitas [Flutter](https://docs.flutter.dev/get-started/install) 3.47 o
superior (y Android SDK solo si quieres el APK):

```bash
git clone https://github.com/MadManJohnSmith/LoboApp.git
cd titulacion
flutter pub get
flutter run -d chrome            # web
flutter run -d windows           # (o macos / linux)
flutter build apk --release      # Android → build/app/outputs/flutter-apk/
```

Para verificar que todo está en orden:

```bash
flutter analyze   # No issues found!
flutter test      # todas las pruebas, incluidas de integridad de datos y assets
```

## 🔒 Privacidad

- No hay servidor ni cuenta: todo el progreso vive en `shared_preferences`
  locales del dispositivo.
- La base de alumnos incluida contiene **solo matrícula y nombre** — se
  quitaron todos los correos de alumnos, y de los trabajadores solo se
  conservan los correos institucionales `@correo.buap.mx`.
- La demo web del navegador **no incluye las bases** (por eso sus buscadores
  están desactivados): el padrón solo viaja dentro de la app instalada, nunca
  como archivos descargables.
- El proceso completo de decisión y cómo quitar las bases si la BUAP lo
  solicita está documentado en [docs/PRIVACIDAD.md](docs/PRIVACIDAD.md).

## 🛠️ Cambiar el contenido (sin programar)

**Toda la información de la app vive en `assets/json/`** — nada está
hardcodeado en el código:

| Archivo | Contenido |
|---|---|
| `routes.json` | Las 3 rutas: niveles, pasos y documentos |
| `facultades.json` | Las 33 unidades académicas y sus contactos |
| `links.json` | Enlaces útiles de la BUAP |
| `contactos.json` | Contactos generales (DAE, CGAU) |

¿Cambió un requisito, un costo o un teléfono? Se edita el JSON y la app se
actualiza. ¿Tu facultad no tiene correo publicado? Mándalo con su fuente
oficial vía [issue](https://github.com/MadManJohnSmith/LoboApp/issues) y
se agrega.

## 🧱 Estructura del proyecto

```
lib/
  main.dart                  raíz: bienvenida ↔ home
  theme.dart                 paleta y tipografías (Poppins, Bungee, Tajawal)
  models/models.dart         Ruta, Nivel, Paso, Documento, Facultad, Alumno
  state/app_state.dart       estado + persistencia local del progreso
  services/                  repositorios: contenido JSON, alumnos, trabajadores
  screens/                   las 10 pantallas de la app
  widgets/                   componentes reutilizables
tools/                       script para regenerar las bases desde los .db
docs/                        privacidad, pendientes, decisiones de diseño
```

## 🚦 Estado del proyecto

La app está **completa y lista para despliegue**: cada tag (`v1.1.0`, …)
dispara una compilación automática para Android, Windows, macOS y Linux que
se publica sola en Releases, y cada cambio en `main` actualiza la demo web.
Lo que queda depende de la BUAP: confirmar algunos textos del diseño
original, completar los correos de titulación que no están publicados, y la
firma de release para Play Store. Detalles en
[docs/PENDIENTES.md](docs/PENDIENTES.md).

## 🤝 Contribuir

Issues y pull requests son bienvenidos — lee
[CONTRIBUTING.md](CONTRIBUTING.md) primero. En especial se agradece ayuda para
**verificar información oficial de la BUAP**.

## 📄 Licencia

El código es público **solo para consulta**: todos los derechos reservados —
no se permite su copia, reutilización ni distribución sin autorización
escrita. Ver [LICENSE.md](LICENSE.md).
