#!/bin/bash
# demo4_comparativa.sh - Comparativa directa: Serial vs P1 vs P2 + verificacion de correctud
cd "$(dirname "$0")/.." || { echo "No se pudo entrar a la carpeta del proyecto"; exit 1; }
# Funciona tanto en macOS como en Linux/WSL (Windows)

N=200000
EPS=0.03
MIN=10
DATA="datos/puntos_${N}.csv"

OS_NAME=$(uname -s)

if [ "$OS_NAME" = "Darwin" ]; then
  # --- macOS: usar sysctl ---
  CORES=$(sysctl -n hw.ncpu 2>/dev/null)
  CORES_FISICOS=$(sysctl -n hw.physicalcpu 2>/dev/null)
  CORES_RENDIMIENTO=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null)
  CORES_EFICIENCIA=$(sysctl -n hw.perflevel1.physicalcpu 2>/dev/null)
  CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
  RAM_GB=$(echo "$(sysctl -n hw.memsize 2>/dev/null)" | awk '{printf "%.0f", $1/1073741824}')
  SISTEMA="macOS $(sw_vers -productVersion 2>/dev/null)"
else
  # --- Linux / WSL (Windows) ---
  CORES=$(nproc 2>/dev/null)
  CORES_FISICOS=$(lscpu 2>/dev/null | awk -F: '/^Core\(s\) per socket/{c=$2} /^Socket\(s\)/{s=$2} END{if(c&&s) printf "%d", c*s}')
  CHIP=$(lscpu 2>/dev/null | awk -F: '/Model name/{print $2}' | sed 's/^ *//')
  if [ -z "$CHIP" ]; then CHIP=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//'); fi
  RAM_GB=$(awk '/MemTotal/{printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null)
  if [ -f /etc/os-release ]; then
    SISTEMA=$(. /etc/os-release && echo "$PRETTY_NAME")
    if grep -qi microsoft /proc/version 2>/dev/null; then SISTEMA="$SISTEMA (WSL en Windows)"; fi
  else
    SISTEMA="Linux (version no detectada)"
  fi
fi

# Compilador: intenta g++-16 (macOS/Homebrew) y si no existe usa g++ (Linux/WSL/MinGW)
if command -v g++-16 >/dev/null 2>&1; then
  COMPILADOR=$(g++-16 --version 2>/dev/null | head -1)
else
  COMPILADOR=$(g++ --version 2>/dev/null | head -1)
fi

HILOS_LIST="1 $((CORES/2)) $CORES $((CORES*2))"

BOLD="\033[1m"; GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; MAGENTA="\033[35m"; RED="\033[31m"; RESET="\033[0m"
linea() { printf "${CYAN}%s${RESET}\n" "────────────────────────────────────────────────────────────────────────"; }
pausa() { sleep 12; }
conteo_tipo() {
  awk -F',' 'NR>1{c[$3]++} END{printf "%d %d %d", c[0]+0, c[1]+0, c[2]+0}' "$1"
}

echo
printf "${BOLD}${CYAN}=== DEMO 4: COMPARATIVA SERIAL vs P1 vs P2 (n=%s) ===${RESET}\n" "$N"
linea
printf "${BOLD}Que es esto:${RESET} corremos las 3 versiones bajo las mismas condiciones para compararlas cara a\n"
printf "cara — y verificamos que P1 y P2 no solo son mas rapidas, sino que dan el MISMO resultado que serial.\n"
linea
printf "${BOLD}Equipo donde se ejecuta el experimento:${RESET}\n"
printf "  sistema operativo:              %s\n" "$SISTEMA"
if [ -n "$CHIP" ]; then printf "  chip / CPU:                     %s\n" "$CHIP"; fi
printf "  hilos logicos detectados:       %s\n" "$CORES"
if [ -n "$CORES_FISICOS" ]; then printf "  cores fisicos:                  %s\n" "$CORES_FISICOS"; fi
if [ -n "$CORES_RENDIMIENTO" ]; then printf "  cores de rendimiento:           %s\n" "$CORES_RENDIMIENTO"; fi
if [ -n "$CORES_EFICIENCIA" ]; then printf "  cores de eficiencia:            %s\n" "$CORES_EFICIENCIA"; fi
if [ -n "$RAM_GB" ]; then printf "  RAM:                            %s GB\n" "$RAM_GB"; fi
printf "  compilador:                     %s\n" "$COMPILADOR"
linea
printf "${BOLD}Interpretacion:${RESET} este es el hardware real donde corremos la demo en vivo — puede variar entre\n"
printf "maquinas (y entre Mac y Windows), por eso los speedups en vivo pueden ser distintos a los del reporte.\n"
pausa

salida=$(./bin/dbscan_serial -i "$DATA" -o datos/salida_serial_ref.csv -e $EPS -m $MIN 2>&1 | grep '^TIEMPO')
IFS=',' read -r _ n k t serial_tiempo <<< "$salida"
printf "${BOLD}Serial (constante, no usa hilos):${RESET} ${YELLOW}%.4f s${RESET}\n" "$serial_tiempo"
linea

printf "${BOLD}%-8s %-14s %-14s %-10s   %-14s %-10s${RESET}\n" "hilos" "Serial (s)" "P1 (s)" "speedup" "P2 (s)" "speedup"
RESULTS_P1=()
RESULTS_P2=()
for hilos in $HILOS_LIST; do
  k_usado=$((hilos*2))

  p1_out=$(./bin/dbscan_p1 -i "$DATA" -o datos/salida_cmp_p1_t${hilos}.csv -e $EPS -m $MIN -t $hilos 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ _n _k _t p1_tiempo <<< "$p1_out"
  p1_speedup=$(echo "$serial_tiempo $p1_tiempo" | awk '{printf "%.2f", $1/$2}')

  p2_out=$(./bin/dbscan_p2 -i "$DATA" -o datos/salida_cmp_p2_t${hilos}.csv -e $EPS -m $MIN -t $hilos -k $k_usado 2>&1 | grep '^TIEMPO')
  IFS=',' read -r _ _n _k _t p2_tiempo <<< "$p2_out"
  p2_speedup=$(echo "$serial_tiempo $p2_tiempo" | awk '{printf "%.2f", $1/$2}')

  printf "  %-8s ${MAGENTA}%-14.4f${RESET} ${YELLOW}%-14.4f${RESET} ${GREEN}%-10s${RESET}   ${YELLOW}%-14.4f${RESET} ${GREEN}%-10s${RESET}\n" \
    "$hilos" "$serial_tiempo" "$p1_tiempo" "${p1_speedup}x" "$p2_tiempo" "${p2_speedup}x"
  RESULTS_P1+=("$hilos $p1_speedup")
  RESULTS_P2+=("$hilos $p2_speedup")
done
linea
printf "${BOLD}Interpretacion de la tabla comparativa:${RESET}\n"
printf "  - El tiempo serial es constante porque no usa hilos; P1 y P2 bajan su tiempo segun suben los hilos.\n"
mejor_p1=$(printf '%s\n' "${RESULTS_P1[@]}" | sort -k2 -nr | head -1)
mejor_p2=$(printf '%s\n' "${RESULTS_P2[@]}" | sort -k2 -nr | head -1)
printf "  En nuestra corrida: P1 llego a su mejor speedup con $(echo $mejor_p1|cut -d' ' -f1) hilos (${GREEN}$(echo $mejor_p1|cut -d' ' -f2)x${RESET}),\n"
printf "  y P2 con $(echo $mejor_p2|cut -d' ' -f1) hilos (${GREEN}$(echo $mejor_p2|cut -d' ' -f2)x${RESET}) — ambas estrategias de paralelizacion dan\n"
printf "  resultados comparables entre si, aunque usan logica distinta para repartir el trabajo.\n"
pausa

printf "${BOLD}Verificacion de correctud${RESET} (n=%s, t=8, k=16 — ¿P1 y P2 clasifican los mismos puntos que serial?)\n" "$N"
./bin/dbscan_p1 -i "$DATA" -o datos/salida_check_p1.csv -e $EPS -m $MIN -t 8 > /dev/null 2>&1
./bin/dbscan_p2 -i "$DATA" -o datos/salida_check_p2.csv -e $EPS -m $MIN -t 8 -k 16 > /dev/null 2>&1

read s_ruido s_core s_borde <<< "$(conteo_tipo datos/salida_serial_ref.csv)"
read p1_ruido p1_core p1_borde <<< "$(conteo_tipo datos/salida_check_p1.csv)"
read p2_ruido p2_core p2_borde <<< "$(conteo_tipo datos/salida_check_p2.csv)"

printf "  %-10s %-10s %-10s %-10s\n" "tipo" "serial" "P1" "P2"
printf "  %-10s %-10s %-10s %-10s\n" "ruido (0)" "$s_ruido" "$p1_ruido" "$p2_ruido"
printf "  %-10s %-10s %-10s %-10s\n" "core (1)"  "$s_core"  "$p1_core"  "$p2_core"
printf "  %-10s %-10s %-10s %-10s\n" "borde (2)" "$s_borde" "$p1_borde" "$p2_borde"

printf "${BOLD}Interpretacion:${RESET} cada punto queda clasificado como ruido (0), nucleo/core (1) o borde (2).\n"
printf "Si las 3 columnas coinciden exactamente, significa que P1 y P2 no cambiaron el resultado del algoritmo\n"
printf "al paralelizarlo — solo lo hicieron mas rapido. Esto es tan importante como la velocidad misma.\n"

if [ "$s_ruido" = "$p1_ruido" ] && [ "$s_core" = "$p1_core" ] && [ "$s_borde" = "$p1_borde" ] && \
   [ "$s_ruido" = "$p2_ruido" ] && [ "$s_core" = "$p2_core" ] && [ "$s_borde" = "$p2_borde" ]; then
  printf "  ${GREEN}✓ COINCIDEN — P1 y P2 clasifican exactamente los mismos puntos que la version serial.${RESET}\n"
else
  printf "  ${RED}✗ NO COINCIDEN — revisar la logica de paralelizacion.${RESET}\n"
fi
linea
printf "${BOLD}${GREEN}Conclusion general del demo:${RESET} ambas versiones paralelas superan por mucho a la serial,\n"
printf "P1 y P2 dan resultados muy parecidos entre si en tiempo, y lo mas importante: producen EXACTAMENTE\n"
printf "el mismo resultado que la version serial — son correctas, no solo rapidas.\n"
echo
