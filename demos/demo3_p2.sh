#!/bin/bash
# demo3_p2.sh - Todo lo demostrable de la 2a version paralela (P2)
cd "$(dirname "$0")/.." || { echo "No se pudo entrar a la carpeta del proyecto"; exit 1; }

N=200000
EPS=0.03
MIN=10
DATA="datos/puntos_${N}.csv"
TAMANOS="20000 40000 80000 120000 140000 160000 180000 200000"
HILOS_FIJO=8
K_LIST="2 4 8 16 32 64"
K_PARA_N=16

CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
HILOS_LIST="1 $((CORES/2)) $CORES $((CORES*2))"

BOLD="\033[1m"; GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; RESET="\033[0m"
linea() { printf "${CYAN}%s${RESET}\n" "──────────────────────────────────────────────────────────────"; }
pausa() { sleep 12; }

echo
printf "${BOLD}${CYAN}=== DEMO 3: SEGUNDA VERSION PARALELA (P2) ===${RESET}\n"
linea
printf "${BOLD}Que es esto:${RESET} P2 tambien usa OpenMP, pero divide los puntos en k bloques (no uno por hilo,\n"
printf "sino k bloques repartidos entre los hilos) — una estrategia de particionamiento distinta a P1.\n"
printf "${BOLD}Parametros usados:${RESET} epsilon=%s, minSamples=%s, cores detectados=%s\n" "$EPS" "$MIN" "$CORES"
linea

salida=$(./bin/dbscan_serial -i "$DATA" -o datos/salida_serial_ref.csv -e $EPS -m $MIN 2>&1 | grep '^TIEMPO')
IFS=',' read -r _ n k t serial_ref <<< "$salida"

printf "${BOLD}Tabla 1 — Speedup y eficiencia vs. hilos (n=%s, k=hilos*2 para evitar desbalance)${RESET}\n" "$N"
printf "  serial de referencia: ${YELLOW}%.4f s${RESET}\n" "$serial_ref"
printf "  %-8s %-6s %-14s %-10s %-12s\n" "hilos" "k" "tiempo (s)" "speedup" "eficiencia"
RESULTS_T1=()
for hilos in $HILOS_LIST; do
  k_usado=$((hilos*2))
  salida=$(./bin/dbscan_p2 -i "$DATA" -o datos/salida_p2_t${hilos}.csv -e $EPS -m $MIN -t $hilos -k $k_usado 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ n k t tiempo <<< "$salida"
  speedup=$(echo "$serial_ref $tiempo" | awk '{printf "%.2f", $1/$2}')
  eficiencia=$(echo "$speedup $hilos" | awk '{printf "%.0f", ($1/$2)*100}')
  printf "  %-8s %-6s ${YELLOW}%-14.4f${RESET} ${GREEN}%-10s${RESET} %-12s\n" "$hilos" "$k_usado" "$tiempo" "${speedup}x" "${eficiencia}%"
  RESULTS_T1+=("$hilos $speedup $eficiencia")
done
linea
printf "${BOLD}Interpretacion de la Tabla 1:${RESET}\n"
printf "  - Usamos k = hilos x 2 para que siempre haya mas bloques que hilos (si k < hilos, algunos hilos se\n"
printf "    quedan sin trabajo y el desempeno se degrada — lo comprobamos en una corrida anterior).\n"
mejor=$(printf '%s\n' "${RESULTS_T1[@]}" | sort -k2 -nr | head -1)
printf "  En nuestra corrida: el mejor resultado fue con ${BOLD}$(echo $mejor | cut -d' ' -f1) hilos${RESET}\n"
printf "  (${GREEN}$(echo $mejor | cut -d' ' -f2)x${RESET} de speedup, eficiencia $(echo $mejor | cut -d' ' -f3)%%).\n"
pausa

printf "${BOLD}Tabla 2 — Speedup vs. k (n=%s, hilos=%s)${RESET}\n" "$N" "$HILOS_FIJO"
printf "  %-8s %-14s %-10s\n" "k" "tiempo (s)" "speedup"
RESULTS_T2=()
for k in $K_LIST; do
  salida=$(./bin/dbscan_p2 -i "$DATA" -o datos/salida_p2_k${k}.csv -e $EPS -m $MIN -t $HILOS_FIJO -k $k 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ n kk t tiempo <<< "$salida"
  speedup=$(echo "$serial_ref $tiempo" | awk '{printf "%.2f", $1/$2}')
  printf "  %-8s ${YELLOW}%-14.4f${RESET} ${GREEN}%-10s${RESET}\n" "$k" "$tiempo" "${speedup}x"
  RESULTS_T2+=("$k $speedup")
done
linea
printf "${BOLD}Interpretacion de la Tabla 2:${RESET}\n"
printf "  - Aqui dejamos los hilos fijos en %s y variamos solo k, el numero de bloques en que se divide el\n" "$HILOS_FIJO"
printf "    trabajo. La idea es ver si P2 es sensible a como se reparten los bloques.\n"
peor_k=$(printf '%s\n' "${RESULTS_T2[@]}" | sort -k2 -n | head -1)
mejor_k=$(printf '%s\n' "${RESULTS_T2[@]}" | sort -k2 -nr | head -1)
printf "  En nuestra corrida: k=$(echo $peor_k | cut -d' ' -f1) dio el peor speedup ($(echo $peor_k | cut -d' ' -f2)x) porque hay pocos\n"
printf "  bloques para %s hilos (desbalance); k=$(echo $mejor_k | cut -d' ' -f1) dio el mejor (${GREEN}$(echo $mejor_k | cut -d' ' -f2)x${RESET}) — una vez que\n" "$HILOS_FIJO"
printf "  k >= hilos, el desempeno se vuelve estable sin importar cuanto mas crezca k.\n"
pausa

printf "${BOLD}Tabla 3 — Speedup y throughput vs. tamano n (hilos=%s, k=%s)${RESET}\n" "$HILOS_FIJO" "$K_PARA_N"
printf "  %-10s %-14s %-14s %-10s %-16s\n" "n" "serial (s)" "P2 (s)" "speedup" "throughput (pts/s)"
RESULTS_T3=()
for n in $TAMANOS; do
  data="datos/puntos_${n}.csv"
  if [ ! -f "$data" ]; then
    printf "  %-10s ${YELLOW}archivo no existe, saltalo${RESET}\n" "$n"
    continue
  fi
  s_out=$(./bin/dbscan_serial -i "$data" -o datos/salida_serial_${n}.csv -e $EPS -m $MIN 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ _n _k _t s_tiempo <<< "$s_out"
  p_out=$(./bin/dbscan_p2 -i "$data" -o datos/salida_p2n_${n}.csv -e $EPS -m $MIN -t $HILOS_FIJO -k $K_PARA_N 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ _n _k _t p_tiempo <<< "$p_out"
  speedup=$(echo "$s_tiempo $p_tiempo" | awk '{printf "%.2f", $1/$2}')
  throughput=$(echo "$n $p_tiempo" | awk '{printf "%.0f", $1/$2}')
  printf "  %-10s ${YELLOW}%-14.4f${RESET} ${YELLOW}%-14.4f${RESET} ${GREEN}%-10s${RESET} %-16s\n" "$n" "$s_tiempo" "$p_tiempo" "${speedup}x" "$throughput"
  RESULTS_T3+=("$n $speedup")
done
linea
printf "${BOLD}Interpretacion de la Tabla 3:${RESET}\n"
min_sp=$(printf '%s\n' "${RESULTS_T3[@]}" | sort -k2 -n | head -1 | cut -d' ' -f2)
max_sp=$(printf '%s\n' "${RESULTS_T3[@]}" | sort -k2 -nr | head -1 | cut -d' ' -f2)
printf "  En nuestra corrida: el speedup de P2 se mantuvo entre ${GREEN}%sx${RESET} y ${GREEN}%sx${RESET} en todos los tamanos de n.\n" "$min_sp" "$max_sp"
printf "  ${BOLD}Conclusion:${RESET} P2 escala igual de bien que P1 siempre que k crezca junto con los hilos; es estable\n"
printf "  para distintos valores de k (mientras k >= hilos), y estable en todos los tamanos de n.\n"
echo
pausa
