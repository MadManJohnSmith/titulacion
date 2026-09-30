# Lo que falta para publicar LoboApp

Fecha: 2026-09-29 (comprobación completa de aquella corrida). La app
**compila, pasa las 116 pruebas de aquel día y ya genera AAB y APKs de release**.
Comprobado entonces en `titulacion/`: `flutter analyze` → `No issues found!`,
`flutter test` → `+116: All tests passed!`, `flutter build web` →
`✓ Built build/web`, `flutter build apk --debug` →
`✓ Built build/app/outputs/flutter-apk/app-debug.apk`. Lo de aquí son cosas que
dependen de la BUAP o de una decisión de ellos, no bugs.

**Revisado el 2026-09-30.** El 116 de arriba es el dato histórico de la corrida
del 2026-09-29, no el estado de hoy: la suite ya no tiene 116 pruebas, porque las
reparaciones F-01 a F-13 traen las suyas. Con el código de hoy, `flutter test` da
`+166: All tests passed!` (las 161 que ya pasaban más las 5 de F-13) y
`flutter analyze` da `No issues found!`. Esa revisión volvió a correr solo esas
dos; los `flutter build` que se citan siguen siendo los del 2026-09-29. Para citar
una cifra, vuélvela a medir antes de escribirla.

**Nota de versión:** la app cambió de 3 a 8 rutas y de 33 a 34 unidades, y el
alumno ahora elige una **modalidad** (con requisitos, fuente y fecha) en vez de
una ruta suelta. Los pendientes de ese trabajo están en §6 y el detalle
completo en `out/INFORME-MODALIDADES.md`.

---

## 1. Lo que necesito de la BUAP

### Validar el texto de los niveles — importante

El contenido salió de extraer el texto de un `.indd` binario, con los acentos
rotos (`n` = «ón», `s` = «á»). Reconstruí lo que pude, pero **alguien tiene que
compararlo contra el diseño antes de publicar**. Estos son los huecos que dejé
a propósito, sin inventar números:

| Dónde | Qué falta |
|---|---|
| `routes.json` → promedio, nivel 4 | **Costo del acta de nacimiento actualizada.** El diseño dice «1?50 pesos» (un dígito se perdió al exportar). Casi seguro es $150, pero no lo puse porque un cobro mal puesto hace que un alumno vaya con el monto equivocado. Hoy `routes.json` **no publica ningún costo**: verifiqué que las 8 rutas no contienen la palabra «pesos» ni «costo». |
| `routes.json` → profesional, nivel «Aval Académico» | «Tienes 1 año para presentar la tesis tras el registro, con prórroga de hasta 6 meses» — **¿desde qué fecha se cuenta el año?** |
| `routes.json` → profesional, nivel «Depósito en biblioteca» | La **URL del formato de aval académico**: el nivel menciona el formato pero no su enlace. |
| `routes.json` → profesional, nivel «Entrega tu tesis» | El **correo** de confirmación del título: el nivel dice «esperen un correo de confirmación» y el diseño no trae la dirección. |
| `routes.json` → promedio, nivel 7 «Entrega final» | Vigencia: puse 3 meses para el certificado de biblioteca y 6 para el oficio **según el diseño, pero confírmenlo**. Son los dos únicos plazos de vigencia escritos en las 8 rutas. |

### Correos de las 26 unidades que no los publican

De las 34 unidades de `facultades.json`, **8 tienen correo con
`confianza: "alta"`** (verificado en el sitio oficial en esta corrida):
Administración, ARPA, Ciencias Políticas y Sociales, Estomatología,
Ingeniería Química, Lenguas, Medicina y Complejo Regional Centro. Una más
(Complejo Regional Sur) tiene la coordinación identificada por nombre pero sin
correo propio, y quedó con `confianza: "media"`.

Las otras 26 tienen el campo `correo` vacío: la app les cae al contacto general
de la DAE en vez de mostrar un correo inventado. **Si tienen los correos internos,
van en `facultades.json` y ya aparecen** — no hay que tocar código.

**Caso Arquitectura:** el código original traía hardcodeados a Maricarmen Lara y
`titulacion.fabuap@correo.buap.mx`, y **no se pudieron confirmar**. Esta corrida
**quitó el correo** del JSON (queda `correo: ""`, `confianza: "baja"`) y dejó la
advertencia en el campo `notas`: «no pudo confirmarse en el sitio oficial durante
esta investigación: VERIFICAR antes de usar». Sigue apareciendo como responsable
«Maricarmen Lara (referido en la app actual)». Si la BUAP lo confirma, se
devuelve el correo a `facultades.json`.

### ¿La base de alumnos se puede distribuir dentro de la app?

La app incluye las 318 mil matrículas y nombres. Quité los correos y no hay
facultad asociada, así que no se puede saber qué unidad estudia cada persona. Aun
así, **cualquiera que descargue la app puede extraer la lista**.

Si la BUAP prefiere no distribuirla, está documentado cómo quitarla en
`docs/PRIVACIDAD.md` en 3 pasos, y la app funciona igual en modo invitado.

### ¿Suena bien incluir a los 43 mil trabajadores?

Mismo criterio: solo van matrícula, nombre y correo institucional (10,715 de
43,025 lo tienen; los personales se descartaron). El directorio **no** filtra
por facultad, porque la base no trae la unidad — y así está dicho en la app,
para no prometer un filtro que no existe.

### Revisión de la base de alumnos

De 318,374 registros: 841 sin apellido materno, 1 sin nombre, 1,567 sin
correo (no usamos el correo). Ninguna matrícula duplicada. **No hay nada que
corregir, pero conviene que lo sepan.**

---

## 2. Decisiones de publicación

- [ ] **Firmas de release**: el AAB que compilé está **sin firmar**
      (`flutter build appbundle` usa la clave de debug). Play Store rechaza
      builds sin firmar. Hay que generar un keystore:

      ```bash
      keytool -genkey -v -ke ~/loboapp-upload.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
      ```

      y ponerlo en `android/key.properties` (**ese archivo NO se sube al
      repositorio**).
- [ ] **iOS**: falta el certificado de Apple Developer, el provisioning profile
      y probarlo en un dispositivo real. Solo compilé Android.
- [ ] **Correo de soporte y sitio web** para la ficha de tienda
      (`docs/TIENDA.md` los tiene marcados como pendientes).
- [ ] **Subir la política de privacidad** a una URL institucional y ponerla en
      Play Console. El texto está en `docs/PRIVACIDAD.md`.
- [ ] **Capturas de pantalla** para la tienda. La ficha lista cuáles tomar.
- [ ] **Gradle**: la versión que traía el repo (8.10.2) no servía; la subí a
      8.14.3. Flutter avisa que 8.14 pronto será anticuada y pide 9.1+.
      Conviene migrar antes de que se rompa con una actualización del SDK.

---

## 3. Decisiones de diseño que tomé sin consultar

Las anoto para que puedas revertirlas si no te convencen:

- **Mapas por ruta — se movieron.** El zip de diseño tenía `Mapa agua` con
  archivo, pero `Mapa tierra` y `Mapa aire` estaban **vacías**. En el commit
  anterior el reparto era promedio → tierra, CENEVAL → aire, profesional → agua.
  **Esta corrida lo rotó** para que el único mapa que el diseño entregó
  (agua) fuera el de CENEVAL: hoy CENEVAL → `mapa_agua.png`, examen profesional y
  las rutas de tesis / experiencia profesional / asignatura optativa →
  `mapa_tierra.png`, y promedio, diplomado y seminario → `mapa_aire.png`.
  **Los tres PNG se generaron durante esta corrida y no son arte de diseño**
  (antes eran degradados planos); el script que los produce no quedó en el
  repositorio, así que no son reproducibles desde el código. Si el cambio no te
  gusta, es una línea por ruta en `routes.json` — pero entonces el único mapa
  del diseño se queda sin usar.
- **Menú hamburguesa y pestañas secundarias.** También estaban vacías en el
  zip. Hice un menú con los colores de las demás pantallas, que lleva a perfil,
  contactos y directorio.
- **Títulos como texto, no como imagen.** En el diseño son SVG con el texto
  contorneado a paths. Los rendericé como texto real: se ven distinto pero se
  pueden leer con lector de pantalla y traducir.
- **Quité Bungee Spice.** Venía en el diseño, pero el archivo (1.47 MB) se
  renderizaba en el color de respaldo de Flutter — naranja, ilegible sobre el
  pergamino. Uso Bungee, que sí funciona y ocupa 8 veces menos. Si quieren el
  Spice, hay que conseguir una versión que Flutter pueda rasterizar.
- **Los títulos de nivel ya no van en arco.** El texto curvo (`CustomPaint`) se
  salía de su caja con las fuentes nuevas y quedaba invisible. Ahora es texto
  plano con Bungee: legible y confiable.
- **Niveles por ruta: 8, 9 y 7.** El diseño no cuadra: hay 7 iconos de nivel,
  7 fondos de CENEVAL, 6 de profesional, 9 lobos y 9 EPS de texto. Este texto
  decía 7, 8 y 6 y ya estaba desactualizado: los conteos que hoy trae
  `routes.json` (8, 9 y 7) son los mismos que estaban en el commit anterior y
  esta corrida no los tocó. **Si profesional debería tener 9, hay que agregar dos
  niveles** al JSON. Las cinco rutas nuevas traen 6, 6, 6, 4 y 4 niveles,
  contados a partir de su fuente oficial, no del diseño.

---

## 4. Bugs que encontré y corregí

Anotados porque son fáciles de volver a meter:

1. **Los assets en subdirectorios no se empaquetaban.** Flutter los ignora
   aunque declares la carpeta intermedia: de 76 assets solo se bundlaban 45 y el
   mapa salía en azul plano. Ahora están a un nivel, con una prueba que falla si
   alguien los anida.
2. **9 MB de assets muertos** en el APK. Ahora hay una prueba que los detecta.
3. **La app se quedaba en bienvenida** después de registrarse: la pantalla raíz
   no escuchaba los cambios de estado.
4. **El registro decía «puedes continuar sin registrarte»** mientras el botón te
   bloqueaba.
5. **El registro no cerraba** al terminar, dejando el formulario encima.
6. **El placeholder de los SVG era un spinner** que nunca se detenía, lo que
   rompía `pumpAndSettle` en los tests.

---

## 5. Ramas

`main` es la rama buena. Las otras cuatro remotas (`feat/music-library-*`,
`perf-optimization-round1`) son de otro proyecto o están sin integrar. Ver
`docs/INVENTARIO.md`.

**No hice commit.** Todo está en el working tree para que lo revises antes de que
exista un commit con cientos de archivos.

---

## 6. Pendientes del catálogo de modalidades (2026-09-29)

La app ya carga `assets/json/catalogo_modalidades.json`: 34 unidades, 137
modalidades, cada una con su fuente y su fecha. Lo que falta:

1. **La tesina está mal clasificada en 9 modalidades de 8 unidades** (FCP, FDERE,
   FECON, FENF, FESTO, FIQ ×2, FPSY, CRNO): apunta a la ruta `tesis` cuando el
   art. 7 la pone dentro de *asignatura optativa con créditos*. Hoy el alumno ve
   el trámite de tesis de la FCC en vez de la exposición ante jurado. Es el
   pendiente que más afecta a un alumno.
2. **Faltan identificadores de carrera y plan por unidad.** Van `null` en las
   137 modalidades porque ninguna fuente los trae, y por eso la Facultad de
   Medicina muestra sus 21 modalidades a cualquier alumno.
3. **Unas unidades no publican catálogo y otras tienen modalidades sin URL
   oficial.** El catálogo marca como «no publica catálogo» a FADMON, FABUAP,
   FCPS, **FFL**, FING, ICSH, IF, IFI y CRC, y como «sin fuente registrada» a
   FIQ, FESTO y FENF (18 modalidades). **Ojo con FFyL: ese estado es incorrecto**
   — `out/investigacion-g3.json` documenta un catálogo de 33 modalidades en 5
   licenciaturas (PDF de 2018, aprobado por su CUA el 6-feb-2018, enlazado hoy
   desde su Secretaría Académica) que se perdió al consolidar; hay que rehacer su
   fila y arreglar `build_catalog.py`, que es la causa de que también se perdieran
   FADMON y FABUAP. Detalle en `out/INFORME-MODALIDADES.md` §7.
4. **Sin arte propio**: las cinco rutas nuevas no tienen título, descripción,
   pergamino ni mascota del diseño, y sus mapas son PNG generados, no del zip.
   El zip de diseño además trae 7 carpetas vacías.
5. **Sin deltas por unidad**: `operaciones` va `[]` en las 137 modalidades; no se
   verificó ningún paso adicional que exija una unidad sobre su ruta base.
6. ~~**Tres pantallas escritas y probadas pero no conectadas**~~ — **ya están
   conectadas** (revisado el 2026-09-30; el documento decía todavía lo contrario).
   Elegibilidad (`lib/screens/eligibility_screen.dart`), notas por nivel
   (`lib/screens/notes_screen.dart`) y respaldo del avance
   (`lib/screens/backup_screen.dart`) se alcanzan hoy desde el menú hamburguesa:
   `lib/screens/menu_screen.dart` las importa (líneas 5-9) y ofrece una entrada
   para cada una (89-126), junto con contactos y directorio, y el menú se abre
   desde la portada (`lib/screens/home_screen.dart:223-233`). No queda nada por
   decidir sobre dónde van, y sus pruebas ya no son el único camino para
   llegar a ellas.
7. **Una errata en la fuente**: el mapa gráfico de Experiencia Profesional de la
   FCC trae «Se参加 en las Convocatorias…» con un carácter no latino. Se conservó
   la cita literal marcada como anomalía; hay que revisar el PDF original.
8. **Otros documentos del repo quedaron desactualizados** y no se tocaron en
   esta corrida porque no estaban en el encargo: `docs/TIENDA.md` («33
   facultades», «3 rutas»), `docs/DECISIONES.md` («8 de las 33 unidades») y
   `docs/INVENTARIO.md` («Elige tu ruta (3 rutas)»). `docs/PLAN.md` describe el
   plan original y se dejó como histórico.

Detalle y evidencia: `out/INFORME-MODALIDADES.md`.
