#!/bin/bash
# demo_rapido.sh - Version corta de respaldo: solo lo esencial (serial + comparativa) si el tiempo apremia
cd "$(dirname "$0")" || { echo "No se pudo entrar a la carpeta demos/"; exit 1; }

echo
echo "=== VERSION RAPIDA: corre Demo 1 (serial) y Demo 4 (comparativa + correctud) ==="
echo "    Si necesitas los detalles de P1 o P2 por separado, corre demo2_p1.sh / demo3_p2.sh aparte."
echo

./demo1_serial.sh
./demo4_comparativa.sh
