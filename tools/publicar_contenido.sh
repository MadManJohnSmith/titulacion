#!/usr/bin/env bash
# Firma y publica el catálogo de modalidades para que la app lo baje.
#
# La app solo instala contenido que viene con un manifiesto firmado por una
# clave en la que confía (Ed25519). Este script produce los dos archivos:
#
#   contenido/catalogo_modalidades.json  el catálogo tal cual
#   contenido/manifiesto.json             qué versión es, dónde está y su hash
#
# Lo que se firma es una cadena canónica, NO el archivo del manifiesto: el
# manifiesto contiene la firma, así que firmarlo entero sería autorreferente.
# La cadena es exactamente la que rebuilds `ManifiestoContenido.bytesFirmados`
# en lib/services/content_repository.dart:
#
#   loboapp-contenido-v1\n<version>\n<generado>\n<vence>\n<url>\n<sha256>\n
#
# Si cambias esa regla, hay que cambiarla en los dos lados o la app rechaza
# todo el contenido.
#
# Uso:
#   tools/publicar_contenido.sh <clave-privada.pem> <base-url> <destino> [vence]
set -euo pipefail

CLAVE="${1:?falta la clave privada PEM}"
BASE_URL="${2:?falta la URL base donde se publica}"
DESTINO="${3:?falta la directorio de destino}"
VENCE="${4:-}"

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
CATALOGO="$RAIZ/assets/json/catalogo_modalidades.json"
CLAVE_ID="loboapp-contenido-v1"

[ -f "$CLAVE" ]   || { echo "ERROR: no existe la clave $CLAVE" >&2; exit 1; }
[ -f "$CATALOGO" ] || { echo "ERROR: no existe $CATALOGO" >&2; exit 1; }

BASE_URL="${BASE_URL%/}"
URL_CONTENIDO="$BASE_URL/contenido/catalogo_modalidades.json"

mkdir -p "$DESTINO/contenido"
cp "$CATALOGO" "$DESTINO/contenido/catalogo_modalidades.json"

# SHA-256 del contenido tal como se sirve, en minúsculas.
SHA256=$(sha256sum "$DESTINO/contenido/catalogo_modalidades.json" | cut -d' ' -f1)

VERSION=$(/usr/bin/python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['catalogoVersion'])" "$CATALOGO")
GENERADO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Cadena canónica firmada: un salto de línea detrás de cada campo.
PAYLOAD="loboapp-contenido-v1
${VERSION}
${GENERADO}
${VENCE}
${URL_CONTENIDO}
${SHA256}
"
printf '%s' "$PAYLOAD" > "$DESTINO/.payload"

FIRMA=$(openssl pkeyutl -sign -rawin -inkey "$CLAVE" -in "$DESTINO/.payload" \
        | base64 -w0)
rm -f "$DESTINO/.payload"

[ -n "$FIRMA" ] || { echo "ERROR: la firma salió vacía" >&2; exit 1; }

/usr/bin/python3 - "$DESTINO/contenido/manifiesto.json" <<PY
import json, sys
manifiesto = {
    "catalogoVersion": """$VERSION""",
    "generadoEn": """$GENERADO""",
    "expiraEn": """$VENCE""",
    "urlContenido": """$URL_CONTENIDO""",
    "sha256": """$SHA256""",
    "firma": {
        "algoritmo": "Ed25519",
        "claveId": "$CLAVE_ID",
        "valorBase64": """$FIRMA""",
    },
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(manifiesto, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

echo "Contenido firmado: versión $VERSION"
echo "  contenido/contenido/catalogo_modalidades.json  (sha256 $SHA256)"
echo "  contenido/contenido/manifiesto.json             (clave $CLAVE_ID)"