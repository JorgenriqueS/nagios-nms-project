#!/usr/bin/env bash
# check_snmp_nms.sh - Plugin de Nagios: metricas por SNMPv3 (authPriv) con perfdata
# (las graficas de PNP4Nagios salen de la perfdata: lo que va despues del "|")
#
# Uso:
#   check_snmp_nms.sh -H <host> -u <usuario> -A <clave auth> -X <clave priv> -m <modo> [opciones]
#   -a <SHA|SHA-256|MD5>  protocolo de autenticacion (def. SHA)
#   -x <AES|DES>          protocolo de cifrado       (def. AES)
#
# Modos:
#   disk       % de disco usado (HOST-RESOURCES-MIB)     -p <punto de montaje> (def. /)
#   mem        Memoria total / en uso en Linux (UCD-SNMP-MIB)
#   mem-cisco  Memoria total / en uso en Cisco IOS (CISCO-MEMORY-POOL-MIB)
#   iface      Trafico de una interfaz en bps (IF-MIB)  -i <ifDescr: ens33, Ethernet0/0...>
#   icmp       Paquetes ICMP entrantes / salientes por segundo (IP-MIB)
#   users      Usuarios con sesion en el sistema (HOST-RESOURCES-MIB / extend)
#   uptime     Tiempo encendido; avisa si el equipo se reinicio hace poco
#
# Umbrales -w / -c:
#   disk, mem, mem-cisco: porcentaje (def. 80 / 90)
#   users: cantidad (def. 5 / 10)
#   iface: Mbps (sin umbral por defecto)
#   icmp:  paquetes/s (sin umbral por defecto)
#   uptime: minutos; WARNING/CRITICAL si el equipo lleva MENOS de -w/-c minutos encendido (def. -w 10)

STATE_DIR="${STATE_DIR:-/usr/local/nagios/var/snmp-state}"
LABEL=(OK WARNING CRITICAL UNKNOWN)
HOST="" SUSER="" AUTHP="" PRIVP="" AUTHPROTO="SHA" PRIVPROTO="AES" MODE="" IFACE="" PART="/" WARN="" CRIT=""

usage()   { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 3; }
unknown() { echo "UNKNOWN - $*"; exit 3; }

while getopts "H:u:A:X:a:x:m:i:p:w:c:h" opt; do
  case $opt in
    H) HOST=$OPTARG ;;  u) SUSER=$OPTARG ;; A) AUTHP=$OPTARG ;; X) PRIVP=$OPTARG ;;
    a) AUTHPROTO=$OPTARG ;; x) PRIVPROTO=$OPTARG ;; m) MODE=$OPTARG ;;
    i) IFACE=$OPTARG ;; p) PART=$OPTARG ;;  w) WARN=$OPTARG ;; c) CRIT=$OPTARG ;;
    *) usage ;;
  esac
done
[[ -z $HOST || -z $SUSER || -z $AUTHP || -z $PRIVP || -z $MODE ]] && usage
command -v snmpget >/dev/null || unknown "snmpget no esta instalado (sudo apt install snmp)"
mkdir -p "$STATE_DIR" 2>/dev/null || unknown "No se puede crear $STATE_DIR"

SNMP=(-v3 -l authPriv -u "$SUSER" -a "$AUTHPROTO" -A "$AUTHP" -x "$PRIVPROTO" -X "$PRIVP" -t 3 -r 1)

# Valor de un OID sin tipo, sin unidades y sin comillas
sget()  { snmpget "${SNMP[@]}" -OqvUe "$HOST" "$1" 2>/dev/null | tr -d '"' | head -n1; }
isnum() { [[ $1 =~ ^[0-9]+([.][0-9]+)?$ ]]; }
calc()  { awk "BEGIN{printf \"$1\", $2}"; }

# Indice de una tabla SNMP cuyo valor coincide exactamente con $2
find_index() {
  snmpwalk "${SNMP[@]}" -On -Oq "$HOST" "$1" 2>/dev/null |
    awk -v want="$2" '{ oid=$1; $1=""; sub(/^[ \t]+/,""); sub(/[ \t]+$/,""); gsub(/"/,"");
                        if ($0==want) { n=split(oid,a,"."); print a[n]; exit } }'
}

# Tasa por segundo de un contador (compara con la lectura anterior guardada en disco)
rate() {
  local key=$1 val=$2 now prev_t="" prev_v="" f
  now=$(date +%s)
  f="$STATE_DIR/${HOST//[^A-Za-z0-9._-]/_}_${key}"
  [[ -r $f ]] && read -r prev_t prev_v < "$f"
  echo "$now $val" > "$f"
  if [[ -z $prev_t ]] || (( now <= prev_t )) ||
     awk -v a="$val" -v b="$prev_v" 'BEGIN{exit !(a<b)}'; then
    echo init; return
  fi
  awk -v a="$val" -v b="$prev_v" -v t=$((now - prev_t)) 'BEGIN{printf "%.2f", (a-b)/t}'
}

# 0/1/2 segun umbrales (mayor o igual)
level() {
  awk -v v="$1" -v w="$2" -v c="$3" 'BEGIN{
    if (c!="" && v+0>=c+0) {print 2; exit}
    if (w!="" && v+0>=w+0) {print 1; exit}
    print 0 }'
}

case $MODE in
# ---------------------------------------------------------------------------
disk)
  W=${WARN:-80}; C=${CRIT:-90}
  idx=$(find_index .1.3.6.1.2.1.25.2.3.1.3 "$PART")
  [[ -n $idx ]] || unknown "No se encontro '$PART' en hrStorageDescr (revisa la vista de snmpd)"
  au=$(sget .1.3.6.1.2.1.25.2.3.1.4.$idx)
  size=$(sget .1.3.6.1.2.1.25.2.3.1.5.$idx)
  used=$(sget .1.3.6.1.2.1.25.2.3.1.6.$idx)
  { isnum "$au" && isnum "$size" && isnum "$used" && (( size > 0 )); } ||
    unknown "Respuesta SNMP invalida para $PART"
  total_mb=$(calc "%.0f" "$size*$au/1048576")
  used_mb=$(calc "%.0f" "$used*$au/1048576")
  pct=$(calc "%.1f" "$used*100/$size")
  rc=$(level "$pct" "$W" "$C")
  echo "${LABEL[rc]} - Disco $PART usado ${pct}% (${used_mb} MB de ${total_mb} MB) | disco_pct=${pct}%;$W;$C;0;100 disco_usado=${used_mb}MB;;;0;$total_mb"
  exit "$rc" ;;
# ---------------------------------------------------------------------------
mem)
  W=${WARN:-80}; C=${CRIT:-90}
  total=$(sget .1.3.6.1.4.1.2021.4.5.0)    # memTotalReal (kB)
  free=$(sget  .1.3.6.1.4.1.2021.4.6.0)    # memAvailReal (kB)
  buf=$(sget   .1.3.6.1.4.1.2021.4.14.0)   # memBuffer   (kB)
  cache=$(sget .1.3.6.1.4.1.2021.4.15.0)   # memCached   (kB)
  { isnum "$total" && isnum "$free" && (( total > 0 )); } ||
    unknown "El agente no expone UCD-SNMP-MIB (memoria)"
  isnum "$buf" || buf=0; isnum "$cache" || cache=0
  used_kb=$(( total - free - buf - cache ))
  (( used_kb < 0 )) && used_kb=$(( total - free ))
  total_mb=$(( total / 1024 )); used_mb=$(( used_kb / 1024 ))
  pct=$(calc "%.1f" "$used_kb*100/$total")
  rc=$(level "$pct" "$W" "$C")
  echo "${LABEL[rc]} - Memoria en uso ${used_mb} MB de ${total_mb} MB (${pct}%) | mem_usada=${used_mb}MB;;;0;$total_mb mem_total=${total_mb}MB;;;0; mem_pct=${pct}%;$W;$C;0;100"
  exit "$rc" ;;
# ---------------------------------------------------------------------------
mem-cisco)
  W=${WARN:-80}; C=${CRIT:-90}
  used=$(sget .1.3.6.1.4.1.9.9.48.1.1.1.5.1)   # ciscoMemoryPoolUsed (Processor, bytes)
  free=$(sget .1.3.6.1.4.1.9.9.48.1.1.1.6.1)   # ciscoMemoryPoolFree (Processor, bytes)
  { isnum "$used" && isnum "$free"; } || unknown "El router no expone CISCO-MEMORY-POOL-MIB"
  total=$(( used + free ))
  total_mb=$(calc "%.1f" "$total/1048576"); used_mb=$(calc "%.1f" "$used/1048576")
  pct=$(calc "%.1f" "$used*100/$total")
  rc=$(level "$pct" "$W" "$C")
  echo "${LABEL[rc]} - Memoria (Processor) en uso ${used_mb} MB de ${total_mb} MB (${pct}%) | mem_usada=${used_mb}MB;;;0;$total_mb mem_total=${total_mb}MB;;;0; mem_pct=${pct}%;$W;$C;0;100"
  exit "$rc" ;;
# ---------------------------------------------------------------------------
iface)
  [[ -n $IFACE ]] || unknown "Falta -i <interfaz>"
  idx=$(find_index .1.3.6.1.2.1.2.2.1.2 "$IFACE")
  [[ -n $idx ]] || unknown "Interfaz '$IFACE' no encontrada en ifDescr"
  oper=$(sget .1.3.6.1.2.1.2.2.1.8.$idx)                     # ifOperStatus 1=up
  in=$(sget .1.3.6.1.2.1.31.1.1.1.6.$idx)                    # ifHCInOctets
  out=$(sget .1.3.6.1.2.1.31.1.1.1.10.$idx)                  # ifHCOutOctets
  if ! isnum "$in" || ! isnum "$out"; then                   # respaldo: contadores de 32 bits
    in=$(sget .1.3.6.1.2.1.2.2.1.10.$idx); out=$(sget .1.3.6.1.2.1.2.2.1.16.$idx)
  fi
  { isnum "$in" && isnum "$out"; } || unknown "No se pudieron leer los contadores de $IFACE"
  rin=$(rate "if${idx}_in" "$in"); rout=$(rate "if${idx}_out" "$out")
  if [[ $rin == init || $rout == init ]]; then
    echo "OK - $IFACE: primera lectura guardada, la tasa aparece en el siguiente chequeo"; exit 0
  fi
  bin=$(calc "%.0f" "$rin*8"); bout=$(calc "%.0f" "$rout*8")
  kin=$(calc "%.2f" "$bin/1000"); kout=$(calc "%.2f" "$bout/1000")
  wb=""; cb=""
  [[ -n $WARN ]] && wb=$(calc "%.0f" "$WARN*1000000")
  [[ -n $CRIT ]] && cb=$(calc "%.0f" "$CRIT*1000000")
  perf="in_bps=${bin};$wb;$cb;0 out_bps=${bout};$wb;$cb;0"
  if [[ $oper != 1 ]]; then
    echo "CRITICAL - Interfaz $IFACE operativamente DOWN | $perf"; exit 2
  fi
  mbps=$(calc "%.3f" "($bin>$bout?$bin:$bout)/1000000")
  rc=$(level "$mbps" "$WARN" "$CRIT")
  echo "${LABEL[rc]} - $IFACE RX ${kin} kbps / TX ${kout} kbps | $perf"
  exit "$rc" ;;
# ---------------------------------------------------------------------------
icmp)
  in=$(sget .1.3.6.1.2.1.5.1.0)      # icmpInMsgs
  out=$(sget .1.3.6.1.2.1.5.14.0)    # icmpOutMsgs
  { isnum "$in" && isnum "$out"; } || unknown "El agente no expone el grupo ICMP de IP-MIB"
  rin=$(rate icmp_in "$in"); rout=$(rate icmp_out "$out")
  if [[ $rin == init || $rout == init ]]; then
    echo "OK - ICMP: primera lectura guardada, la tasa aparece en el siguiente chequeo"; exit 0
  fi
  max=$(calc "%.2f" "($rin>$rout?$rin:$rout)")
  rc=$(level "$max" "$WARN" "$CRIT")
  echo "${LABEL[rc]} - ICMP entrantes ${rin} pkt/s, salientes ${rout} pkt/s (total in=$in out=$out) | icmp_in=${rin};$WARN;$CRIT;0 icmp_out=${rout};$WARN;$CRIT;0"
  exit "$rc" ;;
# ---------------------------------------------------------------------------
users)
  W=${WARN:-5}; C=${CRIT:-10}
  # 1) "extend usuarios" de snmpd (NET-SNMP-EXTEND-MIB, nsExtendOutput1Line."usuarios")
  #    -> necesario en Ubuntu recientes que ya no escriben /run/utmp
  # 2) respaldo: hrSystemNumUsers (HOST-RESOURCES-MIB, lee utmp)
  u=$(sget .1.3.6.1.4.1.8072.1.3.2.3.1.1.8.117.115.117.97.114.105.111.115)
  isnum "$u" || u=$(sget .1.3.6.1.2.1.25.1.5.0)
  isnum "$u" || unknown "El agente no expone el numero de usuarios"
  rc=$(level "$u" "$W" "$C")
  echo "${LABEL[rc]} - $u usuario(s) con sesion en el sistema | usuarios=$u;$W;$C;0"
  exit "$rc" ;;
# ---------------------------------------------------------------------------
uptime)
  W=${WARN:-10}; C=${CRIT:-}
  # hrSystemUptime = tiempo encendido del sistema (Linux); no se reinicia si solo se reinicia snmpd.
  # Respaldo: sysUpTime (Cisco IOS, = tiempo desde que arranco el equipo).
  t=$(snmpget "${SNMP[@]}" -Oqvt "$HOST" .1.3.6.1.2.1.25.1.1.0 2>/dev/null | head -n1)
  isnum "$t" || t=$(snmpget "${SNMP[@]}" -Oqvt "$HOST" .1.3.6.1.2.1.1.3.0 2>/dev/null | head -n1)
  isnum "$t" || unknown "No se pudo leer el tiempo encendido"
  min=$(( t / 6000 ))                                   # timeticks = centesimas de segundo
  txt=$(printf '%dd %dh %dm' $((min/1440)) $((min%1440/60)) $((min%60)))
  rc=0
  if [[ -n $C ]] && (( min < C )); then rc=2
  elif [[ -n $W ]] && (( min < W )); then rc=1; fi
  if (( rc > 0 )); then
    echo "${LABEL[rc]} - El equipo se reinicio hace $min minuto(s) (encendido: $txt) | uptime_min=$min;;;0"
  else
    echo "OK - Encendido desde hace $txt | uptime_min=$min;;;0"
  fi
  exit "$rc" ;;
# ---------------------------------------------------------------------------
*) usage ;;
esac
