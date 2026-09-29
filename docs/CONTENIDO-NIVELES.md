# Contenido de niveles — extraído del `.indd`

> **⚠️ ESTO ES UN BORRADOR.** El texto salió de un binario de InDesign con los
> acentos rotos (`n`=«ón», `s`=«á», `l`=«»). Hay que validarlo contra el diseño
> antes de usarlo. Marqué con `[?]` lo que no pude reconstruir.

Fuente: `EDITORIAL parte yuu con cambios -.indd` (4.2 MB, 19 may 2025).
Complementar con los títulos de los SVG del zip (117 archivos).

---

## ESTADO REAL (actualizado 2026-09-29)

Lo de abajo es la extracción del `.indd` y sigue siendo el texto **sin validar**.
Lo que la app carga hoy es otra cosa, y vive en `assets/json/routes.json` y
`assets/json/catalogo_modalidades.json`. Contados hoy sobre esos archivos:

| | Rutas | Niveles | Pasos | Documentos |
|---|---|---|---|---|
| Las 3 rutas del `.indd` (sin cambios en esta corrida) | 3 | 24 | 54 | 49 |
| Total en la app hoy | **8** | **50** | **86** | **78** |

| Ruta | Niveles en la app | Origen del contenido | Estado de la fuente |
|---|---|---|---|
| `promedio` | 8 | `.indd` (sin validar) | Sin fuente oficial; `fuente` y `fechaFuente` en `null` |
| `ceneval` | 9 | `.indd` (sin validar) | Sin fuente oficial; `fuente` y `fechaFuente` en `null` |
| `profesional` | 7 | `.indd` (sin validar) | Sin fuente oficial; 0 particularidades por unidad |
| `tesis` | 6 | Mapa Gráfico – Titulación Tesis, FCC | Fuente oficial consultada 2026-09-29 |
| `diplomado` | 6 | Mapa Gráfico – Titulación Diplomado, FCC | Fuente oficial consultada 2026-09-29 |
| `experiencia-profesional` | 6 | Mapa Gráfico – Titulación Experiencia Profesional, FCC | Fuente oficial consultada 2026-09-29 |
| `seminario` | 4 | Seminario de Titulación, ARPA | Fuente oficial consultada 2026-09-29 |
| `asignatura-optativa` | 4 | Titulación por Materia Optativa de Emprendimiento, FCP | Fuente oficial consultada 2026-09-29 |

Lo que cambia respecto a este borrador:

1. **Los conteos de niveles del diseño no cuadran con los que la app usa.** El
   diseño es inconsistente (7 iconos de nivel, 7 fondos de CENEVAL, 6 de
   profesional, 9 lobos, 9 EPS de texto) y la app quedó en 8 / 9 / 7. La
   pregunta 1 del final sigue abierta, pero ya no bloquea: los pasos y documentos
   del `.indd` se conservaron tal cual.
2. **Las cinco rutas nuevas** (tesis, diplomado, experiencia-profesional,
   seminario, asignatura-optativa) **no aparecen en este documento**: su texto
   viene de una fuente oficial de la unidad, no del `.indd`.
   Sus pasos y documentos están en `routes.json`, no aquí.
3. **Lo que exige cada unidad ya no está en las rutas**: vive en
   `particularidadesPorUnidad` de cada ruta y en `catalogo_modalidades.json`,
   con fuente y fecha por modalidad (137 modalidades, 34 unidades). Ver
   `out/INFORME-MODALIDADES.md`.
4. **Arte:** las cinco rutas nuevas no tienen título, descripción ni pergamino
   propios; usan `lobo_aviador.svg`, `level_icons/nivel_1..5.svg` y
   `mascot_profesional_lobo_1..5.svg`, y su `mapa` es un PNG generado, no arte
   del diseñador.

---

## RUTA A — Titulación por Promedio

Niveles: 7 (según `Mapas/Iconos de niveles p-mapa agua y tierra/Icono nivel 1..7`
y `Niveles Examen CENEVAL/Fondos/Fondo nivel 1..7 examen ceneval.svg`).
Mascotas: `Mascota inicio`, nivel 1 y 7, 2, 3, 4, 5, 6, `Mascota final`.

### Descripción general (ya está en la app, `promedio_screen.dart`)

> "Bienvenido valiente estudiante, felicidades por llegar a este punto sin haber
> reprobado, sin haber recursado ninguna materia y sin haber pedido permiso por
> baja temporal. Ahora solo queda terminar tu proceso de titulación, es momento
> de empezar el vuelo hacia tu título profesional, reúne tus documentos y vuela
> por los cielos de tu proceso final."

### Documentos (lista final del nivel 7 / "titulación por promedio")

Extraído literal del `.indd`:

1. Certificado de Servicio Social.
2. Certificado de estudios.
3. Certificado de estudios original de licenciatura.
4. Oficio original de titulación por promedio, con antigüedad no mayor a [?] meses.
5. Certificado de liberación de bibliotecas, VIGENTE y con una antigüedad no mayor a 3 meses.
6. Ficha de depósito bancario por concepto de acta de titulación automático.
7. Título profesional en ORIGINAL y DOS COPIAS.
8. Comprobante de la encuesta a egresados IMPRESO.

> Nota: en el texto sale "acta de titulaci**ó**n autom**á**tico" — pareceshould ser
> "automática". Confirmar.

### Pasos por nivel (reconstrucción del flujo)

Los pasos sueltos que aparecen en el `.indd` mapped así:

| Nivel | Acción | Título SVG correspondiente |
|---|---|---|
| 1 | Contacta a tu académico que funge como tutor de servicio social para que pueda calificar la materia. Ruta: autoservicios > servicios al alumno > registro escolar > servicio social y práctica profesional. Contacta al Coordinador de Práctica Profesional Crítica de tu Unidad Académica para que genere la carta de término digital. | `Titulo certificado de ss` |
| 2 | Si no eres egresado de la BUAP tendrás que conseguir la reliquia: contactar a un académico de titulación. | `Titulo acta de nacimiento actualizada` |
| 3 | Datos del acta de nacimiento y la CURP deben coincidir en su totalidad. El acta debe indicar la entidad de registro. Para alumnos registrados después de su nacimiento, presentar constancia de extemporaneidad del Registro Civil. Carta de naturalización: original y copia a color. | `Titulo formato original de certificado de estudios` |
| 4 | Obtener/actualizar el acta de nacimiento por el sitio oficial del Gobierno de Puebla. Capturar datos registrales, CURP, RFC, razón social, nombre y correo. Generar referencia y pagar (costo 1[?]50 pesos — **verificar, probablemente $150**). Confirmado el pago, en 72 h llega por correo el PDF certificado. Descargar e imprimir. | `Titulo impresion de CURP certificada` |
| 5 | Entrar a tu cuenta en **www.autoservicios.buap.mx** y seguir el manual de usuario. Si ya completaste el 100% del plan de estudios,_realiza el trámite de certificado de estudios. Escanear la póliza y el voucher por constancia de estudios (la póliza se genera desde autoservicios). Consultar el manual de escaneo. | `Titulo certificado de estudios` |
| 6 | Pago de derechos del Título Profesional en ventanilla bancaria, depósito a nombre de la Benemérita Universidad Autónoma de Puebla, DAE. **Conservar el folio.** Presentar identificación oficial + comprobante de pago. Certificados con emisión de 1997 o anteriores: entrega más lenta [?]. | `Titulo voucher de pago de derechos de titulo` |
| 7 | Entregar la lista final de 8 documentos. | `Texto final` |

**Cierre de ruta:** "Sea solo o acompañado lo lograrás, gracias a tu esfuerzo y dedicación."

---

## RUTA B — Examen CENEVAL

Niveles: 7 + final. Fondos: `Fondo nivel 1..7`, `Fondo examen ceneval`,
`Fondo final examen ceneval`.

### Documentos (lista final)

1. Cita previa.
2. Identificación oficial vigente.
3. Constancia de la CURP.
4. Acta de nacimiento en original y actualizada.
5. Certificado de Estudios completos de preparatoria o bachillerato.
6. Formato original de Validación del Certificado de Estudios de preparatoria o bachillerato.
7. Certificado de Estudios original de Licenciatura.
8. Certificado de liberación de Servicio Social.
9. Voucher de pago de derechos del Título Profesional.
10. Dos fotografías. [?] (el texto se corta: "Dos fotograf...")
11. Comprobante de la encuesta a egresados.

**Cierre:** "¡Felicidades, ya eres un profesional!"

---

## RUTA C — Examen Profesional

Niveles: 6 (fondos: `nivel 1`, `nivel 2_nivel 3_nivel 4`, `nivel 5`, `nivel 6`).
Mascotas: `lobo 1..9` (¡9 lobos para 6 niveles? ver nota).

### Documentos por nivel (reconstrucción)

| Nivel | Contenido |
|---|---|
| 1 | **Equipo de tesis.** Llena y firma el formato de registro de tesis con tu director. Personas clave: Director de Tesis + 2 asesores (serán sinodales). Recompensa: acceso al Examen profesional. |
| 2 | **Carta de separación de equipo.** Presentar la carta de separación de equipo. Requisito: INE de cada integrante. Recompensa: acceso al Examen profesional. |
| 3 | **Aval Académico.** Obtener la aceptación y firma del Formato de Aval Académico. Una vez sellado, calcular fecha y hora del Examen (mínimo 15 días después de la autorización de la tesis, con todos los documentos en orden). Tiempo límite: 1 año para presentar la tesis tras el registro, con prórroga de hasta 6 meses. |
| 4 | **Examen.** Reunir: Tesis en digital · Portada de la tesis (PDF o JPG) · Certificado de servicio social · Certificado de preparatoria · Certificado de estudios · Acta de nacimiento · Certificado de no adeudo bibliotecario · Carta de separación de equipo · INE de cada integrante. Se presenta por plataforma virtual o presencial. Se graba y se envía a la Coordinación como evidencia. |
| 5 | **Biblioteca / depósito de tesis.** Entrar a la Plataforma de la Dirección General de Bibliotecas: `https://bdigital.buap.mx/user_services_beta/certificate/wizard` con: la tesis autorizada por tu director (PDF y WORD) y el formato de aval académico con fecha, hora de examen y sello de la secretaría académica. Consultar cita para la documentación. |
| 6 | **Envío del expediente.** Enviar todos los documentos escaneados al correo [?]. Una vez validado, recibes instrucciones finales y la confirmación de tu titulación. |

**Cierre:** "Ya casi lo lograron, solo esperen un correo de confirmación para poder
recibir tu logro final. ¡Listo, lo conseguiste!"

---

## Datos transversales (de la pantalla de contactos)

- CGAU BUAP: +52 (222) 229 5500 · jorge.avelinos@correo.buap.mx
- Redes: Facebook "CGAU BUAP", Instagram @cgaubuap
- Titulación Facultad de Arquitectura: Maricarmen Lara · titulacion.fabuap@correo.buap.mx
- DAE: Víctor (Departamento de Titulación) · +52 (221) 256 998

## Cosas a confirmar contigo

1. **¿Cuántos niveles tiene cada ruta?** El diseño es inconsistente: hay 7 iconos
   de nivel, 7 fondos CENEVAL, 6 fondos profesionales pero **9 lobos** y 9 EPS de
   texto. ¿Profesional son 6, 7 o 9?
2. **Costo del acta**: sale "1?50 pesos" — ¿$150?
3. **Correo de envío del expediente profesional**: no aparece en el `.indd`.
4. **Plazos**: "antigüedad no mayor a ? meses", "1 año + prórroga de 6 meses",
   "certificados 1997 o anteriores". Faltan números.
5. **¿Los 9 lobos** son 9 niveles o 6 niveles + 3 estados (bloqueado/activo/hecho)?

**Estado de estas preguntas (2026-09-29):** la 1 y la 5 siguen abiertas y solo la
BUAP o el diseñador las cierran; la app no depende de ellas porque los pasos y
documentos del `.indd` se conservaron tal cual. La 2, la 3 y la 4 **no se
inventaron**: los campos que no se pudieron reconstruir siguen con `[?]` o
`null` en `routes.json` y la app los muestra como «no publicado». Además, el
catálogo por unidad (`assets/json/catalogo_modalidades.json`) sí trae requisitos
verificados para 137 modalidades con su fuente y su fecha, así que varias de
estas preguntas ya tienen respuesta **por unidad** aunque el diseño siga sin
resolverlas; el detalle está en `out/INFORME-MODALIDADES.md`.
