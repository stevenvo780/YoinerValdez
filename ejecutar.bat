@echo off
REM Uso sencillo del proyecto OHLCMTF en Windows. Doble clic o desde cmd:  ejecutar.bat
cd /d "%~dp0"
set PY=ohlc_quant\.venv\Scripts\python.exe
:menu
echo ==================== OHLCMTF SCALPER ====================
echo  1^) Instalar (primera vez; requiere Python 3.11+ instalado)
echo  2^) Descargar datos de XAUUSD
echo  3^) Validacion completa sobre datos reales
echo  4^) Analizar un reporte del Strategy Tester (xlsx/html)
echo  5^) Ejecutar tests
echo  6^) Compilar el EA con MetaEditor
echo  0^) Salir
set /p op=Opcion: 
if "%op%"=="1" goto instalar
if "%op%"=="2" goto datos
if "%op%"=="3" goto validar
if "%op%"=="4" goto reporte
if "%op%"=="5" goto tests
if "%op%"=="6" goto compilar
if "%op%"=="0" exit /b 0
goto menu
:instalar
python -m venv ohlc_quant\.venv && %PY% -m pip install --quiet --upgrade pip && %PY% -m pip install --quiet -e "ohlc_quant[dev]" && echo Listo.
pause & goto menu
:datos
for /f %%i in ('powershell -command "Get-Date -Format yyyy-MM-dd"') do set HOY=%%i
%PY% ohlc_quant\scripts\download_candles.py 2023-01-01 %HOY% 2
pause & goto menu
:validar
%PY% ohlc_quant\scripts\validate_full.py
echo Informe en ohlc_quant\reports\full\VALIDACION.md
pause & goto menu
:reporte
set /p f=Ruta del reporte: 
set /p d=Deposito inicial [300]: 
if "%d%"=="" set d=300
%PY% -m ohlc_quant report "%f%" --deposit %d% --out ohlc_quant\reports\reporte_mt5
pause & goto menu
:tests
cd ohlc_quant && .venv\Scripts\python.exe -m pytest -q -n 8 -p no:warnings & cd ..
pause & goto menu
:compilar
call mql5\compilar_ea.bat
pause & goto menu
