#!/usr/bin/env bash
# Compila la demo web de LoboApp SIN las bases de datos.
#
# La demo de GitHub Pages no debe exponer el padrón de alumnos como archivos
# descargables, así que este script saca `assets/alumnos/` y
# `assets/trabajadores/` del bundle, deja índices vacíos en su lugar y
# compila con DEMO_WEB=true para que los buscadores muestren su aviso.
# Al final restaura las bases y deja el resultado en build/demo-web/.
#
# Uso:  tools/preparar_demo_web.sh [nombre-del-repo]
#       (el nombre define el base-href para GitHub Pages; default: titulacion)
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="${1:-titulacion}"
BASE_HREF="/${REPO}/"

if [ ! -d assets/alumnos ] || [ ! -d assets/trabajadores ]; then
  echo "ERROR: no encuentro assets/alumnos o assets/trabajadores." >&2
  exit 1
fi

restaurar() {
  rm -rf assets/alumnos assets/trabajadores
  mv build/.bases/alumnos assets/alumnos
  mv build/.bases/trabajadores assets/trabajadores
  rmdir build/.bases
}
trap restaurar EXIT

mkdir -p build/.bases
mv assets/alumnos build/.bases/alumnos
mv assets/trabajadores build/.bases/trabajadores
mkdir -p assets/alumnos assets/trabajadores
echo '{"cohorts": {}}' > assets/alumnos/index.json
echo '{"archivo": ""}' > assets/trabajadores/index.json

flutter build web --release \
  --dart-define=DEMO_WEB=true \
  --base-href="$BASE_HREF"

rm -rf build/demo-web
mv build/web build/demo-web
echo "Demo lista en build/demo-web (base-href $BASE_HREF, sin bases de datos)."
