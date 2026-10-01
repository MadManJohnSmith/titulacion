#!/usr/bin/env python3
"""Descubre rutas públicas de unidades BUAP con dirsearch y deja evidencia.

No modifica el contenido de la app. Produce reportes JSON para revisión manual:
dirsearch encuentra páginas; una persona tiene que abrirlas y copiar solo lo que
la unidad publica literalmente. Está deliberadamente acotado a hosts oficiales,
una lista pequeña y dos hilos para no hacer una exploración agresiva.

Requisitos:
  git clone https://github.com/maurosoria/dirsearch /tmp/dirsearch
  python -m venv /tmp/dirsearch-venv
  /tmp/dirsearch-venv/bin/pip install -r /tmp/dirsearch/requirements/runtime.txt

Uso:
  /tmp/dirsearch-venv/bin/python tools/descubrir_con_dirsearch.py \
    --dirsearch /tmp/dirsearch --salida /tmp/lobo-dirsearch
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

PALABRAS = (
    "directorio directorio/ directorio-de-personal directorio-de-personal/ "
    "directorio-personal directorio-personal/ personal personal/ "
    "personal-academico personal-academico/ personal-administrativo "
    "personal-administrativo/ autoridades autoridades/ directivos directivos/ "
    "academicos academicos/ docentes docentes/ profesores profesores/ "
    "contacto contacto/ contactos contactos/ organigrama organigrama/ "
    "organizacion organizacion/ secretaria-academica secretaria-academica/ "
    "secretaria-administrativa secretaria-administrativa/ coordinaciones "
    "coordinaciones/ coordinadores coordinadores/ titulacion titulacion/ "
    "modalidades modalidades/ modalidades-de-titulacion "
    "modalidades-de-titulacion/ opciones-de-titulacion "
    "opciones-de-titulacion/ proceso-de-titulacion proceso-de-titulacion/ "
    "requisitos-de-titulacion requisitos-de-titulacion/ egresados egresados/ "
    "servicios servicios/ tramites tramites/ nosotros nosotros/ "
    "content/directorio content/directorio/ content/directivos "
    "content/directivos/ content/secretaria-academica "
    "content/secretaria-academica/ content/titulacion content/titulacion/ "
    "coords/directorio coords/directorio/ coords/titulacion coords/titulacion/"
).split()

# Solo hosts institucionales de unidades con un hueco conocido. Se agregan
# aquí, de forma explícita, cuando la auditoría tenga otra unidad que revisar.
OBJETIVOS = {
    "FCFM": "https://www.fcfm.buap.mx",
    "FPSY": "https://psicologia.buap.mx",
    "FCP": "https://contaduria.buap.mx",
    "FCEL": "http://academica.ece.buap.mx",
    "CRNO": "https://crzn.buap.mx",
    "CRS": "https://crs.buap.mx",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirsearch", type=Path, required=True)
    ap.add_argument("--salida", type=Path, required=True)
    args = ap.parse_args()

    script = args.dirsearch / "dirsearch.py"
    if not script.is_file():
        raise SystemExit(f"No existe {script}")

    args.salida.mkdir(parents=True, exist_ok=True)
    wordlist = args.salida / "lobo-buap-wordlist.txt"
    wordlist.write_text("\n".join(PALABRAS) + "\n", encoding="utf-8")

    resumen: dict[str, list[dict[str, object]]] = {}
    for clave, url in OBJETIVOS.items():
        reporte = args.salida / f"{clave.lower()}.json"
        comando = [
            sys.executable,
            str(script),
            "-u",
            url,
            "-w",
            str(wordlist),
            "-t",
            "2",
            "--delay",
            "0.2",
            "--timeout",
            "8",
            "--max-time",
            "180",
            "-x",
            "404,429,500-599",
            "--random-agent",
            "--no-color",
            "-O",
            "json",
            "-o",
            str(reporte),
        ]
        print(f"[{clave}] {url}", flush=True)
        subprocess.run(comando, cwd=args.dirsearch, check=True)
        data = json.loads(reporte.read_text(encoding="utf-8"))
        resumen[clave] = data.get("results", [])

    (args.salida / "resumen.json").write_text(
        json.dumps(resumen, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Reportes: {args.salida}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
