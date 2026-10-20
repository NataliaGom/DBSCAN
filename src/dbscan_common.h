// dbscan_common.h
// Funciones compartidas por las 3 versiones (serial, P1, P2) del detector
// de ruido/outliers basado en DBSCAN (algoritmo "ingenuo", ver Paso 1 y Paso 2
// del PDF del Proyecto Apertura).
//
// Formato de entrada (CSV): cabecera "x,y" seguida de una fila por punto.
// Formato de salida (CSV): cabecera "x,y,tipo" donde tipo es:
//    0 = ruido / outlier
//    1 = punto core (de primer orden)
//    2 = punto core (de segundo orden, re-etiquetado en el Paso 2)
#pragma once
#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <stdexcept>
#include <cstdlib>

struct Puntos {
    std::vector<double> x;
    std::vector<double> y;
    size_t n() const { return x.size(); }
};

// Lee un CSV con cabecera "x,y" (acepta cabecera opcional, la detecta sola).
inline Puntos leerPuntosCSV(const std::string& ruta) {
    std::ifstream in(ruta);
    if (!in.is_open()) {
        throw std::runtime_error("No se pudo abrir el archivo de entrada: " + ruta);
    }
    Puntos p;
    std::string linea;
    bool primera = true;
    while (std::getline(in, linea)) {
        if (linea.empty()) continue;
        if (primera) {
            primera = false;
            // si la primera celda no es numérica, asumimos que es cabecera
            char c = linea[0];
            if (!(std::isdigit((unsigned char)c) || c == '-' || c == '+' || c == '.')) {
                continue;
            }
        }
        std::stringstream ss(linea);
        std::string a, b;
        if (!std::getline(ss, a, ',')) continue;
        if (!std::getline(ss, b, ',')) continue;
        p.x.push_back(std::stod(a));
        p.y.push_back(std::stod(b));
    }
    return p;
}

// Escribe el CSV de salida con la clasificación de cada punto.
inline void escribirResultadoCSV(const std::string& ruta, const Puntos& p,
                                  const std::vector<int>& tipo) {
    std::ofstream out(ruta);
    if (!out.is_open()) {
        throw std::runtime_error("No se pudo abrir el archivo de salida: " + ruta);
    }
    out << "x,y,tipo\n";
    out.precision(10);
    for (size_t i = 0; i < p.n(); i++) {
        out << p.x[i] << "," << p.y[i] << "," << tipo[i] << "\n";
    }
}

// Distancia euclidiana al cuadrado (evitamos sqrt en el ciclo caliente).
inline double dist2(const Puntos& p, size_t i, size_t j) {
    double dx = p.x[i] - p.x[j];
    double dy = p.y[i] - p.y[j];
    return dx * dx + dy * dy;
}

struct Parametros {
    std::string archivoEntrada;
    std::string archivoSalida;
    double epsilon = 0.03;  // ajustado a la escala [0,1] de DBSCAN_noise.ipynb (eps=0.03 en la libreta)
    int minSamples = 10;    // mismo valor que usa DBSCAN_noise.ipynb (min_samples=10)
    int k = 4;        // número de bloques (solo usado por la versión P2)
    int hilos = 1;    // número de hilos OpenMP solicitados
    bool medirTiempo = true;
};

// Parseo simple de argumentos de línea de comandos, común a los 3 programas.
// Uso: programa -i entrada.csv -o salida.csv -e epsilon -m minSamples -k k -t hilos
inline Parametros parsearArgumentos(int argc, char** argv) {
    Parametros par;
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        auto next = [&](const char* nombre) -> std::string {
            if (i + 1 >= argc) throw std::runtime_error(std::string("Falta valor para ") + nombre);
            return argv[++i];
        };
        if (arg == "-i") par.archivoEntrada = next("-i");
        else if (arg == "-o") par.archivoSalida = next("-o");
        else if (arg == "-e") par.epsilon = std::stod(next("-e"));
        else if (arg == "-m") par.minSamples = std::stoi(next("-m"));
        else if (arg == "-k") par.k = std::stoi(next("-k"));
        else if (arg == "-t") par.hilos = std::stoi(next("-t"));
        else if (arg == "-q") par.medirTiempo = false;
        else {
            std::cerr << "Argumento desconocido: " << arg << "\n";
        }
    }
    if (par.archivoEntrada.empty() || par.archivoSalida.empty()) {
        throw std::runtime_error(
            "Uso: programa -i entrada.csv -o salida.csv [-e epsilon] [-m minSamples] [-k bloques] [-t hilos]");
    }
    return par;
}
