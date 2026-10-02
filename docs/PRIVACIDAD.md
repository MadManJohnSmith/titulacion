# Aviso de privacidad — LoboApp

**Versión:** 2.0 · **Última actualización:** 1 de octubre de 2026
**Responsable:** Benemérita Universidad Autónoma de Puebla (BUAP)

---

## En una frase

LoboApp **no recoge, no transmite y no comparte datos personales tuyos**. Lo que
escribes se queda en el teléfono donde se instala.

---

## La app no trae bases de datos de personas

Hasta la versión 1.3.2 el archivo de instalación incluía dos padrones de la
BUAP: 318,374 matrículas y nombres de alumnos, y 43,025 matrículas, nombres y
correos institucionales de trabajadores. **Se quitaron a partir de la
1.4.0.** Ninguno de los dos se distribuye ya, ni en los binarios ni en la demo
web.

El motivo es que empaquetarlos hacía que **cualquiera que descargara la app
pudiera extraer la lista completa** sin dejar rastro, y no había forma de dar
acceso controlado a esa información. El argumento de que "la BUAP ya publica
datos equivalentes" no se sostenía: los directorios públicos dan unas cientos
de personas con cargo y ubicación, no cuatrocientas mil sin cargo ni unidad.

### Qué hace la app en su lugar

- **Tu nombre y tu matrícula los escribes tú.** No hay búsqueda ni verificación:
  la app no consulta ningún padrón, así que lo que escribes es lo que se guarda.
  La matrícula solo se revisa por su forma (9 dígitos).
- **El directorio que sí incluye es el que las unidades publican** para poder
  ser contactadas: 407 personas en 29 unidades, con su puesto, su ubicación,
  su correo institucional y su teléfono, y con la URL de la fuente y la fecha
  en que se consultó. Es información publicada con ese propósito.
- **Ya no existe la búsqueda general de trabajadores**, porque solo podía
  alimentarse del padrón que se quitó.

## Qué guarda la app en tu teléfono

Solo el **progreso**, en el almacenamiento local del dispositivo:

- Tu nombre y matrícula, si los escribiste
- La unidad académica que elegiste
- Qué niveles completaste y qué documentos marcaste
- Tus notas

Esto se guarda con `shared_preferences`, en el espacio privado de la app. **No se
envía a ningún servidor.** Si desinstalas la app, se borra.

## Qué hace la app con los enlaces

Al tocar un enlace o un correo, la app **te manda a otra app** (navegador,
cliente de correo o teléfono). A partir de ahí, esa otra app tiene sus propias
políticas de privacidad. LoboApp no interviene ni ve lo que haces ahí.

## Conexiones que hace la app por su cuenta

La app hace **una sola petición automática**, y solo en contenido público:

| A dónde | Qué pide | Para qué |
|---|---|---|
| `madmanjohnsmith.github.io` | Un manifiesto y el catálogo de modalidades | Actualizar los requisitos de titulación sin sacar una versión nueva |

**No se envía nada de tu dispositivo en esa petición**: no se manda tu nombre,
tu matrícula, tu unidad ni tu avance. Solo se descarga contenido oficial de la
BUAP para que la app no enseñe requisitos vencidos.

Ese contenido va **firmado con una clave Ed25519** y la app **comprueba la
firma** contra una clave pública que va dentro de la app. Si alguien cambia el
manifiesto por el camino, la firma deja de cuadrar y la app conserva el
catálogo anterior. Del hash y de la firma se ocupa `tools/publicar_contenido.sh`.

## Permisos que pide

| Permiso | Para qué | ¿Se usa? |
|---|---|---|
| Internet | Abrir enlaces y correos; bajar el catálogo firmado | Sí |
| Consultar el teléfono | No se pide | — |

**No se pide** acceso a contactos, ubicación, cámara, micrófono, archivos ni
almacenamiento.

## Menores de edad

La app está pensada para mayores de edad en proceso de titulación. No recopila
información de menores.

## Tus derechos

Como tus datos no salen de tu teléfono, borrarlos es tuyo y es inmediato:
**desinstalar la app**. Si quieres borrarlos sin desinstalar, en la app:
*Menú → Mi perfil → Cerrar sesión*.

**Cerrar sesión borra todo lo que la app guardó de esa sesión**: tu registro,
tu unidad académica, tu contexto académico, la modalidad que habías elegido, tu
avance (niveles completados y documentos marcados, de todas las modalidades) y
tus notas. Después de eso la app queda como recién instalada, así que la
siguiente persona que se registre en ese teléfono empieza en cero y no ve nada
de la anterior.
**Registrar a otra persona no borra lo anterior**: el avance y las notas se
guardan por modalidad y no por persona, así que si registras a otra persona en
la misma unidad y elige la misma modalidad, verá los niveles completados, los
documentos marcados y las notas que había. La app te avisa antes de cambiar el
registro y te recuerda la salida: **Cerrar sesión**. Desinstalar la app borra
todo, también lo de la otra persona.

Lo que **no** se borra con ese botón es el contenido de la propia app (catálogo,
rutas y directorio), porque no es dato personal tuyo. Para borrarlo hace falta
desinstalar la app.

Para cualquier duda sobre este aviso, escribe a la **Coordinación General de
Atención a los Universitarios (CGAU)**: +52 (222) 229 5500.

---

## Historial

- **1.0 (29 de septiembre de 2026).** Documentaba la app con los dos padrones
  empaquetados y sus justificaciones.
- **2.0 (1 de octubre de 2026).** Los padrones se eliminaron del paquete. Se
  cambió el registro a escritura manual y se retiró la búsqueda general de
  trabajadores. Se añadió la sección de conexión al catálogo firmado.

## Cómo evitar que vuelvan

`test/data_test.dart` tiene pruebas que fallan si reaparecen `assets/alumnos`,
`assets/trabajadores` o cualquier `.tsv.gz`, si `pubspec.yaml` vuelve a
declararlos, y si `lib/` vuelve a usar `StudentRepository` o `StaffRepository`.
Esas pruebas son la razón por la que esto no se repite por descuido.