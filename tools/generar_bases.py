#!/usr/bin/env python3
"""Regenera las bases de datos que van dentro de la app.

Entradas (las que entregó la BUAP):
    /home/alan/Downloads/buap_registros.db     tabla `alumnos`
    /home/alan/Downloads/buap_trabajadores.db  tabla `trabajadores`

Salidas:
    assets/alumnos/cohorte_<año>.tsv.gz
    assets/alumnos/index.json
    assets/trabajadores/trabajadores.tsv.gz
    assets/trabajadores/index.json

Ver tools/README.md para el porqué de cada decisión.
"""

import gzip
import json
import os
import sqlite3
import sys

DB_ALUMNOS = "/home/alan/Downloads/buap_registros.db"
DB_TRABAJADORES = "/home/alan/Downloads/buap_trabajadores.db"
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# La app no usa el correo del alumno, y empaquetar 318 mil correos sería
# distribuir dato personal que no hace falta. No se incluye.
# Para el trabajador sí se conserva el institucional, que la BUAP ya publica
# en sus directorios; los personales (gmail, hotmail) se descartan.
DOMINIO_INSTITUCIONAL = "@correo.buap.mx"


def nombre_completo(paterno, materno, nombre):
    apellidos = " ".join(p for p in (paterno, materno) if p and p.strip())
    return f"{apellidos} {nombre or ''}".strip()


def generar_alumnos():
    if not os.path.exists(DB_ALUMNOS):
        print(f"No se encontró {DB_ALUMNOS}", file=sys.stderr)
        return False

    destino = os.path.join(RAIZ, "assets", "alumnos")
    os.makedirs(destino, exist_ok=True)

    conexion = sqlite3.connect(DB_ALUMNOS)
    filas = conexion.execute(
        "SELECT matricula, paterno, materno, nombre FROM alumnos ORDER BY matricula"
    ).fetchall()
    conexion.close()

    cohorts = {}
    for matricula, paterno, materno, nombre in filas:
        matricula = str(matricula)
        anio = matricula[:4]
        cohorts.setdefault(anio, []).append(
            f"{matricula}\t{nombre_completo(paterno, materno, nombre)}"
        )

    meta = {
        "total": len(filas),
        "cohorts": {},
        "fuente": os.path.basename(DB_ALUMNOS),
        "nota": "Sin correos: la app no los usa. Sin facultad: no esta en la base.",
    }
    for anio, lineas in sorted(cohorts.items()):
        crudo = "\n".join(lineas).encode("utf-8")
        comprimido = gzip.compress(crudo, 9)
        archivo = f"assets/alumnos/cohorte_{anio}.tsv.gz"
        with open(os.path.join(RAIZ, archivo), "wb") as f:
            f.write(comprimido)
        meta["cohorts"][anio] = {
            "registros": len(lineas),
            "archivo": archivo,
            "raw_bytes": len(crudo),
            "gz_bytes": len(comprimido),
        }
        print(f"  {anio}: {len(lineas):>7} alumnos  {len(comprimido)/1048576:.2f} MB")

    with open(os.path.join(destino, "index.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    total_gz = sum(c["gz_bytes"] for c in meta["cohorts"].values())
    print(f"  Total alumnos: {len(filas)} en {len(cohorts)} cohortes, {total_gz/1048576:.2f} MB")
    return True


def generar_trabajadores():
    if not os.path.exists(DB_TRABAJADORES):
        print(f"No se encontró {DB_TRABAJADORES}", file=sys.stderr)
        return False

    destino = os.path.join(RAIZ, "assets", "trabajadores")
    os.makedirs(destino, exist_ok=True)

    conexion = sqlite3.connect(DB_TRABAJADORES)
    filas = conexion.execute(
        "SELECT matricula, paterno, materno, nombre, email FROM trabajadores "
        "ORDER BY matricula"
    ).fetchall()
    conexion.close()

    lineas = []
    con_correo = 0
    for matricula, paterno, materno, nombre, email in filas:
        correo = (email or "").strip()
        institucional = correo if correo.endswith(DOMINIO_INSTITUCIONAL) else ""
        if institucional:
            con_correo += 1
        base = f"{matricula}\t{nombre_completo(paterno, materno, nombre)}"
        lineas.append(f"{base}\t{institucional}" if institucional else base)

    crudo = "\n".join(lineas).encode("utf-8")
    comprimido = gzip.compress(crudo, 9)
    archivo = "assets/trabajadores/trabajadores.tsv.gz"
    with open(os.path.join(RAIZ, archivo), "wb") as f:
        f.write(comprimido)

    meta = {
        "total": len(filas),
        "con_correo_institucional": con_correo,
        "archivo": archivo,
        "raw_bytes": len(crudo),
        "gz_bytes": len(comprimido),
        "nota": (
            "Solo correos @correo.buap.mx. La base no tiene unidad academica: "
            "no se puede ligar a una facultad."
        ),
    }
    with open(os.path.join(destino, "index.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    print(
        f"  Total trabajadores: {len(filas)} "
        f"({con_correo} con correo institucional), {len(comprimido)/1048576:.2f} MB"
    )
    return True


def main():
    print("Alumnos:")
    if not generar_alumnos():
        return 1
    print("Trabajadores:")
    if not generar_trabajadores():
        return 1
    print("\nListo. Corre `flutter test` para validar las bases nuevas.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
