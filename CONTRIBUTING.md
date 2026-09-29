# Contribuir a LoboApp

¡Gracias por el interés! Cualquier ayuda es bienvenida: reportar errores,
confirmar información de la BUAP, o proponer código.

## Antes de abrir un issue

- **Errores de información** (un requisito, un costo, un correo que cambió):
  indica la fuente oficial de la BUAP donde aparece el dato correcto. La app
  no inventa contactos: si algo está vacío es porque no hay fuente verificada.
- **Bugs de la app**: describe qué hiciste, qué esperabas y qué pasó. Si es
  visual, una captura ayuda muchísimo.

## Cambios de código

1. Haz un fork y crea una rama desde `main`.
2. Sigue las reglas del proyecto:
   - **Todo el contenido vive en `assets/json/`** — no hardcodees requisitos,
     contactos ni textos en Dart.
   - **Los assets van a un solo nivel** dentro de su carpeta (Flutter no
     empaqueta subdirectorios aunque declares la carpeta padre).
   - Evita `print()` y dependencias nuevas sin discusión previa en un issue.
3. Antes de abrir el PR, verifica que pasen los tres chequeos:

   ```bash
   flutter analyze   # No issues found!
   flutter test      # todas las pruebas en verde
   ```

4. Abre el PR describiendo qué cambia y por qué. Si toca `assets/json/`,
   menciona la fuente de la información.

## Agregar o corregir información de una facultad

No hace falta saber programar: abre un issue con el correo/telefono/encargado
de titulación de tu facultad **con su fuente oficial** (sitio BUAP, oficio, o
publicación institucional) y se actualiza `facultades.json`.

## Privacidad

Nunca agregues al repositorio datos personales que no estén ya publicados por
la BUAP (correos personales, números de teléfono privados, etc.). La base de
alumnos que trae la app solo contiene matrícula y nombre, y así debe quedarse.
Ver [docs/PRIVACIDAD.md](docs/PRIVACIDAD.md).

## Sobre la licencia

El proyecto es **todos los derechos reservados** (ver [LICENSE.md](LICENSE.md)):
el código es público para consultarlo, pero no para copiarlo ni reutilizarlo.
Al abrir un pull request aceptas que tu contribución pase a ser parte del
proyecto bajo esos mismos términos.
