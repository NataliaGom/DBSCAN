# DBSCAN paralelo para detección de ruido con OpenMP

Proyecto de **Cómputo Paralelo y en la Nube** que implementa una variante de dos etapas de DBSCAN para clasificar puntos bidimensionales y comparar una ejecución serial con dos estrategias paralelas en C++ y OpenMP.

> **Esta guía explica cómo compilar, ejecutar y analizar el proyecto en Linux** (por ejemplo, Ubuntu 22.04 o una distribución basada en Debian). Para la configuración nativa de Windows, consulta la carpeta [`Windows/`](Windows/), donde se documentará ese procedimiento por separado.

## 1. ¿Qué hace el proyecto?

Cada punto de entrada se clasifica como:

- `0`: ruido (*outlier*), si no satisface los criterios de las dos etapas.
- `1`: núcleo (*core*) de primer orden, si tiene suficientes vecinos en un radio `epsilon`.
- `2`: punto de borde o núcleo de segundo orden, si no cumple el umbral anterior pero se encuentra próximo a un punto de primer orden.

Las tres versiones implementan el mismo algoritmo de dos etapas (no asignan identificadores de clúster):

| Ejecutable | Implementación |
|---|---|
| `dbscan_serial` | Referencia secuencial. |
| `dbscan_p1` | Reparto dinámico de iteraciones con `#pragma omp parallel for schedule(dynamic,64)`. |
| `dbscan_p2` | División de puntos en `k` bloques, buffers locales y unión de resultados (*merge*). |

## 2. Estructura del repositorio

```text
DBSCAN/
├── Makefile                  # Compilación de los tres programas
├── src/                      # Código C++ y generador de puntos
├── bin/                      # Ejecutables (se recomienda recompilar en el equipo)
├── datos/                    # Datos de entrada y archivos de clasificación
├── experimentos/
│   ├── run_reanudable.sh     # Batería de mediciones
│   └── analizar.py           # Promedios, speedups y gráficas
├── graficas/                 # Gráficas del análisis
├── demos/                    # Demostraciones en Bash y guía PDF
├── pdfs/                     # Documentación técnica
└── Windows/                  # Archivos específicos para Windows
```

## 3. Requisitos en Linux

Se necesita **GCC/G++ con OpenMP**, GNU Make, Bash y Python 3. Para generar puntos y producir gráficas se usan `numpy`, `scikit-learn`, `pandas` y `matplotlib`.

En Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y build-essential python3 python3-pip python3-venv
```

Clona el repositorio y entra en la carpeta principal:

```bash
git clone https://github.com/NataliaGom/DBSCAN.git
cd DBSCAN
```

Crea un entorno de Python e instala dependencias:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install numpy scikit-learn pandas matplotlib
```

Puedes comprobar el entorno con `g++ --version`, `make --version` y `python3 --version`.

## 4. Compilar los programas

Desde la raíz del repositorio:

```bash
make
```

Esto debe generar:

```text
bin/dbscan_serial
bin/dbscan_p1
bin/dbscan_p2
```

Para forzar una compilación nueva en Linux, especialmente si `bin/` contiene ejecutables de otra plataforma:

```bash
make clean
make
```

El `Makefile` utiliza `g++` con `-O2 -fopenmp -std=c++17 -Wall` en Linux.

## 5. Generar o preparar los datos de entrada

Los archivos tienen **dos columnas numéricas** (`x,y`), separadas por comas y sin encabezado. El generador utiliza `make_blobs` con cuatro cúmulos, `cluster_std=0.06`, `center_box=(0,1.0)`, valor absoluto, inversión de coordenadas y redondeo a tres decimales, siguiendo el procedimiento de `DBSCAN_noise.ipynb`.

El repositorio ya contiene archivos `datos/puntos_<n>.csv`. Para generar uno de forma explícita usando la **semilla 11** del notebook:

```bash
python3 src/generar_puntos.py --n 20000 --salida datos/puntos_20000.csv --semilla 11
```

Para regenerar los ocho tamaños del experimento:

```bash
for n in 20000 40000 80000 120000 140000 160000 180000 200000; do
  python3 src/generar_puntos.py --n "$n" --salida "datos/puntos_${n}.csv" --semilla 11
done
```

> **Reproducibilidad:** el script `experimentos/run_reanudable.sh` genera automáticamente un CSV faltante usando `--semilla 42`, aunque el generador por defecto y el notebook oficial usan `11`. Por eso, **comprueba que los ocho CSV existan y hayan sido generados con semilla 11 antes de iniciar la batería**, o cambia conscientemente esa línea del script. No mezcles resultados obtenidos con datos distintos.

## 6. Ejecutar cada versión

Los siguientes ejemplos procesan **20,000 puntos**, con `epsilon=0.03` y `min_samples=10`. Se ejecutan desde la raíz del repositorio.

**Serial:**

```bash
./bin/dbscan_serial -i datos/puntos_20000.csv -o datos/salida_serial.csv -e 0.03 -m 10 -t 1
```

**Paralela P1 (4 hilos):**

```bash
./bin/dbscan_p1 -i datos/puntos_20000.csv -o datos/salida_p1.csv -e 0.03 -m 10 -t 4
```

**Paralela P2 (8 bloques, 4 hilos):**

```bash
./bin/dbscan_p2 -i datos/puntos_20000.csv -o datos/salida_p2.csv -e 0.03 -m 10 -k 8 -t 4
```

Opciones de línea de comandos:

| Opción | Descripción |
|---|---|
| `-i` | Ruta del CSV de entrada (obligatoria). |
| `-o` | Ruta del CSV de salida (obligatoria). |
| `-e` | Radio `epsilon` (valor de referencia: `0.03`). |
| `-m` | Número mínimo de vecinos (valor de referencia: `10`). |
| `-t` | Número de hilos para las versiones paralelas. |
| `-k` | Cantidad de bloques de P2. |
| `-q` | Omite la línea de medición `TIEMPO`. |

Cada ejecución muestra una línea similar a `TIEMPO p1,20000,1,4,0.012345`, con el tiempo de cómputo en **segundos** (el número es ilustrativo). El archivo de salida contiene `x,y,tipo`.

### Comprobar que las versiones clasifican igual

```bash
diff datos/salida_serial.csv datos/salida_p1.csv
diff datos/salida_serial.csv datos/salida_p2.csv
```

Si `diff` no muestra nada, las salidas son idénticas. Usa siempre el **mismo CSV de entrada y los mismos valores de `-e` y `-m`** en las tres versiones.

## 7. Ejecutar los experimentos completos

El script `experimentos/run_reanudable.sh` ejecuta 10 repeticiones por configuración en ocho tamaños (`n`), con `k = 2, 4, 8, 16, 32, 64` para P2. Las cantidades de hilos se calculan a partir de `nproc`: `1`, mitad, total y doble de procesadores lógicos, eliminando duplicados. **En una máquina que detecta 4 procesadores, usa `1, 2, 4, 8` y produce 2,320 mediciones.** En otras máquinas la lista puede cambiar y no necesariamente habrá 2,320 registros.

```bash
bash experimentos/run_reanudable.sh
```

El script guarda las mediciones en `datos/resultados.csv`, se detiene aproximadamente a los 165 segundos y **puede ejecutarse de nuevo** para continuar donde quedó. Repite el mismo comando hasta que aparezca `EXPERIMENTOS_COMPLETOS` y exista `datos/DONE`.

Para contar las líneas:

```bash
wc -l datos/resultados.csv
```

Con cuatro cantidades distintas de hilos, deben aparecer **2,321 líneas** (encabezado más 2,320 tiempos).

> Si `datos/resultados.csv` ya contiene mediciones, el script las conserva y solamente ejecuta configuraciones faltantes. Para realizar un experimento completamente nuevo, guarda una copia del CSV anterior y del archivo `datos/DONE` antes de empezar. Mantén el mismo hardware, parámetros y conjunto de puntos al comparar ejecuciones.

## 8. Calcular promedios, speedups y generar gráficas

Cuando termine la batería:

```bash
python3 experimentos/analizar.py
```

Este script lee `datos/resultados.csv` y genera:

- `datos/resultados_promedio.csv`: media, desviación estándar y número de repeticiones por configuración.
- `datos/speedups.csv`: aceleración de P1 y P2 frente al tiempo serial del **mismo tamaño de entrada**.
- Cinco imágenes en `graficas/`: aceleración frente a hilos, tamaño de entrada y `k`; tiempos frente a tamaño; comparación P1/P2.

La aceleración se calcula como:

\[
\text{speedup}=\frac{\text{tiempo promedio serial}}{\text{tiempo promedio paralelo}}
\]

Un valor mayor que `1` indica una mejora; el proyecto evalúa si al menos una estrategia supera `1.5x`.

## 9. Demostraciones para presentación

La carpeta `demos/` incluye scripts preparados para Bash:

```bash
bash demos/demo1_serial.sh
bash demos/demo2_p1.sh
bash demos/demo3_p2.sh
bash demos/demo4_comparativa.sh
```

Para la versión resumida:

```bash
bash demos/demo_rapido.sh
```

Consulta también [`demos/Guia_Demos_DBSCAN.pdf`](demos/Guia_Demos_DBSCAN.pdf). Las demos imprimen resultados y pueden generar CSV adicionales en `datos/`; **no sustituyen** las diez repeticiones por configuración del experimento formal. Algunas demostraciones incorporan pausas explicativas.

## 10. Notas para la interpretación

- **P1** paraleliza directamente iteraciones y evita buffers locales de clasificación.
- **P2** permite ajustar `k`, a cambio del trabajo de particionar y combinar (*merge*).
- Ambas implementaciones deben producir la misma clasificación para entradas y parámetros idénticos.
- Los tiempos dependen del hardware, del número de hilos, de `k`, de la distribución de puntos y de la actividad del sistema.
- No compares speedups de equipos diferentes como si fueran tiempos absolutos: cada speedup usa su propia referencia serial.

## 11. Documentación adicional

Revisa la carpeta [`pdfs/`](pdfs/) para la explicación técnica y documentos del proyecto, y [`vision_general.md`](vision_general.md) para una descripción general. La configuración de Windows se mantendrá independiente en [`Windows/`](Windows/).
