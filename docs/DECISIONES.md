# Decisiones de diseño técnico

Notas internas para quien mantenga o contribuya al código. Son las razones
detrás de cosas que de otra forma parecerían raras.

## Los assets viven a un solo nivel

Flutter no empaqueta los archivos que están en subdirectorios aunque declares
la carpeta intermedia en `pubspec.yaml`. Por eso los fondos se llaman
`levels_ceneval_bg_1.svg` y no `levels/ceneval/bg_1.svg`. Hay una prueba en
`test/app_flow_test.dart` que falla si alguien anida assets de nuevo.

## El placeholder de los SVG es estático

`AssetImageSafe` muestra un rectángulo del color del tema mientras carga, no
un `CircularProgressIndicator`: un spinner nunca termina de girar mientras el
asset carga y eso rompe `pumpAndSettle` en los tests de widgets.

## Fuentes: Poppins, Bungee y Tajawal — no Bungee Spice

El prototipo original usaba Bungee Spice en los pergaminos, pero su archivo
no lo rasteriza bien el motor de Flutter (salía con el glifo de respaldo en
naranja) y pesaba 8 veces más que Bungee. Los títulos de pergamino van en
Bungee plano.

## Los contactos sin fuente verificada están vacíos

22 de las 34 unidades académicas publican un correo de titulación que se haya
podido verificar; esas 22 van con `confianza: "alta"`. Las otras 12 tienen el
correo vacío y la app muestra el contacto general de la DAE en su lugar, en
vez de inventar un correo. Agregar los faltantes es solo editar
`facultades.json`.

## Cada ruta tiene su mapa

El mapa de agua venía en el zip de diseño. Los de tierra y aire estaban vacíos
en el diseño, así que se generaron con la paleta de cada ruta para que las
rutas tengan el mismo nivel de pulido. Hoy las ocho rutas de `routes.json`
comparten uno de esos tres mapas: cada una declara en `mapaNota` por qué usa
ese y cuáles carpetas del diseño vinieron vacías, para que el fondo no se
presente como arte propio cuando no lo es.

## La base de alumnos va partida por cohorte

318,374 registros comprimidos en archivos por prefijo de matrícula (el
prefijo de 4 dígitos codifica el año de ingreso). Buscar por matrícula
descomprime un solo archivo; buscar por nombre carga la base completa. El
pipeline que la genera está en `tools/generar_bases.py` y es reproducible
byte por byte (ver `tools/README.md`).

## Privacidad en los datos

Se excluyeron a propósito: los correos de los alumnos (la app no los usa) y
los correos personales de los trabajadores (solo se conservan los
`@correo.buap.mx`). Ver `PRIVACIDAD.md`.
