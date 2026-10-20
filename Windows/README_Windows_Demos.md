# Ejecutar DBSCAN en Windows con WSL (demos)

Esta guía explica cómo **clonar y ejecutar el proyecto desde cero en Windows** utilizando **Ubuntu mediante WSL**. Se ejecutan los demos originales (`.sh`) y se aprovechan los puntos que **ya están incluidos en `datos/`**: no hay que generarlos otra vez.

> **Importante:** los comandos de Ubuntu se escriben en la terminal **Ubuntu/WSL**, no en PowerShell. Los ejecutables compilados en Linux/WSL no son archivos `.exe`.

## 1. Instalar WSL y Ubuntu (solo la primera vez)

Abre **PowerShell como administrador** y ejecuta:

```powershell
wsl --install
```

Reinicia Windows si se solicita. Abre **Ubuntu** desde Inicio y crea el usuario y contraseña de Linux cuando te lo pida. Si ya tienes Ubuntu/WSL configurado, salta al paso 2.

## 2. Instalar las herramientas necesarias

Dentro de la terminal **Ubuntu**, ejecuta:

```bash
sudo apt update
sudo apt install -y git build-essential
```

Esto instala Git, `g++`, `make` y las herramientas necesarias para compilar C++ con OpenMP.

## 3. Clonar el repositorio

En **Ubuntu**, ejecuta:

```bash
cd ~
git clone https://github.com/NataliaGom/DBSCAN.git
cd DBSCAN
```

Comprueba que estás en la raíz del proyecto:

```bash
ls
```

Deberías ver carpetas como `src/`, `datos/`, `demos/`, `experimentos/` y el archivo `Makefile`.

## 4. Compilar las tres versiones

Desde la raíz `DBSCAN/`, ejecuta:

```bash
make
```

Comprueba que se crearon los programas:

```bash
ls bin/
```

Deberían aparecer:

```text
dbscan_serial  dbscan_p1  dbscan_p2
```

> Si el repositorio contiene ejecutables anteriores, puedes recompilar con `make clean && make`. **No utilices** `Windows/Makefile` dentro de Ubuntu: ese archivo es para Windows nativo con MinGW.

## 5. Comprobar los datos de entrada

Los archivos CSV de puntos **ya están creados** y están en `datos/`. Compruébalo con:

```bash
ls datos/puntos_*.csv
```

No necesitas ejecutar `generar_puntos.py` ni instalar bibliotecas de Python para correr los demos.

## 6. Ejecutar los demos

Da permisos de ejecución a los scripts (solo hace falta una vez):

```bash
chmod +x demos/*.sh
```

Luego, desde la raíz del proyecto, ejecuta el demo que quieras:

```bash
./demos/demo1_serial.sh
./demos/demo2_p1.sh
./demos/demo3_p2.sh
./demos/demo4_comparativa.sh
```

También hay una versión corta para la presentación:

```bash
./demos/demo_rapido.sh
```

**Qué hace cada uno:**

| Demo | Descripción |
|---|---|
| `demo1_serial.sh` | Ejecuta y explica la versión serial. |
| `demo2_p1.sh` | Ejecuta la paralelización P1 con OpenMP. |
| `demo3_p2.sh` | Ejecuta P2 con partición en bloques `k`. |
| `demo4_comparativa.sh` | Compara serial, P1 y P2; muestra tiempos, *speedups*, datos del equipo y conteos de clasificación. |
| `demo_rapido.sh` | Ejecuta una demostración resumida (demos 1 y 4). |

Los demos **pueden tardar** porque incluyen explicaciones y pausas. La cantidad de hilos utilizada en la comparativa se calcula a partir de los procesadores detectados por WSL; por eso los tiempos y *speedups* cambiarán entre computadoras.

## 7. ¿Dónde quedan los archivos de salida?

Los demos guardan sus resultados en la carpeta **`datos/`** del repositorio. Por ejemplo, el demo comparativo crea archivos como:

```text
datos/salida_serial_ref.csv
datos/salida_cmp_p1_t1.csv
datos/salida_cmp_p2_t1.csv
datos/salida_check_p1.csv
datos/salida_check_p2.csv
```

El nombre exacto de algunos archivos depende de los hilos utilizados. Para ver los CSV que se han creado:

```bash
ls -lh datos/salida_*.csv
```

Para abrir uno de ellos en la terminal:

```bash
head datos/salida_serial_ref.csv
```

Los archivos de clasificación contienen las columnas **`x,y,tipo`**, donde `0` es ruido, `1` es núcleo (*core*) de primer orden y `2` es punto de borde o núcleo de segundo orden. **No son el registro de tiempos de las 2,320 mediciones**; esos experimentos se realizan con otro script.

Para navegar a los archivos desde el Explorador de Windows, estando en Ubuntu dentro de `DBSCAN`, ejecuta:

```bash
explorer.exe .
```

## 8. Problemas frecuentes

- **`make: command not found`**: ejecuta `sudo apt install -y build-essential`.
- **`Permission denied` al abrir un demo**: ejecuta `chmod +x demos/*.sh`.
- **`datos/puntos_200000.csv` no existe**: verifica que clonaste el repositorio completo y que estás en la raíz `DBSCAN/`.
- **El resultado tarda o parece detenido**: algunos demos incluyen pausas intencionales; espera a que continúe.
- **Quieres repetir los 2,320 experimentos**: utiliza `experimentos/run_reanudable.sh` y después `experimentos/analizar.py` desde la raíz, pero primero revisa si existe `datos/resultados.csv` para no mezclar o reutilizar mediciones anteriores.

---

**Nota sobre Windows nativo:** esta guía usa **WSL**, no MinGW/PowerShell. El archivo `Windows/Makefile` y el script `Windows/run_windows.ps1` corresponden a la alternativa de ejecución nativa de Windows, no a estos demos Bash.
