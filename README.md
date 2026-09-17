# OHLCMTF SCALPER — auditoría, EA corregido y validación sobre datos reales

Este repositorio contiene todo lo hecho sobre el robot de trading **OHLCMTF SCALPER v14.0 ELITE** (MetaTrader 5, oro XAUUSD):
la auditoría del código, una versión corregida y modular del robot (v15), y un laboratorio en Python que reproduce la estrategia
sobre 3,7 años de precios reales para medir si funciona y cuánto riesgo tiene.

## Para empezar en 3 minutos (sin saber programar)

1. **Leer el veredicto**: `docs/VALIDACION_RESULTADOS.md` (resultados) y `docs/AUDITORIA_v14.md` (qué estaba mal en el robot y qué se cambió).
2. **Usar el robot corregido en MetaTrader 5**: copiar las carpetas de `mql5/Experts`, `mql5/Include` y `mql5/Scripts` dentro de la
   carpeta de datos de tu MetaTrader (en el terminal: *Archivo → Abrir carpeta de datos → MQL5*). El robot ya compilado está en
   `mql5/compilados/OHLCMTF_Scalper.ex5`; si prefieres compilarlo tú, abre `OHLCMTF_Scalper.mq5` en MetaEditor y pulsa *Compilar*, o ejecuta `mql5/compilar_ea.bat`.
3. **Ejecutar las simulaciones**: en la raíz hay un único archivo de arranque con menú.
   - Windows: doble clic en `ejecutar.bat` (necesita Python 3.11 o superior instalado desde python.org, marcando "Add to PATH").
   - Linux / Mac: abrir una terminal en esta carpeta y escribir `./ejecutar.sh`.
   El menú ofrece: **1** instalar (una sola vez), **2** descargar los datos de XAUUSD (30-60 min), **3** validación completa
   (5 minutos, deja el informe en `ohlc_quant/reports/full/VALIDACION.md`), **4** analizar un reporte del Strategy Tester,
   **5** tests, **6** compilar el robot.

   También se puede llamar directo: `./ejecutar.sh instalar`, `./ejecutar.sh datos`, `./ejecutar.sh validar`,
   `./ejecutar.sh reporte MiReporte.xlsx 300`.

## Qué hay en cada carpeta

| Carpeta | Contenido |
|---|---|
| `old/` | El robot original tal cual se recibió (`expert 3.3.mq5`) y la versión intermedia monolítica v14.1. No tocar. |
| `docs/` | `AUDITORIA_v14.md`: hallazgos (críticos/importantes/menores), cambios, plan de validación, checklist para cuenta real. `VALIDACION_RESULTADOS.md`: resultados de las simulaciones y recomendaciones. |
| `mql5/` | Robot v15 modular: `Experts/OHLCMTF/OHLCMTF_Scalper.mq5` (principal), `Include/OHLCMTF/*.mqh` (14 módulos), `Scripts/OHLCMTF/ExportCalendarCSV.mq5` (exporta el calendario económico para el filtro de noticias), `compilados/` (binarios), `compilar_ea.bat` / `.sh`. |
| `ohlc_quant/` | Laboratorio Python: descarga de precios (Dukascopy), motor que reproduce el robot, Monte Carlo, walk-forward, sensibilidad, estrés, lector de reportes MT5. Ver su `README.md` para el detalle de comandos. |
| `ejecutar.sh` / `ejecutar.bat` | Menú único para usar todo lo anterior. |
| `TOKENS_SESION.md` | Consumo de tokens de la sesión de trabajo que produjo este repositorio. |

## Lo esencial que dice la validación

- El backtest original (+$1.820 con $300) es un artefacto: con lote mínimo 0.01 en oro cada operación arriesgaba entre 4% y 13% de la cuenta.
- Con el sizing corregido hacen falta **$3.000-5.000** para operar dentro del riesgo configurado.
- Con $3.000 y 3,7 años de datos reales: PF 1.46, +63% total (unos 14% anuales), drawdown máximo 7.7%. Casi todo el beneficio viene del
  mercado alcista de oro de 2025-2026; 2023 y 2024 fueron planos. Sin las 18 mejores operaciones el sistema apenas gana.
- Walk-forward fuera de muestra: PF 1.37. Hay ventaja, pero es modesta y depende del régimen. Recomendación: demo con capital real
  previsto y expectativas bajas antes de considerar cuenta real (detalle en `docs/VALIDACION_RESULTADOS.md`).

## Requisitos

- MetaTrader 5 (Windows) para usar el robot. Compila con MetaEditor actual; 0 errores, 0 avisos.
- Python 3.11+ para el laboratorio. Los datos ocupan 69 MB y se descargan con el menú (opción 2). Las simulaciones aprovechan todos los núcleos disponibles.
