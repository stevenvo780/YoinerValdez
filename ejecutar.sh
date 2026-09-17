#!/bin/bash
# Uso sencillo del proyecto OHLCMTF. Ejecutar desde una terminal:  ./ejecutar.sh
# Sin argumentos muestra un menú. Con argumento ejecuta directo: ./ejecutar.sh instalar | datos | validar | tests | reporte ARCHIVO | compilar
set -e
cd "$(dirname "$0")"
PY=ohlc_quant/.venv/bin/python

instalar() {
  echo "▶ Creando entorno Python e instalando dependencias (una sola vez, 2-5 minutos)..."
  python3 -m venv ohlc_quant/.venv
  ohlc_quant/.venv/bin/pip install --quiet --upgrade pip
  ohlc_quant/.venv/bin/pip install --quiet -e "ohlc_quant[dev]"
  echo "✔ Listo."
}
datos() {
  echo "▶ Descargando velas M1 de XAUUSD (Dukascopy) 2023-01-01 → hoy. Tarda 30-60 minutos; se puede interrumpir y reanudar."
  $PY ohlc_quant/scripts/download_candles.py 2023-01-01 "$(date +%Y-%m-%d)" 2
}
validar() {
  echo "▶ Validación completa (5 minutos en 32 núcleos). Resultado: ohlc_quant/reports/full/VALIDACION.md"
  $PY ohlc_quant/scripts/validate_full.py
  echo "✔ Informe en ohlc_quant/reports/full/VALIDACION.md"
}
tests() {
  echo "▶ Ejecutando los 95 tests del motor..."
  cd ohlc_quant && .venv/bin/python -m pytest -q -n 8 -p no:warnings
}
reporte() {
  [ -z "$1" ] && { echo "Uso: ./ejecutar.sh reporte RUTA/ReportTester-XXXX.xlsx"; exit 1; }
  echo "▶ Analizando el reporte del Strategy Tester: $1"
  $PY -m ohlc_quant report "$1" --deposit "${2:-300}" --out ohlc_quant/reports/reporte_mt5
}
compilar() {
  bash mql5/compilar_ea.sh
}
menu() {
  echo "==================== OHLCMTF SCALPER ===================="
  echo " 1) Instalar (primera vez)"
  echo " 2) Descargar datos de XAUUSD"
  echo " 3) Validación completa sobre datos reales"
  echo " 4) Analizar un reporte del Strategy Tester (xlsx/html)"
  echo " 5) Ejecutar tests"
  echo " 6) Compilar el EA con MetaEditor (Linux con Wine)"
  echo " 0) Salir"
  read -rp "Opción: " op
  case "$op" in
    1) instalar ;; 2) datos ;; 3) validar ;;
    4) read -rp "Ruta del reporte: " f; read -rp "Depósito inicial [300]: " d; reporte "$f" "${d:-300}" ;;
    5) tests ;; 6) compilar ;; 0) exit 0 ;; *) echo "Opción no válida" ;;
  esac
}
case "${1:-}" in
  instalar) instalar ;; datos) datos ;; validar) validar ;; tests) tests ;; reporte) reporte "$2" "$3" ;; compilar) compilar ;; "") menu ;;
  *) echo "Comandos: instalar | datos | validar | tests | reporte ARCHIVO [DEPOSITO] | compilar"; exit 1 ;;
esac
