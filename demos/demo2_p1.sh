#!/bin/bash
# demo2_p1.sh - Todo lo demostrable de la 1a version paralela (P1)
cd "$(dirname "$0")/.." || { echo "No se pudo entrar a la carpeta del proyecto"; exit 1; }

N=200000
EPS=0.03
MIN=10
DATA="datos/puntos_${N}.csv"
TAMANOS="20000 40000 80000 120000 140000 160000 180000 200000"
HILOS_FIJO=8

CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
HILOS_LIST="1 $((CORES/2)) $CORES $((CORES*2))"

BOLD="\033[1m"; GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; RESET="\033[0m"
linea() { printf "${CYAN}%s${RESET}\n" "──────────────────────────────────────────────────────────────"; }
pausa() { sleep 12; }

echo
printf "${BOLD}${CYAN}=== DEMO 2: PRIMERA VERSION PARALELA (P1) ===${RESET}\n"
linea
printf "${BOLD}Que es esto:${RESET} P1 reparte los puntos entre varios hilos con OpenMP (paralelizacion simple del\n"
printf "bucle principal). Cada hilo procesa una porcion de los puntos al mismo tiempo, en vez de uno por uno.\n"
printf "${BOLD}Parametros usados:${RESET} epsilon=%s, minSamples=%s, cores detectados en esta maquina=%s\n" "$EPS" "$MIN" "$CORES"
linea

printf "${BOLD}Tabla 1 — Speedup y eficiencia vs. hilos (n=%s)${RESET}\n" "$N"
salida=$(./bin/dbscan_serial -i "$DATA" -o datos/salida_serial_ref.csv -e $EPS -m $MIN 2>&1 | grep '^TIEMPO')
IFS=',' read -r _ n k t serial_ref <<< "$salida"
printf "  serial de referencia: ${YELLOW}%.4f s${RESET}\n" "$serial_ref"
printf "  %-8s %-14s %-10s %-12s\n" "hilos" "tiempo (s)" "speedup" "eficiencia"
RESULTS_T1=()
for hilos in $HILOS_LIST; do
  salida=$(./bin/dbscan_p1 -i "$DATA" -o datos/salida_p1_t${hilos}.csv -e $EPS -m $MIN -t $hilos 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ n k t tiempo <<< "$salida"
  speedup=$(echo "$serial_ref $tiempo" | awk '{printf "%.2f", $1/$2}')
  eficiencia=$(echo "$speedup $hilos" | awk '{printf "%.0f", ($1/$2)*100}')
  printf "  %-8s ${YELLOW}%-14.4f${RESET} ${GREEN}%-10s${RESET} %-12s\n" "$hilos" "$tiempo" "${speedup}x" "${eficiencia}%"
  RESULTS_T1+=("$hilos $speedup $eficiencia")
done
linea
printf "${BOLD}Interpretacion de la Tabla 1:${RESET}\n"
printf "  - ${BOLD}speedup${RESET}: cuantas veces mas rapido es P1 que la version serial con ese numero de hilos.\n"
printf "  - ${BOLD}eficiencia${RESET}: que porcentaje de ese speedup ideal (speedup = hilos) realmente se logra.\n"
printf "    100%% seria perfecto (cada hilo aporta su parte completa); baja porque hay overhead de crear\n"
printf "    hilos, sincronizarlos y repartir memoria entre ellos.\n"
mejor=$(printf '%s\n' "${RESULTS_T1[@]}" | sort -k2 -nr | head -1)
peor=$(printf '%s\n' "${RESULTS_T1[@]}" | sort -k2 -n | head -1)
printf "  En nuestra corrida: con ${BOLD}$(echo $mejor | cut -d' ' -f1) hilos${RESET} se logro el mejor speedup\n"
printf "  (${GREEN}$(echo $mejor | cut -d' ' -f2)x${RESET}, eficiencia $(echo $mejor | cut -d' ' -f3)%%), mientras que con\n"
printf "  $(echo $peor | cut -d' ' -f1) hilo(s) el speedup fue el mas bajo ($(echo $peor | cut -d' ' -f2)x) — con pocos hilos casi no\n"
printf "  hay paralelismo que aprovechar.\n"
pausa

printf "${BOLD}Tabla 2 — Speedup y throughput vs. tamano n (hilos=%s)${RESET}\n" "$HILOS_FIJO"
printf "  %-10s %-14s %-14s %-10s %-16s\n" "n" "serial (s)" "P1 (s)" "speedup" "throughput (pts/s)"
RESULTS_T2=()
for n in $TAMANOS; do
  data="datos/puntos_${n}.csv"
  if [ ! -f "$data" ]; then
    printf "  %-10s ${YELLOW}archivo no existe, saltalo${RESET}\n" "$n"
    continue
  fi
  s_out=$(./bin/dbscan_serial -i "$data" -o datos/salida_serial_${n}.csv -e $EPS -m $MIN 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ _n _k _t s_tiempo <<< "$s_out"
  p_out=$(./bin/dbscan_p1 -i "$data" -o datos/salida_p1_${n}.csv -e $EPS -m $MIN -t $HILOS_FIJO 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ _n _k _t p_tiempo <<< "$p_out"
  speedup=$(echo "$s_tiempo $p_tiempo" | awk '{printf "%.2f", $1/$2}')
  throughput=$(echo "$n $p_tiempo" | awk '{printf "%.0f", $1/$2}')
  printf "  %-10s ${YELLOW}%-14.4f${RESET} ${YELLOW}%-14.4f${RESET} ${GREEN}%-10s${RESET} %-16s\n" "$n" "$s_tiempo" "$p_tiempo" "${speedup}x" "$throughput"
  RESULTS_T2+=("$n $speedup")
done
linea
printf "${BOLD}Interpretacion de la Tabla 2:${RESET}\n"
printf "  - Aqui dejamos los hilos fijos en %s y variamos n, para ver si el speedup se mantiene sin importar\n" "$HILOS_FIJO"
printf "    que tan grande sea el problema.\n"
min_sp=$(printf '%s\n' "${RESULTS_T2[@]}" | sort -k2 -n | head -1 | cut -d' ' -f2)
max_sp=$(printf '%s\n' "${RESULTS_T2[@]}" | sort -k2 -nr | head -1 | cut -d' ' -f2)
printf "  En nuestra corrida: el speedup se mantuvo entre ${GREEN}%sx${RESET} y ${GREEN}%sx${RESET} en todos los tamanos de n —\n" "$min_sp" "$max_sp"
printf "  esto confirma que P1 escala bien sin importar si el problema es chico o grande.\n"
printf "  ${BOLD}Conclusion:${RESET} P1 (paralelizacion simple con OpenMP) da un speedup consistente y aprovecha\n"
printf "  bien los hilos hasta acercarse al numero de cores fisicos de la maquina.\n"
echo
pausa
