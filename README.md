# OHLCMTF SCALPER — auditoría, EA corregido y validación sobre datos reales

Este repositorio contiene todo lo hecho sobre el robot de trading **OHLCMTF SCALPER v14.0 ELITE** (MetaTrader 5, oro XAUUSD):
la auditoría del código, el robot corregido (v15) y la versión de rendimiento (v16), y un laboratorio en Python que reproduce la estrategia
sobre 3,7 años de precios reales para medir si funciona y cuánto riesgo tiene.

## Si solo quieres el bot (para el cliente)

Todo está en **`ENTREGA_CLIENTE/`**. El instructivo es `LEEME.md`.

- **`OHLCMTF_Scalper_v16.mq5`**: el robot que hay que instalar. Un solo archivo, se copia a *MQL5/Experts* y se compila con F7. No trae `.ex5`: se compila en el MetaEditor del cliente.
- **`OHLCMTF_Scalper_v15.mq5`** y **`.ex5`**: la entrega anterior, por si hay que repetir esa prueba. No poner v15 y v16 a la vez sobre el mismo oro: comparten número mágico.
- `ExportCalendarCSV.mq5` / `.ex5`: solo para volcar el calendario económico si se activa el filtro de noticias en el probador.

La v16 deja cuatro defaults distintos de la v15 (lookback 10, objetivo 3,0 ATR, sin exigir expansión, protección progresiva apagada). El techo de riesgo del 2,5 % y la guardia de drawdown del 12 % no cambian. Capital de trabajo: 3.000-5.000. Con 300 casi no opera.

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
| `ENTREGA_CLIENTE/` | Lo que se entrega al cliente: `OHLCMTF_Scalper_v16.mq5`, el v15 (fuente y `.ex5`), script de calendario y `LEEME.md`. |
| `old/` | El robot original tal cual se recibió (`expert 3.3.mq5`) y la versión intermedia monolítica v14.1. No tocar. |
| `docs/` | `AUDITORIA_v14.md`: hallazgos (críticos/importantes/menores), cambios, plan de validación, checklist para cuenta real. `VALIDACION_RESULTADOS.md`: resultados de las simulaciones y recomendaciones. |
| `mql5/` | Robot en módulos (fuente de la v16): `Experts/OHLCMTF/OHLCMTF_Scalper.mq5`, `Include/OHLCMTF/*.mqh`, `Scripts/OHLCMTF/ExportCalendarCSV.mq5`, `compilados/` (binarios de la v15), `compilar_ea.bat` / `.sh`, y `build_single_file.py`, que regenera `OHLCMTF_Scalper_v16.mq5` en `ENTREGA_CLIENTE/`. |
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
- La v16, con depósito 5.000 y el mismo histórico, hizo en el laboratorio 2.697 de beneficio neto contra 1.860 de la v15 (factor 1,49 contra 1,43; drawdown 5,4 % contra 5,8 %). No es un resultado del Strategy Tester del bróker del cliente. Cómo instalarla está en `ENTREGA_CLIENTE/LEEME.md`.

## Requisitos

- MetaTrader 5 (Windows) para usar el robot. Compila con MetaEditor actual; 0 errores, 0 avisos.
- Python 3.11+ para el laboratorio. Los datos ocupan 69 MB y se descargan con el menú (opción 2). Las simulaciones aprovechan todos los núcleos disponibles.
