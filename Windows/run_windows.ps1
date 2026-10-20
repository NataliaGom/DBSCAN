
# DBSCAN - Experimentos para Windows
# Conserva los experimentos originales de Linux.
# Ejecuta 2320 mediciones y permite reanudar.

$ErrorActionPreference = "Stop"

Set-Location (Join-Path $PSScriptRoot "..")

$BIN = "bin"
$EPS = "0.03"
$MINS = 10
$ITERS = 10

$NS = @(20000,40000,80000,120000,140000,160000,180000,200000)
$KS = @(2,4,8,16,32,64)
$HILOS = @(1,2,4,8)

$OUT = "datos\resultados_windows_2.csv"
$OUTTMP = "datos\salida_tmp_windows_2.csv"

if (!(Test-Path $OUT)) {
    "version,n,k,hilos,iter,tiempo_seg" |
        Set-Content $OUT -Encoding ASCII
}

# Leer experimentos que ya se completaron
$completados = @{}

Import-Csv $OUT | ForEach-Object {
    $clave = "$($_.version),$($_.n),$($_.k),$($_.hilos),$($_.iter)"
    $completados[$clave] = $true
}

function Ejecutar-Prueba {
    param(
        [string]$Version,
        [int]$N,
        [int]$K,
        [int]$H
    )

    $csv = "datos_profesor\puntos_${N}.csv"
    $exe = ".\bin\dbscan_$Version.exe"

    if (!(Test-Path $csv)) {
        throw "No existe el archivo: $csv"
    }

    for ($i = 1; $i -le $ITERS; $i++) {

        $clave = "$Version,$N,$K,$H,$i"

        if ($completados.ContainsKey($clave)) {
            continue
        }

        $archivoTiempo = Join-Path $env:TEMP "dbscan_tiempo_windows.txt"

        $proceso = Start-Process -FilePath $exe `
            -ArgumentList @("-i", $csv, "-o", $OUTTMP, "-e", $EPS, "-m", $MINS, "-k", $K, "-t", $H) `
            -RedirectStandardError $archivoTiempo `
            -Wait -PassThru -NoNewWindow

        $resultado = Get-Content $archivoTiempo

        if ($proceso.ExitCode -ne 0) {
            throw "Error ejecutando $Version con N=$N K=$K H=$H"
        }

        $linea = $resultado |
            Where-Object { $_ -match "TIEMPO" } |
            Select-Object -First 1

        if (!$linea) {
            throw "No se encontro TIEMPO en la salida de $Version"
        }

        $partes = ([string]$linea).Trim().Split(",")
        $tiempo = $partes[-1].Trim()

        if ($tiempo -notmatch '^\d+(\.\d+)?$') {
            throw "Tiempo invalido: $tiempo"
        }

        "$Version,$N,$K,$H,$i,$tiempo" |
            Add-Content $OUT -Encoding ASCII

        $completados[$clave] = $true

        Write-Host "$Version N=$N K=$K H=$H Iter=$i Tiempo=$tiempo"
    }
}

foreach ($N in $NS) {

    Write-Host "`n===== N = $N ====="

    Ejecutar-Prueba -Version "serial" -N $N -K 1 -H 1

    foreach ($H in $HILOS) {
        Ejecutar-Prueba -Version "p1" -N $N -K 1 -H $H
    }

    foreach ($K in $KS) {
        foreach ($H in $HILOS) {
            Ejecutar-Prueba -Version "p2" -N $N -K $K -H $H
        }
    }
}

Write-Host "`nEXPERIMENTOS COMPLETOS"
