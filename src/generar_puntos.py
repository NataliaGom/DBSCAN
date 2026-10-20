#!/usr/bin/env python3
"""
generar_puntos.py
================================================================================
Genera un CSV de puntos aleatorios en 2D, siguiendo EXACTAMENTE el mismo
método que la libreta OFICIAL del curso (DBSCAN_noise.ipynb, repositorio
github.com/octavio-gutierrez/computoparalelo2026b), verificada el 17 de
octubre de 2026 directamente contra su código fuente.

MÉTODO DE LA LIBRETA (reproducido aquí sin cambios, solo parametrizado para
poder pedir distintos tamaños n desde la línea de comandos):

    from sklearn.datasets import make_blobs
    points, y_true = make_blobs(n_samples=n_points, centers=4,
                                 cluster_std=0.06, random_state=11,
                                 center_box=(0, 1.0))
    points = np.round(np.abs(points[:, ::-1]), 3)
    np.savetxt(f"{n_points}_data.csv", points, delimiter=",", fmt="%.3f")

NOTAS SOBRE LA FIDELIDAD AL ORIGINAL:
- Sin encabezado de texto, separador coma, 3 decimales -- igual que la
  libreta (nuestro lector en C++ ya detectaba esto automáticamente, pero
  ahora coincide también en el archivo real, no solo en la tolerancia).
- NO se agrega ruido uniforme a mano (a diferencia de una versión anterior
  de este script): el "ruido" que detecta DBSCAN surge naturalmente de la
  cola dispersa de cada cúmulo gaussiano (controlado por cluster_std=0.06),
  exactamente como en la libreta oficial.
- Los puntos quedan en el rango aproximado [0, 1.3] (center_box=(0,1.0)).
  Por eso epsilon/min_samples se ajustaron a esta escala: eps=0.03,
  min_samples=10 (los mismos valores que usa la libreta), ver
  experimentos/run_reanudable.sh.

Uso:
    python3 generar_puntos.py --n 20000 --salida puntos_20000.csv --semilla 11
================================================================================
"""
import argparse
import numpy as np
from sklearn.datasets import make_blobs


def generar(n, semilla):
    """Genera n puntos en 2D con el mismo método que DBSCAN_noise.ipynb:
    4 cúmulos gaussianos (centers=4, cluster_std=0.06) dentro de la caja
    [0,1]x[0,1], con valor absoluto y redondeo a 3 decimales."""
    points, _ = make_blobs(n_samples=n, centers=4, cluster_std=0.06,
                            random_state=semilla, center_box=(0, 1.0))
    points = np.round(np.abs(points[:, ::-1]), 3)
    return points


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, required=True, help="número de puntos a generar")
    ap.add_argument("--salida", type=str, required=True, help="ruta del CSV de salida")
    ap.add_argument("--semilla", type=int, default=11,
                     help="semilla aleatoria (11 = la misma que usa la libreta oficial)")
    args = ap.parse_args()

    points = generar(args.n, args.semilla)
    # Mismo formato exacto que np.savetxt(..., delimiter=",", fmt="%.3f") de la libreta:
    # sin encabezado, separador coma, 3 decimales.
    np.savetxt(args.salida, points, delimiter=",", fmt="%.3f")
    print(f"Generados {len(points)} puntos en {args.salida} (formato igual a DBSCAN_noise.ipynb)")


if __name__ == "__main__":
    main()
