#!/usr/bin/env python3
"""
analizar.py
================================================================================
Script de análisis del experimento completo del Proyecto Apertura.

QUÉ HACE, DE PRINCIPIO A FIN:
  1) Lee el log crudo de todas las corridas (datos/resultados.csv).
  2) Calcula tiempo promedio + desviación estándar por cada combinación
     única de (version, n, k, hilos)  -> datos/resultados_promedio.csv
  3) Calcula el speedup de cada versión paralela contra la versión serial,
     para el mismo tamaño de problema n                -> datos/speedups.csv
  4) Imprime en consola un resumen rápido (top 10 speedups, promedio por
     versión) para revisar los números sin tener que abrir los CSV.
  5) Genera las 5 gráficas que se usan en el reporte, todas en graficas/.

No tiene funciones separadas (def) a propósito: es un script de análisis
de un solo uso, pensado para correrse una vez al final del experimento y
leerse de arriba hacia abajo como una receta. Por eso cada bloque está
etiquetado con su propio comentario de sección, a modo de "título de
función", explicando qué hace y por qué está ahí.

Uso:
    python3 experimentos/analizar.py
(se debe correr desde cualquier lado, encuentra las rutas solo porque usa
__file__ para ubicar la carpeta raíz del proyecto)
"""
import pandas as pd
import matplotlib
matplotlib.use("Agg")  # backend sin interfaz gráfica: aquí no hay pantalla, solo guardamos PNGs
import matplotlib.pyplot as plt
import numpy as np
import os

# ============================================================================
# SECCIÓN 0: localizar las rutas del proyecto y cargar el log crudo
# ============================================================================
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
df = pd.read_csv(os.path.join(BASE, "datos", "resultados.csv"))

# ============================================================================
# SECCIÓN 1: promedio y desviación estándar por configuración
# ----------------------------------------------------------------------------
# Agrupa las 10 iteraciones de cada combinación (version, n, k, hilos) en una
# sola fila con su tiempo promedio, su desviación estándar (qué tan ruidosa
# fue la medición) y cuántas iteraciones se usaron. Esto es lo que vuelve el
# experimento "estadísticamente serio": en vez de reportar una sola corrida
# (que puede salir rara por el sistema operativo haciendo otras cosas en ese
# instante), reportamos el promedio de 10.
# ============================================================================
g = df.groupby(["version", "n", "k", "hilos"])["tiempo_seg"].agg(["mean", "std", "count"]).reset_index()
g.rename(columns={"mean": "tiempo_prom", "std": "tiempo_std", "count": "n_iters"}, inplace=True)
g.to_csv(os.path.join(BASE, "datos", "resultados_promedio.csv"), index=False)

# ============================================================================
# SECCIÓN 2: cálculo de speedup (tiempo_serial / tiempo_version_paralela)
# ----------------------------------------------------------------------------
# El speedup es la métrica central del proyecto (NOTA 1 exige > 1.5x en al
# menos una versión paralela). Para cada fila paralela (p1 o p2) busca el
# tiempo serial promedio CON EL MISMO n y divide: speedup = t_serial / t_version.
# speedup > 1 significa "más rápido que serial"; < 1 significa "más lento".
# ============================================================================
serial = g[g.version == "serial"].set_index("n")["tiempo_prom"]

filas_speedup = []
for _, row in g.iterrows():
    if row.version == "serial":
        continue
    t_serial = serial.loc[row.n]
    speedup = t_serial / row.tiempo_prom
    filas_speedup.append({
        "version": row.version, "n": row.n, "k": row.k, "hilos": row.hilos,
        "tiempo_prom": row.tiempo_prom, "tiempo_serial": t_serial, "speedup": speedup
    })
sp = pd.DataFrame(filas_speedup)
sp.to_csv(os.path.join(BASE, "datos", "speedups.csv"), index=False)

# ============================================================================
# SECCIÓN 3: resumen impreso en consola (para revisión rápida sin abrir CSVs)
# ============================================================================
print("Máximo speedup global:")
print(sp.sort_values("speedup", ascending=False).head(10).to_string(index=False))
print()
print("Speedup promedio por versión:")
print(sp.groupby("version")["speedup"].mean())

# Valores de referencia usados por varias gráficas a continuación:
NS = sorted(df.n.unique())              # todos los tamaños n que se probaron
HILOS = sorted(df.hilos.unique())       # todos los números de hilos probados
KS = sorted(df[df.version == "p2"].k.unique())  # todos los valores de k (solo aplica a P2)
N_MAX = max(NS)                         # el n más grande (200,000) -> "caso representativo"
H_MAX = max(HILOS)                      # el máximo de hilos probado

GRAF = os.path.join(BASE, "graficas")
os.makedirs(GRAF, exist_ok=True)

COLOR_P1 = "#2E6F9E"
COLOR_P2 = "#B23A48"
COLOR_SERIAL = "#555555"

# ============================================================================
# GRÁFICA 1: Speedup vs. número de hilos (n = N_MAX fijo)
# ----------------------------------------------------------------------------
# Responde: "¿qué tanto ayuda agregar más hilos?" Se fija n al valor más
# grande para que el efecto de la paralelización sea más visible (con n chico
# el overhead de crear hilos puede dominar). Se compara P1 contra la mejor k
# de P2 en el número máximo de hilos probado.
# ============================================================================
fig, ax = plt.subplots(figsize=(7, 5))
p1_nmax = sp[(sp.version == "p1") & (sp.n == N_MAX)].sort_values("hilos")
ax.plot(p1_nmax.hilos, p1_nmax.speedup, "o-", color=COLOR_P1, label="P1 (matriz indivisible)")

# mejor k de P2 en el mayor número de hilos, para elegir una curva representativa
p2_nmax = sp[(sp.version == "p2") & (sp.n == N_MAX)]
mejor_k = p2_nmax[p2_nmax.hilos == H_MAX].sort_values("speedup", ascending=False).iloc[0].k
p2_mejor = p2_nmax[p2_nmax.k == mejor_k].sort_values("hilos")
ax.plot(p2_mejor.hilos, p2_mejor.speedup, "s-", color=COLOR_P2, label=f"P2 (k={int(mejor_k)})")

ax.axhline(1.5, color="gray", linestyle="--", linewidth=1, label="Umbral NOTA 1 (1.5x)")
ax.axhline(1.0, color="black", linestyle=":", linewidth=1)
ax.set_xlabel("Número de hilos")
ax.set_ylabel("Speedup vs. versión serial")
ax.set_title(f"Speedup vs. número de hilos (n = {N_MAX:,} puntos)")
ax.legend()
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(GRAF, "01_speedup_vs_hilos.png"), dpi=150)
plt.close(fig)

# ============================================================================
# GRÁFICA 2: Speedup vs. tamaño del problema n (hilos = H_MAX fijo)
# ----------------------------------------------------------------------------
# Responde: "¿el speedup se mantiene conforme el problema crece?" Fija el
# número de hilos al máximo probado y recorre todos los tamaños n.
# ============================================================================
fig, ax = plt.subplots(figsize=(7, 5))
p1_hmax = sp[(sp.version == "p1") & (sp.hilos == H_MAX)].sort_values("n")
ax.plot(p1_hmax.n, p1_hmax.speedup, "o-", color=COLOR_P1, label="P1")
p2_hmax = sp[(sp.version == "p2") & (sp.hilos == H_MAX) & (sp.k == mejor_k)].sort_values("n")
ax.plot(p2_hmax.n, p2_hmax.speedup, "s-", color=COLOR_P2, label=f"P2 (k={int(mejor_k)})")
ax.axhline(1.5, color="gray", linestyle="--", linewidth=1, label="Umbral NOTA 1 (1.5x)")
ax.set_xlabel("Número de puntos (n)")
ax.set_ylabel("Speedup vs. versión serial")
ax.set_title(f"Speedup vs. tamaño del problema (hilos = {H_MAX})")
ax.legend()
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(GRAF, "02_speedup_vs_n.png"), dpi=150)
plt.close(fig)

# ============================================================================
# GRÁFICA 3: P2 — speedup vs. k (número de bloques), para cada cantidad de hilos
# ----------------------------------------------------------------------------
# Responde: "¿cómo le afecta a P2 el valor de k que elijamos?" Una línea por
# cada cantidad de hilos probada, eje x en escala log base 2 porque k se
# probó en potencias de 2 (2,4,8,16,32,64).
# ============================================================================
fig, ax = plt.subplots(figsize=(7, 5))
for h in HILOS:
    sub = sp[(sp.version == "p2") & (sp.n == N_MAX) & (sp.hilos == h)].sort_values("k")
    ax.plot(sub.k, sub.speedup, "o-", label=f"{h} hilo(s)")
ax.set_xscale("log", base=2)
ax.set_xlabel("k (número de bloques)")
ax.set_ylabel("Speedup vs. versión serial")
ax.set_title(f"P2: speedup vs. k (n = {N_MAX:,} puntos)")
ax.legend()
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(os.path.join(GRAF, "03_speedup_p2_vs_k.png"), dpi=150)
plt.close(fig)

# ============================================================================
# GRÁFICA 4: tiempo de ejecución vs. n (serial, P1, P2 mejor k), escala log
# ----------------------------------------------------------------------------
# A diferencia de las gráficas 1-3 (que grafican SPEEDUP, un ratio), esta
# grafica TIEMPO ABSOLUTO en segundos, en escala logarítmica en el eje y
# (porque los tiempos van de ~0.04s a ~1.3s: en escala lineal las diferencias
# chicas en n bajo quedarían aplastadas).
# ============================================================================
fig, ax = plt.subplots(figsize=(7, 5))
ser = g[(g.version == "serial")].sort_values("n")
ax.plot(ser.n, ser.tiempo_prom, "^-", color=COLOR_SERIAL, label="Serial")
p1g = g[(g.version == "p1") & (g.hilos == H_MAX)].sort_values("n")
ax.plot(p1g.n, p1g.tiempo_prom, "o-", color=COLOR_P1, label=f"P1 ({H_MAX} hilos)")
p2g = g[(g.version == "p2") & (g.hilos == H_MAX) & (g.k == mejor_k)].sort_values("n")
ax.plot(p2g.n, p2g.tiempo_prom, "s-", color=COLOR_P2, label=f"P2 (k={int(mejor_k)}, {H_MAX} hilos)")
ax.set_xlabel("Número de puntos (n)")
ax.set_ylabel("Tiempo de ejecución promedio (s)")
ax.set_yscale("log")
ax.set_title("Tiempo de ejecución vs. tamaño del problema")
ax.legend()
ax.grid(alpha=0.3, which="both")
fig.tight_layout()
fig.savefig(os.path.join(GRAF, "04_tiempo_vs_n.png"), dpi=150)
plt.close(fig)

# ============================================================================
# GRÁFICA 5: comparación directa P1 vs. P2 (barras lado a lado, hilos = H_MAX)
# ----------------------------------------------------------------------------
# Para cada n, una barra de P1 y una barra de la MEJOR k de P2 en ese n
# (no siempre la misma k; busca la que dio mayor speedup para cada n por
# separado). Pensada como la gráfica "resumen" para cerrar la sección de
# resultados en la presentación.
# ============================================================================
fig, ax = plt.subplots(figsize=(8, 5))
width = 0.35
idx = np.arange(len(NS))
p1_vals = [sp[(sp.version == "p1") & (sp.n == n) & (sp.hilos == H_MAX)].speedup.values[0] for n in NS]
p2_vals = []
for n in NS:
    sub = sp[(sp.version == "p2") & (sp.n == n) & (sp.hilos == H_MAX)]
    p2_vals.append(sub.speedup.max())
ax.bar(idx - width/2, p1_vals, width, color=COLOR_P1, label="P1")
ax.bar(idx + width/2, p2_vals, width, color=COLOR_P2, label="P2 (mejor k)")
ax.axhline(1.5, color="gray", linestyle="--", linewidth=1)
ax.set_xticks(idx)
ax.set_xticklabels([f"{n//1000}k" for n in NS], rotation=0)
ax.set_xlabel("Número de puntos (n)")
ax.set_ylabel("Speedup vs. serial")
ax.set_title(f"Comparación P1 vs. P2 (hilos = {H_MAX})")
ax.legend()
ax.grid(alpha=0.3, axis="y")
fig.tight_layout()
fig.savefig(os.path.join(GRAF, "05_comparacion_p1_p2.png"), dpi=150)
plt.close(fig)

# ============================================================================
# SECCIÓN FINAL: resumen de parámetros usados, impreso en consola
# ============================================================================
print()
print(f"n usado como referencia grande: {N_MAX}")
print(f"hilos máximo: {H_MAX}")
print(f"mejor k para P2 (en n={N_MAX}, hilos={H_MAX}): {mejor_k}")
print("Gráficas guardadas en graficas/")
