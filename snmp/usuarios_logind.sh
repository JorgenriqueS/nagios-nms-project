#!/bin/sh
# /usr/local/bin/usuarios_logind.sh
# Cuenta las sesiones de usuario registradas en systemd-logind.
# Ubuntu reciente ya no escribe /run/utmp, por eso who, w y hrSystemNumUsers dan 0.
# Solo cuenta sesiones de clase "user" (excluye "manager", "greeter", etc.).
n=0
for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
  [ "$(loginctl show-session "$s" -p Class --value 2>/dev/null)" = "user" ] && n=$((n + 1))
done
echo "$n"
