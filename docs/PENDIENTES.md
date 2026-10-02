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

**Revisado el 2026-10-01** al cerrar la release **v1.3.0**: `flutter test` da
`+248: All tests passed!` y `flutter analyze` da `No issues found!`. La release
publicó los cuatro binarios de escritorio y móvil desde el tag `v1.3.0`, y CI
corrrió `flutter analyze --fatal-infos` en verde sobre ese mismo código. El
número de modalidades de la §6 también era impreciso: son **170** en total, de
las cuales 99 son jugables, 119 confirmadas y 18 quedan sin fuente registrada.

**Nota de versión:** la app cambió de 3 a 8 rutas y de 33 a 34 unidades, y el
alumno ahora elige una **modalidad** (con requisitos, fuente y fecha) en vez de
una ruta suelta. Los pendientes de ese trabajo están en §6 y el detalle
completo en `out/INFORME-MODALIDADES.md`.

**Revisado el 2026-10-01** al cerrar la release **v1.3.2**: `flutter test` da
`+248: All tests passed!` y `flutter analyze --fatal-infos` da
`No issues found!`. v1.3.1 es la primera firmada de forma permanente; v1.3.2
sigue esa misma clave y por lo tanto **sí se instala encima de v1.3.1 sin
desinstalar**. Lo único que añade sobre v1.3.1 son los directorios oficiales
recuperados con `dirsearch`: FCFM (26 personas), FPSY (coordinación de
Titulación) y CRS (16 responsables), con lo que el directorio pasa de 364
personas en 26 unidades a **407 en 29**, cada una con su URL de fuente y su
fecha de consulta.

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

- [x] **Firma permanente de Android** — resuelto para **v1.3.1**. Hasta v1.3.0
      el workflow firmaba cada release con la clave de depuración creada por
      el runner efímero de GitHub. Las huellas de v1.2.1 y v1.3.0 son distintas,
      así que Android no acepta una como actualización de la otra. Desde v1.3.1
      los APK se firman con el keystore permanente `loboapp-upload-v1`, guardado
      como secretos de GitHub, y el workflow comprueba la huella SHA-256,
      `applicationId`, `versionCode` y `versionName` antes de publicar.

      **Migración inevitable:** quien tenga instalada v1.3.0 o anterior debe
      desinstalarla una vez para instalar v1.3.1, y Android borrará el progreso
      local. De v1.3.1 en adelante las actualizaciones se instalan encima sin
      desinstalar, mientras se conserve el mismo keystore.

      La copia maestra quedó fuera del repositorio en
      `~/Documents/LoboApp-signing-backup/`; nunca subirla ni perderla.
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

**Ya está commiteado y publicado.** El 2026-10-01 el working tree se vació en
dos commits sobre `main` (`9cf6fd3` con el contenido y `669927b` con el salto a
1.3.0) y se publicó la release `v1.3.0` con los cuatro binarios. Esta nota se
queda porque las ramas que se mencionan arriba no se tocaron.

---

## 6. Pendientes del catálogo de modalidades (2026-09-29)

La app ya carga `assets/json/catalogo_modalidades.json`: 34 unidades, 137
modalidades, cada una con su fuente y su fecha. Lo que falta:

1. **La tesina está mal clasificada en 9 modalidades de 8 unidades** (FCP, FDERE,
   FECON, FENF, FESTO, FIQ ×2, FPSY, CRNO): apunta a la ruta `tesis` cuando el
   art. 7 la pone dentro de *asignatura optativa con créditos*. Hoy el alumno ve
   el trámite de tesis de la FCC en vez de la exposición ante jurado. Es el
   pendiente que más afecta a un alumno.
   **Parcialmente mitigado el 2026-10-01 (v1.3.0):** la app ya detecta el caso
   (nombre de modalidad con «tesina» sobre la ruta `tesis`) y muestra un aviso
   que explica la diferencia entre el art. 7 fr. I y el fr. VII y pide confirmar
   con la unidad. **No se reclasificó el mapeo**, porque hay universidades que
   usan «tesina» como nombre de una tesis corta y cambiarlo sin preguntar a
   esas 8 unidades sería afirmar algo que nadie comprobó. Para cerrarlo de
   verdad hay que preguntar a FCP, FDERE, FECON, FENF, FESTO, FIQ, FPSY y CRNO.
2. **Faltan identificadores de carrera y plan por unidad.** Van `null` en las
   137 modalidades porque ninguna fuente los trae, y por eso la Facultad de
   Medicina muestra sus 21 modalidades a cualquier alumno.
3. **Unas unidades no publican catálogo y otras tienen modalidades sin URL
   oficial.** Hoy el registro es de 14 unidades que **no publican catálogo** —
   FADMON, FABUAP, FCPS, FING, ICSH, ICGDE, IF, IFI, CRC, CRM, CRNO, CRN,
   CRS y BACH5M — y 18 modalidades con `estado: "sin_fuente_registrada"`. La
   app lo explica y deja el rastro de dónde se buscó, sin rellenar nada.
   **FFyL ya está corregido (2026-09-30):** publica catálogo con sus 33
   modalidades en 5 licenciaturas, leído del PDF de 2018 aprobado por su CUA el
   6-feb-2018. Su salvedad —que el catálogo es por licenciatura y no una lista
   única para la facultad— está en el JSON y ahora se muestra en pantalla.
   Lo que sigue pendiente es **`build_catalog.py`**, que es la causa de que
   FADMON y FABUAP perdieran su fila: todavía no reproduce el JSON actual.
   Detalle en `out/INFORME-MODALIDADES.md` §7.
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
7. ~~**Una errata en la fuente**~~ — **resuelto el 2026-09-30.** El mapa gráfico
   de Experiencia Profesional de la FCC traía «Se参加 en las Convocatorias…» con
   un carácter no latino. Se bajó el PDF original, se leyó la frase completa y
   quedó «Si ha participado en las Convocatorias de Titulación por Experiencia
   Profesional…». La versión corregida es la que se muestra hoy; una prueba
   (`test/enlaces_test.dart`) falla si vuelve a colarse un carácter de otra
   escritura.
8. ~~**Otros documentos del repo quedaron desactualizados**~~ — **corregido el
   2026-10-01.** `docs/TIENDA.md` describía 33 facultades y 3 rutas; ahora dice
   34 unidades y 170 modalidades con sus 8 rutas base. `docs/DECISIONES.md`
   decía «8 de las 33 unidades» con correo verificado; ahora son 22 de 34.
   `docs/INVENTARIO.md` enumeraba archivos que ya no existen, así que se
   encabezó como foto histórica del 2026-09-28, con su §3 marcada como
   lo que decía ese día y no como estado actual. `docs/PLAN.md` describe
   el plan original y se dejó como histórico.

Detalle y evidencia: `out/INFORME-MODALIDADES.md`.

---

## 7. Auditoría de contenido y trazabilidad (2026-10-01, v1.3.0)

La revisión que precedió a la release encontró una pauta que se repitió:
había datos verificados en el JSON que **ninguna pantalla mostraba**. No
faltaba información; la información existía y se perdía entre el archivo y el
alumno.

### Resuelto

1. **Enlaces que no respondían.** `estadoEnlace` y `notaEnlace` estaban
   escritos en 63 lugares y ningún modelo Dart los leía: el botón «Abrir
   documento oficial» salía igual para un PDF vivo y para un servidor caído.
   Ahora el estado llega a la pantalla, la fila solo abre lo comprobado y el
   botón sin comprobar se rotula «Reintentar el enlace». Dos documentos ni
   siquiera declaraban su enlace muerto.
2. **Requisitos por unidad invisibles.** Las 114 `particularidadesPorUnidad`
   se armaban y se cargaban en `RutaOferta.particularidad`, pero ninguna
   pantalla las pintaba. Ahora aparecen con la cita oficial, el estado de
   publicación de la unidad y su fuente.
3. **El resto de la metadata descartada:** `mapaNota`,
   `fuenteDeParticularidades`, `articuloAplicado`, `fuenteCatalogo`,
   `salvedad`, `textoPublicacion`, `citaFuente`, `notaContacto`,
   `enlaceRetirado`, `sinEnlace` y la página del directorio con su fecha.
   Se comprobó con un barrido que de las 138 claves del JSON solo queden 10
   sin leer, y se verificó una por una que están vacías o duplicadas en el
   catálogo que la app sí consume.
4. **Directorio sin fuente.** `DirectorioUnidad` leía `url` y `consultadoEn`
   y guardaba solo la lista de personas: la app mandaba a un cubículo
   concreto sin decir de dónde salió.
5. **Rastros incompletos.** Cuatro unidades (FENF, FESTO, FFL, FIQ) solo
   tenían su rastro de búsqueda en `facultades.json` y no en el catálogo que
   la app lee, así que decían «sin fuente registrada» sin decir dónde
   buscó. Se completaron 12 registros.
6. **Errata de transcripción** en una ubicación de la FADMON («Edficio» →
   «Edificio»). La página oficial no respondió al reintentarla, así que la
   corrección quedó **declarada** en ambas fuentes en vez de darse por
   verificada.

### Pendiente

7. **Confirmar con ocho unidades qué es una tesina en su caso.** Ver §6.1.
   La app avisa; el mapeo sigue apuntando a `tesis`.
8. **Reintentar los cuatro enlaces caídos desde otra red:** `mederi.buap.mx`,
   `webserver.siiaa.siu.buap.mx`, `des.buap.mx/?q=…` (403) y
   `autoservicios.buap.mx` (503). Todos respondieron igual desde esta red.
9. **`build_catalog.py` y `build_assets.py` ya no reproducen el JSON
   actual.** Correrlos perdería el directorio, el catálogo de FFyL, las 114
   particularidades y todo lo de esta sesión. Nadie los ha ejecutado desde el
   2026-09-29. **Sigue pendiente: lo correcto es borrarlos o marcarlos como
   obsoletos**, porque son el camino más fácil para perder datos sin darse
   cuenta.
10. **`assets/json/directorios.json` está huérfano.** Su contenido está
    embebido en `facultades.json` y el archivo no lo lee nadie. Hoy es
    inocuo porque se comprobó que coinciden en las 29 unidades, pero es una
    fuente duplicada que puede divergir sin que nada lo note.
11. **5 unidades sin directorio** y **0 de 137 modalidades** con carrera o
    plan publicados: sin fuente oficial, la app no los inventa. El
    2026-10-01 se usó `dirsearch` con una lista acotada y dos hilos sobre
    hosts públicos de la BUAP: se recuperaron FCFM (26 personas), FPSY
    (contacto de Coordinación de Titulación) y CRS (16 responsables). Siguen
    sin directorio FCEL, FCP, IF, CRNO y BACH5M. En FCP se encontró el PDF
    oficial «Directorio 2025», pero es una lámina de una página cuya
    extracción mezcla nombres, correos y cargos; no se importó para no
    atribuir datos a la persona equivocada.
