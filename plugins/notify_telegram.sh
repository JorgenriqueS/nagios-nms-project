#!/usr/bin/env bash
# notify_telegram.sh - Envia notificaciones de Nagios a Telegram
# Lo llaman los comandos notify-host-by-telegram / notify-service-by-telegram:
#   notify_telegram.sh host    <chat_id> <tipo> <host> <ip> <estado> <salida> <fecha>
#   notify_telegram.sh service <chat_id> <tipo> <host> <ip> <servicio> <estado> <salida> <fecha>
# El token del bot se lee de /usr/local/nagios/etc/telegram.conf  (TELEGRAM_TOKEN="...")

CONF=/usr/local/nagios/etc/telegram.conf
[[ -r $CONF ]] || { logger -t nagios-telegram "No se puede leer $CONF"; exit 1; }
# shellcheck source=/dev/null
source "$CONF"

KIND=$1; CHAT=$2; TYPE=$3; HOSTN=$4; ADDR=$5
if [[ $KIND == host ]]; then
  SVC="";  STATE=$6; OUT=$7; WHEN=$8
else
  SVC=$6;  STATE=$7; OUT=$8; WHEN=$9
fi

case $STATE in
  OK|UP)          ICON="🟢" ;;
  WARNING)        ICON="🟡" ;;
  CRITICAL|DOWN)  ICON="🔴" ;;
  *)              ICON="⚪" ;;
esac
case $TYPE in
  RECOVERY)        ICON="✅" ;;
  ACKNOWLEDGEMENT) ICON="👀" ;;
esac

MSG="$ICON Nagios - $TYPE
Host: $HOSTN ($ADDR)"
[[ -n $SVC ]] && MSG+="
Servicio: $SVC"
MSG+="
Estado: $STATE
Detalle: $OUT
Fecha: $WHEN"

RESP=$(curl -sS --max-time 10 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
         --data-urlencode "chat_id=${CHAT}" --data-urlencode "text=${MSG}" 2>&1)

if [[ $RESP == *'"ok":true'* ]]; then
  logger -t nagios-telegram "Enviado: $TYPE $HOSTN${SVC:+ / $SVC} $STATE"
else
  logger -t nagios-telegram "ERROR al enviar a Telegram: $RESP"
  exit 1
fi
