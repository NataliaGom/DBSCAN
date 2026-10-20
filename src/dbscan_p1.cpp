// dbscan_p1.cpp
// Versión paralela P1: "matriz indivisible".
//
// Estrategia de paralelización: se toma el ciclo externo (uno por cada uno
// de los n puntos) y se reparte directamente entre los hilos con
// "#pragma omp parallel for", SIN dividir manualmente el conjunto de puntos
// en bloques. Es el propio runtime de OpenMP (con "schedule(dynamic)") el
// que decide, en tiempo de ejecución, qué iteraciones (puntos) le tocan a
// cada hilo. Se usa "dynamic" porque el costo de cada punto no es uniforme
// (un punto en zona densa cuesta más: hay que contar más vecinos antes de
// llegar al corte temprano), así que el reparto dinámico balancea mejor la
// carga que un reparto estático en bloques iguales.
//
// No hay condiciones de carrera: cada hilo solo escribe en tipo[i] para su
// propio índice i, así que no se necesitan secciones críticas ni locks.
// El único punto de sincronización es la barrera implícita al final de cada
// "#pragma omp parallel for": el Paso 2 no puede arrancar hasta que TODOS
// los hilos terminaron el Paso 1 y la lista global "core" esté completa
// (si no, algunos puntos de ruido podrían no alcanzar un core que otro
// hilo todavía no había etiquetado).
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

    omp_set_num_threads(par.hilos);

    Puntos p = leerPuntosCSV(par.archivoEntrada);
    size_t n = p.n();
    std::vector<int> tipo(n, 0);

    double eps2 = par.epsilon * par.epsilon;

    double t0 = omp_get_wtime();

    // ---- Paso 1 (paralelo, matriz completa indivisible) ----
    #pragma omp parallel for schedule(dynamic, 64)
    for (size_t i = 0; i < n; i++) {
        int vecinos = 0;
        for (size_t j = 0; j < n; j++) {
            if (i == j) continue;
            if (dist2(p, i, j) <= eps2) {
                vecinos++;
                if (vecinos >= par.minSamples) break;
            }
        }
        if (vecinos >= par.minSamples) tipo[i] = 1;
    }
    // barrera implícita del "parallel for": aquí ya terminaron todos los hilos

    std::vector<size_t> core;
    core.reserve(n);
    for (size_t i = 0; i < n; i++) if (tipo[i] == 1) core.push_back(i);

    // ---- Paso 2 (paralelo) ----
    #pragma omp parallel for schedule(dynamic, 64)
    for (size_t i = 0; i < n; i++) {
        if (tipo[i] != 0) continue;
        for (size_t idx = 0; idx < core.size(); idx++) {
            if (dist2(p, i, core[idx]) <= eps2) {
                tipo[i] = 2;
                break;
            }
        }
    }

    double t1 = omp_get_wtime();

    escribirResultadoCSV(par.archivoSalida, p, tipo);

    if (par.medirTiempo) {
        std::cerr << "TIEMPO p1," << n << ",1," << par.hilos << "," << (t1 - t0) << "\n";
    }
    return 0;
}
