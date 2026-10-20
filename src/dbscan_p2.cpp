// dbscan_p2.cpp
// Versión paralela P2: "dividiendo la matriz por k".
//
// Estrategia de paralelización: a diferencia de P1 (que deja que OpenMP
// reparta los n puntos "al vuelo"), aquí el conjunto de puntos se divide
// MANUALMENTE en k bloques contiguos de tamaño ~n/k (k es un parámetro
// independiente del número de hilos: puede haber más bloques que hilos,
// en cuyo caso varios bloques se procesan uno tras otro en el mismo hilo).
// Cada bloque se procesa de forma totalmente local: escribe su resultado
// en un buffer propio (tipoLocal[bloque]), y solo al terminar TODOS los
// bloques se hace un paso explícito de "merge" que copia cada buffer local
// al arreglo global "tipo". Este patrón de map (bloques independientes) +
// merge (unión de resultados) imita cómo se tendría que resolver el mismo
// problema si los bloques vivieran en procesos/máquinas distintas (como en
// MPI), aunque aquí todo corre en memoria compartida con OpenMP.
//
// Consistencia entre bloques: el Paso 1 de cada bloque es independiente
// (compara sus puntos contra TODO el arreglo global de puntos, así que el
// resultado no depende de en qué bloque haya quedado cada punto). El punto
// delicado es el Paso 2: un punto de un bloque puede volverse "core de
// segundo orden" gracias a un punto core que un OTRO bloque encontró en su
// Paso 1. Por eso el merge de la lista global de puntos core se hace como
// una barrera dura entre el Paso 1 y el Paso 2: ningún bloque empieza su
// Paso 2 hasta que el merge de TODOS los bloques del Paso 1 terminó.
#include "dbscan_common.h"
#include <omp.h>
#include <algorithm>

int main(int argc, char** argv) {
    Parametros par;
    try {
        par = parsearArgumentos(argc, argv);
    } catch (const std::exception& e) {
        std::cerr << e.what() << "\n";
        return 1;
    }

    omp_set_num_threads(par.hilos);

    Puntos p = leerPuntosCSV(par.archivoEntrada);
    size_t n = p.n();
    int k = std::max(1, par.k);
    if ((size_t)k > n) k = (int)n;

    std::vector<int> tipo(n, 0);
    double eps2 = par.epsilon * par.epsilon;

    // Límites de cada uno de los k bloques (contiguos, tamaño ~n/k).
    std::vector<size_t> inicioBloque(k + 1);
    for (int b = 0; b <= k; b++) inicioBloque[b] = (n * (size_t)b) / k;

    double t0 = omp_get_wtime();

    // ---- Paso 1: cada bloque se procesa de forma independiente ----
    // (se guarda en un buffer local por bloque; el merge al arreglo global
    // se hace explícitamente después, fuera de la región paralela).
    std::vector<std::vector<int>> tipoLocalP1(k);
    #pragma omp parallel for schedule(dynamic)
    for (int b = 0; b < k; b++) {
        size_t ini = inicioBloque[b], fin = inicioBloque[b + 1];
        std::vector<int> local(fin - ini, 0);
        for (size_t i = ini; i < fin; i++) {
            int vecinos = 0;
            for (size_t j = 0; j < n; j++) {
                if (i == j) continue;
                if (dist2(p, i, j) <= eps2) {
                    vecinos++;
                    if (vecinos >= par.minSamples) break;
                }
            }
            if (vecinos >= par.minSamples) local[i - ini] = 1;
        }
        tipoLocalP1[b] = std::move(local);
    }

    // ---- Merge explícito: se unen los k resultados locales en "tipo" ----
    for (int b = 0; b < k; b++) {
        size_t ini = inicioBloque[b];
        for (size_t idx = 0; idx < tipoLocalP1[b].size(); idx++)
            tipo[ini + idx] = tipoLocalP1[b][idx];
    }

    std::vector<size_t> core;
    core.reserve(n);
    for (size_t i = 0; i < n; i++) if (tipo[i] == 1) core.push_back(i);

    // ---- Paso 2: de nuevo por bloques, usando ya la lista global de core ----
    std::vector<std::vector<int>> tipoLocalP2(k);
    #pragma omp parallel for schedule(dynamic)
    for (int b = 0; b < k; b++) {
        size_t ini = inicioBloque[b], fin = inicioBloque[b + 1];
        std::vector<int> local(fin - ini, 0);
        for (size_t i = ini; i < fin; i++) {
            if (tipo[i] != 0) { local[i - ini] = tipo[i]; continue; }
            int encontrado = 0;
            for (size_t idx = 0; idx < core.size(); idx++) {
                if (dist2(p, i, core[idx]) <= eps2) { encontrado = 2; break; }
            }
            local[i - ini] = encontrado;
        }
        tipoLocalP2[b] = std::move(local);
    }

    // ---- Merge final ----
    for (int b = 0; b < k; b++) {
        size_t ini = inicioBloque[b];
        for (size_t idx = 0; idx < tipoLocalP2[b].size(); idx++)
            tipo[ini + idx] = tipoLocalP2[b][idx];
    }

    double t1 = omp_get_wtime();

    escribirResultadoCSV(par.archivoSalida, p, tipo);

    if (par.medirTiempo) {
        std::cerr << "TIEMPO p2," << n << "," << k << "," << par.hilos << "," << (t1 - t0) << "\n";
    }
    return 0;
}
