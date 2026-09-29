#!/usr/bin/env python3
"""Helper de investigacion: descarga una URL y la convierte a texto legible.

Uso:  fetch.py URL [--links] [--grep TEXTO] [--max N]
Imprime: STATUS, URL_FINAL, TITULO, y luego el texto (o la lista de enlaces con --links).
"""
import sys
import subprocess
import sys as _s
from bs4 import BeautifulSoup

args = _s.argv[1:]
url = args[0]
show_links = "--links" in args
grep = None
if "--grep" in args:
    grep = args[args.index("--grep") + 1]
maxn = 200000
if "--max" in args:
    maxn = int(args[args.index("--max") + 1])

# Los sitios de varias facultades BUAP no envian el certificado intermedio
# (GlobalSign GCC R46 AlphaSSL CA 2025). Sin --cacert curl rechaza la conexion.
# Descargamos ese intermedio desde su AIA y lo anadimos como ancla de confianza,
# de modo que la verificacion TLS se hace completa en vez de desactivarse con -k.
CA = "/tmp/buap/buap-chain.pem"

p = subprocess.run(
    ["curl", "-sSL", "-m", "45", "--cacert", CA,
     "-A",
     "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36",
     "-w", "\n__HTTP__%{http_code}__%{url_effective}__%{content_type}",
     url],
    capture_output=True, text=True, errors="replace",
)
raw = p.stdout
marker = raw.rfind("__HTTP__")
body, meta = (raw[:marker], raw[marker + 10:]) if marker != -1 else (raw, "")
status, final_url, ctype = "?", url, "?"
parts = meta.strip().split("__")
if len(parts) >= 3:
    status, final_url, ctype = parts[0], parts[1], parts[2]

print(f"### STATUS={status} FINAL={final_url} TYPE={ctype} BYTES={len(body)}")
if p.stderr.strip():
    print("### STDERR:", p.stderr.strip()[:300])

if "pdf" in ctype.lower() or body[:4] == "%PDF":
    out = subprocess.run(["pdftotext", "-layout", "-", "-"],
                         input=body.encode("utf-8", "replace"),
                         capture_output=True)
    text = out.stdout.decode("utf-8", "replace")
    print("### PDF: texto extraido con pdftotext")
else:
    soup = BeautifulSoup(body, "html.parser")
    for t in soup(["script", "style", "noscript"]):
        t.decompose()
    title = soup.title.get_text(strip=True) if soup.title else ""
    print("### TITLE:", title)
    if show_links:
        seen = set()
        for a in soup.find_all("a", href=True):
            href = a["href"]
            label = " ".join(a.get_text(" ", strip=True).split())[:110]
            if not href or href.startswith("#") or href.startswith("javascript"):
                continue
            key = (href, label)
            if key in seen:
                continue
            seen.add(key)
            print(f"LINK\t{href}\t{label}")
    text = soup.get_text("\n", strip=True)

lines = [l for l in text.splitlines() if l.strip()]
if grep:
    g = grep.lower()
    lines = [l for l in lines if g in l.lower()]
print("\n".join(lines)[:maxn])
