<?php
#
# Plantilla PNP4Nagios para check_snmp_nms.sh
# Ruta: /usr/local/pnp4nagios/share/templates/check_snmp_nms.php
#
# Junta en una misma grafica los datos relacionados:
#   - Memoria: total (area) + en uso (area) en MB, y otra grafica con el % de uso
#   - Trafico de interfaz: entrada y salida en bps
#   - ICMP: paquetes entrantes y salientes por segundo
#   - Disco y usuarios: una grafica con sus umbrales
#

$ds = array();
foreach ($this->DS as $KEY => $VAL) {
    $ds[$VAL['NAME']] = $VAL;
}
$usados = array();
$g = 0;

# ------------------------------------------------------------- MEMORIA
if (isset($ds['mem_usada']) && isset($ds['mem_total'])) {
    $g++;
    $u = $ds['mem_usada']; $t = $ds['mem_total'];
    $ds_name[$g] = "Memoria total y en uso";
    $opt[$g]  = "--vertical-label MB -l 0 --title \"$hostname / Memoria total y en uso\" ";
    $def[$g]  = rrd::def("total", $t['RRDFILE'], $t['DS'], "AVERAGE");
    $def[$g] .= rrd::def("usada", $u['RRDFILE'], $u['DS'], "AVERAGE");
    $def[$g] .= rrd::area("total", "#BDD7EE", "Total   ");
    $def[$g] .= rrd::gprint("total", array("LAST"), "%8.1lf MB");
    $def[$g] .= rrd::area("usada", "#2E75B6", "En uso  ");
    $def[$g] .= rrd::gprint("usada", array("LAST", "MAX", "AVERAGE"), "%8.1lf MB");
    $usados[] = 'mem_usada'; $usados[] = 'mem_total';
}

# ------------------------------------------------------------- TRAFICO DE INTERFAZ
if (isset($ds['in_bps']) && isset($ds['out_bps'])) {
    $g++;
    $i = $ds['in_bps']; $o = $ds['out_bps'];
    $ds_name[$g] = "Trafico de la interfaz";
    $opt[$g]  = "--vertical-label bps -l 0 --base 1000 --title \"$hostname / $servicedesc\" ";
    $def[$g]  = rrd::def("rx", $i['RRDFILE'], $i['DS'], "AVERAGE");
    $def[$g] .= rrd::def("tx", $o['RRDFILE'], $o['DS'], "AVERAGE");
    $def[$g] .= rrd::area("rx", "#70AD47", "Entrada (RX) ");
    $def[$g] .= rrd::gprint("rx", array("LAST", "MAX", "AVERAGE"), "%7.2lf %Sbps");
    $def[$g] .= rrd::line2("tx", "#2E75B6", "Salida  (TX) ");
    $def[$g] .= rrd::gprint("tx", array("LAST", "MAX", "AVERAGE"), "%7.2lf %Sbps");
    if ($i['WARN'] != "") { $def[$g] .= rrd::hrule($i['WARN'], "#FFC000", "Warning  " . ($i['WARN'] / 1000000) . " Mbps\\n"); }
    if ($i['CRIT'] != "") { $def[$g] .= rrd::hrule($i['CRIT'], "#FF0000", "Critical " . ($i['CRIT'] / 1000000) . " Mbps\\n"); }
    $usados[] = 'in_bps'; $usados[] = 'out_bps';
}

# ------------------------------------------------------------- ICMP
if (isset($ds['icmp_in']) && isset($ds['icmp_out'])) {
    $g++;
    $i = $ds['icmp_in']; $o = $ds['icmp_out'];
    $ds_name[$g] = "Paquetes ICMP";
    $opt[$g]  = "--vertical-label pkt/s -l 0 --title \"$hostname / Trafico de paquetes ICMP\" ";
    $def[$g]  = rrd::def("ein", $i['RRDFILE'], $i['DS'], "AVERAGE");
    $def[$g] .= rrd::def("eout", $o['RRDFILE'], $o['DS'], "AVERAGE");
    $def[$g] .= rrd::area("ein", "#ED7D31", "ICMP entrantes ");
    $def[$g] .= rrd::gprint("ein", array("LAST", "MAX", "AVERAGE"), "%7.2lf pkt/s");
    $def[$g] .= rrd::line2("eout", "#7030A0", "ICMP salientes ");
    $def[$g] .= rrd::gprint("eout", array("LAST", "MAX", "AVERAGE"), "%7.2lf pkt/s");
    if ($i['WARN'] != "") { $def[$g] .= rrd::hrule($i['WARN'], "#FFC000", "Warning  " . $i['WARN'] . " pkt/s\\n"); }
    if ($i['CRIT'] != "") { $def[$g] .= rrd::hrule($i['CRIT'], "#FF0000", "Critical " . $i['CRIT'] . " pkt/s\\n"); }
    $usados[] = 'icmp_in'; $usados[] = 'icmp_out';
}

# ------------------------------------------------------------- RESTO (%, disco, usuarios)
# Una grafica por cada dato no agrupado arriba, con sus lineas de umbral.
$titulos = array(
    'mem_pct'     => 'Memoria en uso (%)',
    'disco_pct'   => 'Utilizacion de disco duro (%)',
    'disco_usado' => 'Disco usado (MB)',
    'usuarios'    => 'Cantidad de usuarios en el sistema',
    'uptime_min'  => 'Tiempo encendido (minutos)',
);
foreach ($this->DS as $KEY => $VAL) {
    if (in_array($VAL['NAME'], $usados)) { continue; }
    $g++;
    $nombre = isset($titulos[$VAL['NAME']]) ? $titulos[$VAL['NAME']] : $VAL['NAME'];
    $unidad = ($VAL['UNIT'] == "%%") ? "%" : $VAL['UNIT'];
    $ds_name[$g] = $nombre;
    $opt[$g]  = "--vertical-label \"" . $unidad . "\" -l 0 --title \"$hostname / $nombre\" ";
    if ($VAL['NAME'] == 'mem_pct' || $VAL['NAME'] == 'disco_pct') { $opt[$g] .= "-u 100 "; }
    $def[$g]  = rrd::def("v", $VAL['RRDFILE'], $VAL['DS'], "AVERAGE");
    $def[$g] .= rrd::area("v", "#5B9BD5", $nombre . " ");
    $def[$g] .= rrd::gprint("v", array("LAST", "MAX", "AVERAGE"), "%7.1lf " . $VAL['UNIT']);
    if ($VAL['MAX'] != "" && $VAL['NAME'] == 'disco_usado') {
        $def[$g] .= rrd::hrule($VAL['MAX'], "#7F7F7F", "Capacidad " . $VAL['MAX'] . " MB\\n");
    }
    if ($VAL['WARN'] != "") { $def[$g] .= rrd::hrule($VAL['WARN'], "#FFC000", "Warning  " . $VAL['WARN'] . "\\n"); }
    if ($VAL['CRIT'] != "") { $def[$g] .= rrd::hrule($VAL['CRIT'], "#FF0000", "Critical " . $VAL['CRIT'] . "\\n"); }
}
?>
