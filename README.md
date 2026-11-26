# NMS con Nagios Core, SNMPv3, PNP4Nagios, Telegram y syslog

Archivos para levantar un sistema de monitoreo de red con **Nagios Core** que supervisa servidores Ubuntu y un router Cisco por **SNMPv3** (authPriv: SHA + AES-128), con gráficas en **PNP4Nagios**, alertas por **Telegram**, bitácora central con **rsyslog** y scripts de comandos CLI ejecutados por SSH.

## Documentación

| Archivo | Contenido |
|---|---|
| `nagios-installation.pdf` | Instalación de Nagios Core 4.5.9 y sus plugins, paso a paso, con capturas |
| `Guia_Proyecto_NMS_Nagios.pdf` | Guía del proyecto: SNMPv3, plugin y servicios, gráficas, Telegram, syslog, pruebas y scripts (también en `GUIA.md`) |

Orden sugerido: primero `nagios-installation.pdf` y luego `Guia_Proyecto_NMS_Nagios.pdf`.

## Contenido

| Carpeta / archivo | Para qué sirve |
|---|---|
| `plugins/check_snmp_nms.sh` | Plugin de Nagios: disco, memoria, tráfico de interfaces, ICMP, usuarios y tiempo encendido por SNMPv3, con umbrales y perfdata para las gráficas |
| `plugins/notify_telegram.sh` | Envía las notificaciones de Nagios a un bot de Telegram |
| `nagios/proyecto.cfg` | Hosts, grupos, comandos, servicios con umbrales y contacto de Telegram |
| `nagios/nagios.cfg.fragmento` | Directivas de `nagios.cfg` para syslog y perfdata |
| `nagios/resource.cfg.fragmento` | Variables con el usuario y las claves SNMPv3 |
| `nagios/quitar_servicios.py` | Comenta servicios de ejemplo en un `.cfg` de Nagios, con respaldo |
| `pnp4nagios/check_snmp_nms.php` | Plantilla de PNP4Nagios para las gráficas del plugin |
| `systemd/npcd.service` | Unidad de systemd para NPCD |
| `snmp/snmpd.conf.*` | Configuración del agente SNMPv3 (NMS y servidor monitoreado) |
| `snmp/usuarios_logind.sh` | Cuenta sesiones con `loginctl` (Ubuntu reciente no usa `/run/utmp`) |
| `rsyslog/` | Servidor syslog central, filtro de eventos de Nagios, reenvío del cliente y rotación |
| `cisco/` | Configuración del router: SNMPv3, syslog, SSH con llave pública y comandos de monitoreo |
| `cli/monitoreo_cli.sh` | Comandos de monitoreo en Linux (local o `--remoto <alias>` por SSH) con reporte |
| `cli/monitoreo_router.sh` | Comandos de monitoreo en Cisco IOS por SSH con reporte |
| `img/` | Capturas usadas en la guía |
| `nagios-installation.pdf` · `Guia_Proyecto_NMS_Nagios.pdf` | Documentación (ver arriba) |

## Antes de usarlo

Reemplaza los valores de ejemplo por los de tu red:

| Valor de ejemplo | Dónde | Qué poner |
|---|---|---|
| `192.168.20.20` / `.22` / `.24` | `proyecto.cfg`, `rsyslog/`, `cisco/`, `cli/` | IPs de tu NMS, servidor y router |
| `final-project-nmm` | `snmpd.conf`, `resource.cfg`, router | Tu usuario SNMPv3 |
| `CAMBIAR_CLAVE_AUTH` / `CAMBIAR_CLAVE_PRIV` | `resource.cfg`, `createUser`, router | Tus claves (mínimo 8 caracteres, distintas entre sí) |
| `CAMBIAR_CHAT_ID` | `proyecto.cfg` | Tu chat_id de Telegram |
| `ens33`, `ens37`, `Ethernet0/0` | `proyecto.cfg`, `cli/` | Nombres de tus interfaces |
| `<usuario>` | Guía | Tu usuario de Linux |

El token del bot va en `/usr/local/nagios/etc/telegram.conf` (`TELEGRAM_TOKEN="..."`, permisos `root:nagios 640`). **Nunca lo subas a un repositorio.**

Probado con Nagios Core 4.5.9, PNP4Nagios 0.6.26, PHP 8.4, Ubuntu Server y Cisco IOL 15.7(3)M2 en EVE-NG.
