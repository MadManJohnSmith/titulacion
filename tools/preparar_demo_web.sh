#!/usr/bin/env bash
# Compila la demo web de LoboApp.
#
# Antes este script sacaba `assets/alumnos/` y `assets/trabajadores/` del
# bundle porque eran bases de datos de personas. Ya no existen en el proyecto:
# la app no distribuye ningún padrón, ni en la demo ni en los binarios. Queda
# solo el base-href que GitHub Pages necesita para servir el bundle.
#
# Uso:  tools/preparar_demo_web.sh [nombre-del-repo]
#       (el nombre define el base-href para GitHub Pages; default: titulacion)
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="${1:-titulacion}"
BASE_HREF="/${REPO}/"

flutter build web --release \
  --dart-define=DEMO_WEB=true \
  --base-href="$BASE_HREF"

rm -rf build/demo-web
mv build/web build/demo-web
echo "Demo lista en build/demo-web (base-href $BASE_HREF)."
