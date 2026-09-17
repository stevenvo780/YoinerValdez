@echo off
REM Compila el EA y el script con MetaEditor en Windows.
REM 1) Ajusta MT5DIR a tu carpeta de datos de MetaTrader 5 (Archivo > Abrir carpeta de datos en el terminal).
REM 2) Ejecuta este archivo. Copia los fuentes a MQL5\ y compila; los .ex5 quedan junto a los .mq5.
set MT5DIR=%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075
set METAEDITOR="C:\Program Files\MetaTrader 5\MetaEditor64.exe"
cd /d "%~dp0"
xcopy /E /Y /I Include\OHLCMTF "%MT5DIR%\MQL5\Include\OHLCMTF"
xcopy /E /Y /I Experts\OHLCMTF "%MT5DIR%\MQL5\Experts\OHLCMTF"
xcopy /E /Y /I Scripts\OHLCMTF "%MT5DIR%\MQL5\Scripts\OHLCMTF"
%METAEDITOR% /compile:"%MT5DIR%\MQL5\Experts\OHLCMTF\OHLCMTF_Scalper.mq5" /log:"%MT5DIR%\MQL5\compile_ea.log"
%METAEDITOR% /compile:"%MT5DIR%\MQL5\Scripts\OHLCMTF\ExportCalendarCSV.mq5" /log:"%MT5DIR%\MQL5\compile_script.log"
type "%MT5DIR%\MQL5\compile_ea.log"
echo.
echo Si el log termina en "0 errors", el EA compilado esta en %MT5DIR%\MQL5\Experts\OHLCMTF\OHLCMTF_Scalper.ex5
