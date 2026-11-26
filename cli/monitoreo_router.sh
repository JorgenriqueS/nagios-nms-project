#!/usr/bin/env bash
# monitoreo_router.sh - Comandos de monitoreo del router Cisco ejecutados por SSH desde el NMS
# Equivalente a monitoreo_cli.sh, pero para IOS. Usa la llave publica (sin contrasena).
#
# Uso:  ./monitoreo_router.sh [alias_ssh] [interfaz] [IP_destino]
#       ./monitoreo_router.sh r1 Ethernet0/0 192.168.20.20
# Requiere el bloque "Host r1" en ~/.ssh/config (ver GUIA.md, seccion 8).
# Genera reporte_cli_<alias>_<fecha>.txt

R=${1:-r1}; IF=${2:-Ethernet0/0}; DEST=${3:-192.168.20.20}
OUT="reporte_cli_${R}_$(date +%F_%H%M).txt"
SSH=(ssh -q -o BatchMode=yes -o ConnectTimeout=10 "$R")

# Comprobar el acceso antes de empezar
if ! "${SSH[@]}" "show clock" >/dev/null 2>&1; then
  echo "No se pudo entrar por SSH a '$R'. Prueba: ssh -v $R \"show clock\""
  exit 1
fi

# IOS cierra la sesion al terminar cada comando; OpenSSH avisa aunque se use -q, asi que se filtra
cmd() { printf '\n===== %s =====\n%s# %s\n' "$1" "$R" "$2"; "${SSH[@]}" "$2" 2>&1 | tr -d '\r' | sed 's/Connection to .* closed by remote host\.//'; echo; }

{
echo "Reporte de monitoreo - router $R - $(date)"

# 1. Velocidad del ancho de banda (configurado) y duplex
cmd "1. Ancho de banda de la interfaz ($IF)" "show interfaces $IF | include BW|duplex"

# 2. Usuarios conectados
cmd "2. Usuarios conectados" "show users"

# 3. Throughput de una interfaz
cmd "3a. Throughput de $IF" "show interfaces $IF | include rate"
cmd "3b. Contadores de la interfaz" "show interfaces $IF"

# 4. Capacidad de disco (IOL no tiene flash: nvram)
cmd "4a. Sistemas de archivos" "show file systems"
cmd "4b. Uso de NVRAM (IOL no tiene flash)" "dir nvram:"

# 5. Otros comandos relevantes
cmd "5a. Memoria" "show memory statistics"
cmd "5b. Tiempo encendido" "show version | include uptime"
cmd "5c. Procesos que mas CPU consumen" "show processes cpu sorted | exclude 0.00%  0.00%  0.00%"
cmd "5d. Procesos que mas memoria consumen" "show processes memory sorted"
cmd "5e. Puertos en escucha" "show control-plane host open-ports"
cmd "5f. Tabla de rutas" "show ip route"
cmd "5g. Hora" "show clock detail"
cmd "5h. Conectividad a $DEST" "ping $DEST"
} | tee "$OUT"

echo; echo "Reporte guardado en $OUT"
