#!/usr/bin/env python3
"""
quitar_servicios.py - Comenta (desactiva) bloques "define service" de Nagios
por host y descripcion, dejando un respaldo del archivo.

Uso:
  sudo python3 quitar_servicios.py <archivo.cfg> <host> "Servicio 1" "Servicio 2" ...   # vista previa
  sudo python3 quitar_servicios.py --aplicar <archivo.cfg> <host> "Servicio 1" ...      # aplica

Los bloques no se borran: cada linea queda con "#" al inicio, para poder revertir.
"""
import re
import shutil
import sys
from datetime import datetime

args = sys.argv[1:]
aplicar = False
if args and args[0] == "--aplicar":
    aplicar = True
    args = args[1:]
if len(args) < 3:
    print(__doc__)
    sys.exit(1)

archivo, host, servicios = args[0], args[1], set(args[2:])
texto = open(archivo, encoding="utf-8").read()

patron = re.compile(r"^[ \t]*define[ \t]+service[ \t]*\{.*?^[ \t]*\}", re.S | re.M)

def valor(bloque, clave):
    m = re.search(r"^[ \t]*" + clave + r"[ \t]+([^;\n]+)", bloque, re.M)
    return m.group(1).strip() if m else None

encontrados = []

def comentar(m):
    bloque = m.group(0)
    desc = valor(bloque, "service_description")
    hosts = [h.strip() for h in (valor(bloque, "host_name") or "").split(",")]
    if desc in servicios and host in hosts:
        encontrados.append(desc)
        return "\n".join("#" + linea for linea in bloque.split("\n"))
    return bloque

nuevo = patron.sub(comentar, texto)

for s in sorted(servicios):
    print(("  [x] " if s in encontrados else "  [ ] no encontrado: ") + s)

if not aplicar:
    print("\nVista previa. Agrega --aplicar para modificar el archivo.")
    sys.exit(0)

if encontrados:
    respaldo = archivo + ".bak-" + datetime.now().strftime("%Y%m%d-%H%M%S")
    shutil.copy2(archivo, respaldo)
    open(archivo, "w", encoding="utf-8").write(nuevo)
    print("\nAplicado. Respaldo en " + respaldo)
else:
    print("\nNo hubo cambios.")
