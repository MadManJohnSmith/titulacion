# Aviso de privacidad — LoboApp

**Versión:** 1.0 · **Última actualización:** 29 de septiembre de 2026
**Responsable:** Benemérita Universidad Autónoma de Puebla (BUAP)

---

## En una frase

LoboApp **no recoge, no transmite y no comparte datos personales**. Todo se
queda en el teléfono donde se instala.

---

## Qué datos trae la app

La app incluye dos bases de datos de la BUAP **dentro del propio archivo de
instalación**:

| Base | Contenido | Tamaño |
|---|---|---|
| Alumnos | 318,374 matrículas y nombres | 2.9 MB comprimidos |
| Trabajadores | 43,025 matrículas y nombres | 0.6 MB comprimidos |

Estas bases van empaquetadas, no se descargan. **La app no puede modificarlas ni
enviarlas a ningún lado**, y no hay ningún servidor detrás.

### Qué se quitó a propósito

- **Los correos de los alumnos no están en la app.** La base original los traía;
  se eliminaron antes de empaquetar porque la app no los usa para nada.
- **Los correos personales de los trabajadores tampoco** (gmail, hotmail y
  similares). Solo se conservan los institucionales `@correo.buap.mx`, que la
  universidad ya publica en sus directorios.

### Aviso sobre la base de alumnos

Empaquetar el padrón de alumnos significa que **cualquiera que descargue la app
puede extraer la lista de matrículas y nombres**. Consideramos que es aceptable
porque:

1. La BUAP publica datos equivalentes en sus directorios públicos.
2. La app **no tiene la facultad asociada**, así que no permite saber qué
   unidad académica estudia cada persona.
3. La lista es de 2020 a 2025 y no incluye correos, teléfonos ni datos
   sensibles.

Aun así, si la BUAP prefiere no distribuirla, se puede dejar la base fuera
(borrando `assets/alumnos/`) y la app funciona igual: el alumno entra como
invitado. Ver "Cómo quitar la base" más abajo.

---

## Qué guarda la app en tu teléfono

Solo el **progreso de juego**, en el almacenamiento local del dispositivo:

- Tu nombre y matrícula (solo si te encontraste en la base)
- La unidad académica que elegiste
- Qué niveles completaste y qué documentos marcaste

Esto se guarda con `shared_preferences`, en el espacio privado de la app. **No se
envía a ningún servidor.** Si desinstalas la app, se borra.

## Qué hace la app con los enlaces

Al tocar un enlace o un correo, la app **te manda a otra app** (navegador,
cliente de correo o teléfono). A partir de ahí, esa otra app tiene sus propias
políticas de privacidad. LoboApp no interviene ni ve lo que haces ahí.

## Permisos que pide

| Permiso | Para qué | ¿Se usa? |
|---|---|---|
| Internet | Abrir enlaces y correos | Sí, al tocar un enlace |
| Consultar el teléfono | No se pide | — |

**No se pide** acceso a contactos, ubicación, cámara, micrófono, archivos ni
almacenamiento.

## Menores de edad

La app está pensada para mayores de edad en proceso de titulación. No recopila
información de menores.

## Tus derechos

Como los datos no salen de tu teléfono, borrarlos es tuyo y es inmediato:
**desinstalar la app**. Si quieres borrar solo el progreso sin desinstalar, en
la app: *Menú → Mi perfil → Cerrar sesión*.

Para cualquier duda sobre este aviso o sobre las bases incluidas, escribe a la
**Coordinación General de Atención a los Universitarios (CGAU)**:
+52 (222) 229 5500.

---

## Cómo quitar la base de alumnos de la app

Si la BUAP decide que el padrón no debe distribuirse:

1. Borra la carpeta `assets/alumnos/`.
2. Quita la línea `- assets/alumnos/` de `pubspec.yaml`.
3. Quita la pantalla de búsqueda del registro: en
   `lib/screens/register_screen.dart`, deja el botón siempre como
   "Continuar como invitado".

La app sigue funcionando completa; solo pierde la verificación de matrícula.
Lo mismo aplica a `assets/trabajadores/` para el directorio.

## Cambios a este aviso

Si cambia la base de datos incluida o se agrega alguna funcionalidad que
transmita información, se actualiza este documento y la versión de la app.
