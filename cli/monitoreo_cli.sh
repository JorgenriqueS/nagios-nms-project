#!/usr/bin/env bash
# monitoreo_cli.sh - Comandos de monitoreo desde la linea de comandos
# Se ejecuta igual en cualquier host Linux monitoreado (NMS y ubuntu-srv).
#
# Uso local:   ./monitoreo_cli.sh [interfaz] [segundos] [IP_destino]
#              ./monitoreo_cli.sh ens33 10 192.168.20.24
# Uso remoto:  ./monitoreo_cli.sh --remoto <alias_ssh> [interfaz] [segundos] [IP_destino]
#              ./monitoreo_cli.sh --remoto server2 ens33 10
#   Copia este script al equipo remoto, lo ejecuta alli por SSH (con llave)
#   y guarda el reporte en ESTE equipo. No deja archivos en el remoto.
# Genera reporte_cli_<host>_<fecha>.txt como evidencia para el informe.

# ------------------------------------------------------------- modo remoto
if [[ $1 == --remoto ]]; then
  RHOST=$2; shift 2
  [[ -n $RHOST ]] || { echo "Falta el equipo: --remoto <alias_ssh>"; exit 1; }
  SSHR=(ssh -q -o BatchMode=yes -o ConnectTimeout=10 "$RHOST")
  RNAME=$("${SSHR[@]}" hostname) || { echo "No se pudo entrar por SSH a '$RHOST'. Prueba: ssh -v $RHOST hostname"; exit 1; }
  OUT="reporte_cli_${RNAME}_$(date +%F_%H%M).txt"
  RTMP=$("${SSHR[@]}" mktemp /tmp/monitoreo_cli.XXXXXX) || exit 1
  scp -q -o BatchMode=yes "$(readlink -f "$0")" "$RHOST:$RTMP" || { echo "No se pudo copiar el script a $RHOST"; exit 1; }
  "${SSHR[@]}" "REPORTE_ARCHIVO=0 bash $RTMP $(printf '%q ' "$@"); rm -f $RTMP" | tee "$OUT"
  echo; echo "Reporte de $RNAME guardado en $(pwd)/$OUT"
  exit 0
fi

# ------------------------------------------------------------- modo local
IF=${1:-ens33}; S=${2:-5}; DEST=${3:-192.168.20.24}
OUT="reporte_cli_$(hostname)_$(date +%F_%H%M).txt"

sec() { printf '\n===== %s =====\n$ %s\n' "$1" "$2"; bash -c "$2" 2>&1 </dev/null; }

reporte() {
echo "Reporte de monitoreo - $(hostname) - $(date)"

# 1. Velocidad del ancho de banda
sec "1. Ancho de banda hacia Internet" "command -v speedtest-cli >/dev/null && speedtest-cli --simple || echo 'Instalar: sudo apt install speedtest-cli'"

# 2. Usuarios conectados
sec "2a. Sesiones de usuario (systemd-logind)" "loginctl list-sessions"
sec "2b. Cantidad de sesiones de usuario" "/usr/local/bin/usuarios_logind.sh 2>/dev/null || loginctl list-sessions --no-legend | wc -l"

# 3. Throughput de una interfaz (calculo con los contadores del kernel)
printf '\n===== 3a. Throughput de %s medido durante %ss =====\n' "$IF" "$S"
r1=$(<"/sys/class/net/$IF/statistics/rx_bytes"); t1=$(<"/sys/class/net/$IF/statistics/tx_bytes")
sleep "$S"
r2=$(<"/sys/class/net/$IF/statistics/rx_bytes"); t2=$(<"/sys/class/net/$IF/statistics/tx_bytes")
awk -v r=$((r2-r1)) -v t=$((t2-t1)) -v s="$S" \
    'BEGIN{printf "RX: %.2f kbps   TX: %.2f kbps\n", r*8/s/1000, t*8/s/1000}'
sec "3b. Contadores de la interfaz" "ip -s link show $IF"
sec "3c. Estadistica por interfaz (sysstat)" "command -v sar >/dev/null && sar -n DEV 1 3 | grep -E 'IFACE|$IF' || echo 'Instalar: sudo apt install sysstat'"

# 4. Capacidad de disco utilizada
sec "4a. Capacidad de disco utilizada" "df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay"
sec "4b. Inodos" "df -i /"

# 5. Otros comandos relevantes para el monitoreo
sec "5a. Memoria" "free -h"
sec "5b. Tiempo encendido y carga" "uptime"
sec "5c. Procesos que mas CPU consumen" "ps aux --sort=-%cpu | head -n 6"
sec "5d. Procesos que mas memoria consumen" "ps aux --sort=-%mem | head -n 6"
sec "5e. Puertos en escucha" "ss -tuln"
sec "5f. Tabla de rutas y gateway" "ip route"
sec "5g. Hora y sincronizacion NTP" "timedatectl"
sec "5h. Conectividad a $DEST" "ping -c 4 $DEST"
}

# En modo remoto (REPORTE_ARCHIVO=0) solo se envia la salida; el archivo lo guarda el NMS
if [[ ${REPORTE_ARCHIVO:-1} == 0 ]]; then
  reporte
else
  reporte | tee "$OUT"
  echo; echo "Reporte guardado en $OUT"
fi
