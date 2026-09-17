#!/bin/bash
# Compila el EA con MetaEditor bajo Wine (Linux). Requiere: wine, xvfb (apt install wine64 xvfb) y MetaTrader 5 instalado en $WINEPREFIX.
# Instalación de MT5 en Wine (una vez):  WINEPREFIX=$HOME/mt5wine xvfb-run -a wine mt5setup.exe /auto   y arrancar terminal64.exe una vez para que extraiga MQL5/Include.
set -e
cd "$(dirname "$0")"
export WINEPREFIX="${WINEPREFIX:-/workspace/mt5wine}" WINEDEBUG=-all
MT5="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
[ -f "$MT5/MetaEditor64.exe" ] || { echo "No se encuentra MetaEditor en $MT5 (ver instrucciones en este archivo)"; exit 1; }
mkdir -p "$MT5/MQL5/Include/OHLCMTF" "$MT5/MQL5/Experts/OHLCMTF" "$MT5/MQL5/Scripts/OHLCMTF"
cp Include/OHLCMTF/*.mqh "$MT5/MQL5/Include/OHLCMTF/"
cp Experts/OHLCMTF/OHLCMTF_Scalper.mq5 "$MT5/MQL5/Experts/OHLCMTF/"
cp Scripts/OHLCMTF/ExportCalendarCSV.mq5 "$MT5/MQL5/Scripts/OHLCMTF/"
cd "$MT5"
for f in "MQL5\\Experts\\OHLCMTF\\OHLCMTF_Scalper.mq5" "MQL5\\Scripts\\OHLCMTF\\ExportCalendarCSV.mq5"; do
  echo "=== compilando $f"
  timeout 300 xvfb-run -a wine MetaEditor64.exe /compile:"$f" /log:"C:\\compile.log" >/dev/null 2>&1 || true
  iconv -f UTF-16 -t UTF-8 "$WINEPREFIX/drive_c/compile.log" | grep -v "information" | grep -v "^ *$" | tail -5
done
mkdir -p "$OLDPWD/compilados"
cp "$MT5/MQL5/Experts/OHLCMTF/OHLCMTF_Scalper.ex5" "$MT5/MQL5/Scripts/OHLCMTF/ExportCalendarCSV.ex5" "$OLDPWD/compilados/"
echo "✔ Binarios en mql5/compilados/"
