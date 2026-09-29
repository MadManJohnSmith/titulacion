#!/usr/bin/env python3
"""Rastrea un sitio Drupal de BUAP: parte de la portada, sigue enlaces internos
de /content/ y /?q=content/ (mismo host, profundidad limitada) y lista todos los
PDF y paginas cuyo texto mencione modalidades de titulacion.

Uso: crawl.py https://host.buap.mx/ [profundidad]
"""
import sys
import subprocess
import urllib.parse
from collections import deque
from bs4 import BeautifulSoup

ROOT = sys.argv[1].rstrip("/")
MAXD = int(sys.argv[2]) if len(sys.argv) > 2 else 2
CA = "/tmp/buap/buap-chain.pem"
KEYS = ("titulación automática", "modalidades de titulación", "modalidad de titulación",
        "mapa gráfico", "mapa grafico", "ruta de titulación", "ruta de titulacion",
        "egel", "seminario de titulación", "seminario de titulacion", "diplomado de",
        "tesina", "portafolio", "examen profesional", "titulación por",
        "titulacion por", "unidad de titulación", "unidad de titulacion")


def get(url):
    p = subprocess.run(
        ["curl", "-sSL", "-m", "35", "--cacert", CA, "-A", "Mozilla/5.0",
         "-w", "\n__S__%{http_code}", url],
        capture_output=True, text=True, errors="replace")
    t = p.stdout
    i = t.rfind("\n__S__")
    if i == -1:
        return None, ""
    return t[i + 6:].strip(), t[:i]


def norm(h):
    u = urllib.parse.urljoin(ROOT + "/", h)
    p = urllib.parse.urlparse(u)
    q = urllib.parse.parse_qs(p.query).get("q", [""])[0]
    if q.startswith("content/"):
        q = "content/" + q[len("content/"):]
        return urllib.parse.urlunparse((p.scheme, p.netloc, "/" + q, "", "", ""))
    if p.path.startswith("/content/"):
        return urllib.parse.urlunparse((p.scheme, p.netloc, p.path, "", "", ""))
    return None


seen, queue, pdfs = set(), deque([(ROOT, 0)]), {}
hits = []
while queue:
    url, d = queue.popleft()
    if url in seen or d > MAXD:
        continue
    seen.add(url)
    code, body = get(url)
    if code != "200" or not body:
        continue
    soup = BeautifulSoup(body, "html.parser")
    txt = " ".join(soup.get_text(" ", strip=True).split())
    low = txt.lower()
    if any(k in low for k in KEYS):
        marks = [k for k in KEYS if k in low]
        hits.append((url, marks, txt))
    for a in soup.find_all("a", href=True):
        h = a["href"]
        if h.lower().split("?")[0].endswith(".pdf"):
            pdfs[urllib.parse.urljoin(url, h)] = a.get_text(" ", strip=True)
            continue
        n = norm(h)
        if n and n not in seen:
            queue.append((n, d + 1))

print(f"## Páginas rastreadas: {len(seen)}")
print(f"## PDFs encontrados: {len(pdfs)}")
for u, lab in sorted(pdfs.items()):
    print(f"PDF\t{u}\t{lab[:80]}")
print("\n## Páginas cuyo texto menciona modalidades:")
for u, marks, txt in hits:
    print(f"HIT\t{u}\t{marks}")
    for k in marks:
        i = txt.lower().find(k)
        print("      ...", txt[max(0, i - 160):i + 300].strip()[:460])
