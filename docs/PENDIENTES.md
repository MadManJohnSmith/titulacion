# Lo que falta para publicar LoboApp

Fecha: 2026-09-29. La app **compila, pasa las 37 pruebas y ya genera AAB y
APKs de release**. Lo de aquí son cosas que dependen de la BUAP o de una
decisión de ellos, no bugs.

---

## 1. Lo que necesito de la BUAP

### Validar el texto de los niveles — importante

El contenido salió de extraer el texto de un `.indd` binario, con los acentos
rotos (`n` = «ón», `s` = «á»). Reconstruí lo que pude, pero **alguien tiene que
compararlo contra el diseño antes de publicar**. Estos son los huecos que dejé
a propósito, sin inventar números:

| Dónde | Qué falta |
|---|---|
| `routes.json` → CENEVAL, nivel 3 | **Costo del acta de nacimiento actualizada.** El diseño dice «1?50 pesos» (un dígito se perdió al exportar). Casi seguro es $150, pero no lo puse porque un cobro mal puesto hace que un alumno vaya con el monto equivocado. |
| `routes.json` → Examen profesional, nivel 3 | «1 año para presentar la tesis» — **¿desde qué fecha se cuenta?** |
| `routes.json` → Examen profesional, nivel 4 | El **correo** donde se envían los documentos escaneados no aparece en el diseño |
| `routes.json` → Examen profesional, nivel 5 | La URL del formato de aval académico |
| Toda la app | Vigencia de cada documento (puse 3 meses para bibliotecas y 6 para el oficio, **según el diseño, pero confírmenlo**) |

### Correos de las 25 facultades que no los publican

La investigación encontró **8 con correo verificado** en el sitio oficial:
Administración, ARPA, Ciencias Políticas y Sociales, Estomatología,
Ingeniería Química, Lenguas, Medicina y Complejo Regional Centro.

Las otras 25 tienen el campo vacío: la app les cae al contacto general de la DAE
en vez de mostrar un correo inventado. **Si tienen los correos internos, van en
`facultades.json` y ya aparecen** — no hay que tocar código.

**Caso Arquitectura:** el código original traía hardcodeados a Maricarmen Lara y
`titulacion.fabuap@correo.buap.mx`, y **no se pudieron confirmar**. Están
marcados `confianza: "baja"`. Confírmalos o quítalos.

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

- **Mapas por ruta.** El zip de diseño tenía `Mapa agua` con archivo, pero
  `Mapa tierra` y `Mapa aire` estaban **vacías**. Asigné: promedio → tierra (la
  mascota es la deportiva), CENEVAL → aire (la mascota va con goggles de
  aviador), profesional → agua. Los de tierra y aire **los generé** con la
  paleta de cada ruta; no son arte de diseño.
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
- **Niveles por ruta: 7, 8 y 6.** El diseño no cuadra: hay 7 iconos de nivel,
  7 fondos de CENEVAL, 6 de profesional, 9 lobos y 9 EPS de texto. Usé lo que
  el contenido soportaba. **Si profesional debería tener 9, hay que agregar tres
  niveles** al JSON.

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
