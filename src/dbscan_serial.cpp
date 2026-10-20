// dbscan_serial.cpp
// Versión SERIAL (de referencia) del algoritmo ingenuo de detección de
// ruido/outliers tipo DBSCAN, descrito en el PDF del Proyecto Apertura:
//
//   Paso 1: para cada punto i, cuenta cuántos puntos j (de TODO el
//           conjunto) están a distancia <= epsilon. Si ese conteo es
//           >= minSamples, i es punto "core" (de primer orden).
//           Si no, i queda como candidato a ruido/outlier.
//
//   Paso 2: para cada punto que quedó como candidato a ruido, revisa si
//           está a distancia <= epsilon de ALGÚN punto core. Si es así,
//           se re-etiqueta como punto core (de segundo orden). Si no,
//           se queda como ruido/outlier definitivo.
//
// Complejidad: O(n^2) -- es intencionalmente el algoritmo "ingenuo" que
// pide el enunciado (sin estructuras espaciales tipo k-d tree), para que
// el costo de cómputo sea comparable entre las 3 versiones y el speedup
// se deba solamente a la paralelización, no a un algoritmo distinto.
#include "dbscan_common.h"
#include <omp.h>

int main(int argc, char** argv) {
    Parametros par;
    try {
        par = parsearArgumentos(argc, argv);
    } catch (const std::exception& e) {
        std::cerr << e.what() << "\n";
        return 1;
    }

    Puntos p = leerPuntosCSV(par.archivoEntrada);
    size_t n = p.n();
    std::vector<int> tipo(n, 0); // 0 = ruido, 1 = core 1er orden, 2 = core 2do orden

    double eps2 = par.epsilon * par.epsilon;

    double t0 = omp_get_wtime();

    // ---- Paso 1 ----
    for (size_t i = 0; i < n; i++) {
        int vecinos = 0;
        for (size_t j = 0; j < n; j++) {
            if (i == j) continue;
            if (dist2(p, i, j) <= eps2) {
                vecinos++;
                if (vecinos >= par.minSamples) break; // ya sabemos que es core, no hace falta seguir contando
            }
        }
        if (vecinos >= par.minSamples) tipo[i] = 1;
    }

    // Lista de puntos core (de primer orden) encontrados en el Paso 1.
    std::vector<size_t> core;
    core.reserve(n);
    for (size_t i = 0; i < n; i++) if (tipo[i] == 1) core.push_back(i);

    // ---- Paso 2 ----
    for (size_t i = 0; i < n; i++) {
        if (tipo[i] != 0) continue; // ya es core de primer orden
        for (size_t c : core) {
            if (dist2(p, i, c) <= eps2) {
                tipo[i] = 2;
                break;
            }
        }
    }

    double t1 = omp_get_wtime();

    escribirResultadoCSV(par.archivoSalida, p, tipo);

    if (par.medirTiempo) {
        // Formato fijo para que el script de experimentos lo pueda parsear:
        // version,n,k,hilos,tiempo_seg
        std::cerr << "TIEMPO serial," << n << ",1," << 1 << "," << (t1 - t0) << "\n";
    }
    return 0;
}
