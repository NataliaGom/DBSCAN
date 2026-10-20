#!/bin/bash
# demo1_serial.sh - Todo lo demostrable de la version SERIAL
cd "$(dirname "$0")/.." || { echo "No se pudo entrar a la carpeta del proyecto"; exit 1; }

EPS=0.03
MIN=10
TAMANOS="20000 40000 80000 120000 140000 160000 180000 200000"

BOLD="\033[1m"; GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; MAGENTA="\033[35m"; RESET="\033[0m"
linea() { printf "${CYAN}%s${RESET}\n" "──────────────────────────────────────────────────────────────"; }
pausa() { sleep 12; }

echo
printf "${BOLD}${CYAN}=== DEMO 1: VERSION SERIAL ===${RESET}\n"
linea
printf "${BOLD}Que es esto:${RESET} la version serial corre DBSCAN sin ningun paralelismo — un solo hilo recorre\n"
printf "todos los puntos uno por uno. Es la LINEA BASE: todo lo demas (P1, P2) se compara contra estos tiempos.\n"
printf "${BOLD}Parametros usados:${RESET} epsilon=%s (radio de vecindad), minSamples=%s (minimo de vecinos para ser nucleo)\n" "$EPS" "$MIN"
linea
printf "${BOLD}Tiempo serial segun tamano del problema (n)${RESET}\n"
printf "  %-10s %-14s %-16s %-14s\n" "n" "tiempo (s)" "throughput (pts/s)" "crecimiento"

prev=""
first_tiempo=""
for n in $TAMANOS; do
  data="datos/puntos_${n}.csv"
  if [ ! -f "$data" ]; then
    printf "  %-10s ${YELLOW}archivo no existe, saltalo${RESET}\n" "$n"
    continue
  fi
  salida=$(./bin/dbscan_serial -i "$data" -o datos/salida_serial_${n}.csv -e $EPS -m $MIN 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ _n _k _t tiempo <<< "$salida"
  throughput=$(echo "$n $tiempo" | awk '{printf "%.0f", $1/$2}')
  if [ -n "$prev" ]; then
    factor=$(echo "$tiempo $prev" | awk '{printf "%.2fx", $1/$2}')
  else
    factor="-"
    first_tiempo=$tiempo
  fi
  printf "  %-10s ${YELLOW}%-14.4f${RESET} %-16s ${MAGENTA}%-14s${RESET}\n" "$n" "$tiempo" "$throughput" "$factor"
  prev=$tiempo
  last_tiempo=$tiempo
done
linea
printf "${BOLD}Interpretacion de lo que acabamos de correr:${RESET}\n"
printf "  - ${BOLD}tiempo (s)${RESET}: cuanto tarda el algoritmo completo (sin paralelismo) en procesar n puntos.\n"
printf "  - ${BOLD}throughput${RESET}: cuantos puntos procesa por segundo — a mas n, deberia bajar un poco por el\n"
printf "    trabajo extra de comparar cada punto contra mas vecinos.\n"
printf "  - ${BOLD}crecimiento${RESET}: cuanto mas tarda cada tamano respecto al anterior.\n"
ratio=$(echo "$last_tiempo $first_tiempo" | awk '{printf "%.1f", $1/$2}')
printf "  En nuestra corrida: al pasar de n=20,000 a n=200,000 (10 veces mas puntos), el tiempo serial\n"
printf "  paso de ${YELLOW}%.4fs${RESET} a ${YELLOW}%.4fs${RESET} — %sx mas lento. " "$first_tiempo" "$last_tiempo" "$ratio"
cmp=$(echo "$ratio" | awk '{print ($1<=11 && $1>=9)?"lineal":($1<9?"mejor que lineal":"peor que lineal")}')
printf "Esto es aproximadamente ${BOLD}%s${RESET} respecto al tamano del problema,\n" "$cmp"
printf "  lo cual tiene sentido para un algoritmo de clustering por vecindad como DBSCAN.\n"
printf "  ${BOLD}Conclusion:${RESET} esta es la version que P1 y P2 tienen que superar — y lo hacen por varias veces, como\n"
printf "  vamos a ver en los siguientes demos.\n"
echo
pausa
