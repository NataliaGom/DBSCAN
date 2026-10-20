#!/bin/bash
# ==============================================================================
# run_reanudable.sh
# ==============================================================================
# QUÉ HACE: corre la rejilla COMPLETA de experimentos (serial + P1 + P2),
# combinando todos los valores de n, k (solo P2) e hilos, 10 iteraciones cada
# combinación, y va anexando cada tiempo medido a datos/resultados.csv.
#
# POR QUÉ ES "REANUDABLE" (y por qué existe este script en vez de uno simple):
# el entorno donde se corrió este experimento no deja que un proceso en
# segundo plano sobreviva más allá de una sola invocación de la terminal, así
# que un script normal de "corre todo de una sentada" se interrumpía a medio
# camino. La solución: este script se autolimita a ~165 segundos de reloj
# (LIMITE_SEG) y, antes de correr cada combinación, usa la función contar()
# para revisar cuántas de las 10 iteraciones YA están en resultados.csv — si
# ya están las 10, se salta esa combinación. Por eso se puede invocar una y
# otra vez (se corrió ~11 veces) hasta que aparece el archivo datos/DONE,
# que marca que la rejilla completa ya quedó registrada.
#
# ROL EN EL PROYECTO: es el script que generó TODO el archivo
# datos/resultados.csv (2,320 filas) que pide el enunciado como "archivo con
# los datos de los experimentos", y que después datos/analizar.py resume y
# convierte en gráficas.
# ==============================================================================
set -u
cd "$(dirname "$0")/.."
BIN=bin
EPS=0.03   # ajustado a la escala [0,1] de DBSCAN_noise.ipynb (misma eps que la libreta)
MINS=10    # mismo min_samples que la libreta oficial
ITERS=10
LIMITE_SEG=165
INICIO=$SECONDS

# Rejilla completa a cubrir: 8 tamaños de n, 6 valores de k (solo P2), y los
# hilos se calculan en automático a partir de nproc (1, mitad de cores,
# cores, doble de cores) para que el experimento se adapte a la máquina
# donde se corra, en vez de tener números fijos "a mano".
NS="20000 40000 80000 120000 140000 160000 180000 200000"
KS="2 4 8 16 32 64"
CORES=$(nproc)
HILOS=$(echo "1 $((CORES/2)) $CORES $((CORES*2))" | tr ' ' '\n' | sort -n -u | tr '\n' ' ')

OUT=datos/resultados.csv
[ -f "$OUT" ] || echo "version,n,k,hilos,iter,tiempo_seg" > "$OUT"

# ------------------------------------------------------------------------------
# FUNCIÓN: contar(version, n, k, hilos)
# QUÉ HACE: cuenta cuántas filas YA existen en resultados.csv para esa
# combinación exacta de (version,n,k,hilos). Es el mecanismo que hace posible
# reanudar: antes de correr una iteración, se le resta este número a ITERS
# para saber cuántas faltan (si ya hay 10, faltan 0, y no se corre nada).
# PARÁMETROS: $1=version ("serial"/"p1"/"p2"), $2=n, $3=k, $4=hilos
# ------------------------------------------------------------------------------
contar() {
    awk -F, -v v="$1" -v n="$2" -v k="$3" -v h="$4" \
        'NR>1 && $1==v && $2==n && $3==k && $4==h {c++} END{print c+0}' "$OUT"
}

terminado=1
for N in $NS; do
    # ------------------------------------------------------------------------
    # BLOQUE: preparar los datos de entrada para este n
    # Genera datos/puntos_<N>.csv con generar_puntos.py SOLO si todavía no
    # existe (para no regenerar puntos distintos entre invocaciones del
    # script — la semilla fija ya garantiza reproducibilidad, pero esto
    # además evita trabajo repetido).
    # ------------------------------------------------------------------------
    CSV="datos/puntos_${N}.csv"
    if [ ! -f "$CSV" ]; then
        python3 src/generar_puntos.py --n "$N" --salida "$CSV" --semilla 42 >/dev/null
    fi
    OUTTMP="/tmp/salida_tmp_${N}.csv"

    # ------------------------------------------------------------------------
    # BLOQUE: versión serial — línea base contra la que se mide el speedup
    # ------------------------------------------------------------------------
    ya=$(contar serial "$N" 1 1)
    faltan=$((ITERS - ya))
    for ((i=0; i<faltan; i++)); do
        if [ $((SECONDS - INICIO)) -ge $LIMITE_SEG ]; then terminado=0; break 3; fi
        T=$("$BIN/dbscan_serial" -i "$CSV" -o "$OUTTMP" -e $EPS -m $MINS -t 1 2>&1 >/dev/null | grep TIEMPO | cut -d, -f5)
        it=$((ya+i+1))
        echo "serial,$N,1,1,$it,$T" >> "$OUT"
    done

    # ------------------------------------------------------------------------
    # BLOQUE: versión P1 (matriz indivisible) — recorre cada cantidad de hilos
    # ------------------------------------------------------------------------
    for H in $HILOS; do
        ya=$(contar p1 "$N" 1 "$H")
        faltan=$((ITERS - ya))
        for ((i=0; i<faltan; i++)); do
            if [ $((SECONDS - INICIO)) -ge $LIMITE_SEG ]; then terminado=0; break 3; fi
            T=$("$BIN/dbscan_p1" -i "$CSV" -o "$OUTTMP" -e $EPS -m $MINS -t "$H" 2>&1 >/dev/null | grep TIEMPO | cut -d, -f5)
            it=$((ya+i+1))
            echo "p1,$N,1,$H,$it,$T" >> "$OUT"
        done
    done

    # ------------------------------------------------------------------------
    # BLOQUE: versión P2 (dividiendo la matriz por k) — recorre cada
    # combinación de k (número de bloques) y cantidad de hilos
    # ------------------------------------------------------------------------
    for K in $KS; do
        for H in $HILOS; do
            ya=$(contar p2 "$N" "$K" "$H")
            faltan=$((ITERS - ya))
            for ((i=0; i<faltan; i++)); do
                if [ $((SECONDS - INICIO)) -ge $LIMITE_SEG ]; then terminado=0; break 4; fi
                T=$("$BIN/dbscan_p2" -i "$CSV" -o "$OUTTMP" -e $EPS -m $MINS -k "$K" -t "$H" 2>&1 >/dev/null | grep TIEMPO | cut -d, -f5)
                it=$((ya+i+1))
                echo "p2,$N,$K,$H,$it,$T" >> "$OUT"
            done
        done
    done
done

# ------------------------------------------------------------------------------
# BLOQUE FINAL: marcar si la rejilla quedó completa o si hay que reinvocar
# ------------------------------------------------------------------------------
if [ "$terminado" -eq 1 ]; then
    touch datos/DONE
    echo "EXPERIMENTOS_COMPLETOS"
else
    echo "PARCIAL_continuar ($(wc -l < "$OUT") filas hasta ahora, $((SECONDS-INICIO))s usados)"
fi
