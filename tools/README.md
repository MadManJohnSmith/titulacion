# Regenerar las bases de datos de la app

Las bases que van dentro del APK salen de los `.db` que entregó la BUAP. Este
script las vuelve a generar cuando cambien.

## Entradas

Los archivos originales van en `/home/alan/Downloads/`:

- `buap_registros.db` — tabla `alumnos`: 318,374 filas (matrícula, paterno,
  materno, nombre, email)
- `buap_trabajadores.db` — tabla `trabajadores`: 43,025 filas (misma estructura)

## Uso

```bash
cd titulacion
python3 tools/generar_bases.py
```

## Qué hace

1. **Alumnos**: agrupa por cohorte (los 4 primeros dígitos de la matrícula) y
   escribe un `.tsv.gz` por año en `assets/alumnos/`. Cada línea es
   `matrícula<TAB>APELLIDOS NOMBRES`. **Quita el correo**: la app no lo usa.
2. **Trabajadores**: un solo `trabajadores.tsv.gz` con
   `matrícula<TAB>NOMBRE<TAB>correo`, y **solo conserva el correo si termina en
   `@correo.buap.mx`**. Los personales (gmail, hotmail) se descartan.
3. Escribe los `index.json` con el conteo y los tamaños, que la app usa para
   saber qué archivos existen.

## Por qué comprimidas y partidas

Las dos bases juntas son 3.5 MB comprimidos. Partir la de alumnos por cohorte es
lo que permite que la app sea ligera: al buscar una matrícula, el prefijo de 4
dígitos dice cuál de los 6 archivos descomprimir, en vez de los 318 mil
registros. Buscar por nombre sí carga todo.

## Cuidado

Este script **borra y reescribe** `assets/alumnos/` y `assets/trabajadores/`.
No borra nada fuera de esas dos carpetas.

Si la base cambia, después hay que correr `flutter test`: la suite
`test/data_test.dart` valida los conteos, que no haya correos personales y que
las matrículas no estén duplicadas.
