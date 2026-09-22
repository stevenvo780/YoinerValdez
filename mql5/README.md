# OHLCMTF Scalper v15 (MQL5, modular)

Reescritura modular del EA `OHLCMTF SCALPER v14.0 ELITE` con todas las correcciones de la auditoría (`docs/AUDITORIA_v14.md`).
La lógica de señales, gestión y protección es la de v14.1; lo que cambia es la arquitectura.

```
Experts/OHLCMTF/OHLCMTF_Scalper.mq5      orquestación: OnInit/OnTick/OnTradeTransaction
Include/OHLCMTF/Types.mqh                 constantes, structs (SSignal, SPositionState, SSizing), contexto de símbolo
Include/OHLCMTF/Config.mqh                todos los inputs (nombres y defaults de v14.0) + ValidateInputs()
Include/OHLCMTF/Logger.mqh                CLogger: Print + fichero opcional
Include/OHLCMTF/Market.mqh                CMarket: ATR (vela cerrada), spread muestreado, tendencia de estructura
Include/OHLCMTF/Signals.mqh               CSignalEngine: ruptura, calidad, MTF, tendencia, scoring → SSignal[]
Include/OHLCMTF/Risk.mqh                  CRiskManager: sizing con techo duro (OrderCalcProfit), diagnóstico de capital
Include/OHLCMTF/Guards.mqh                CCapitalGuard: HWM/drawdown con latch, límite diario, racha, cooldown, fin de semana
Include/OHLCMTF/Execution.mqh             CExecutor: envío (mercado/límite), retcodes, flatten, pendientes
Include/OHLCMTF/Recovery.mqh              CStateStore: variables globales, recuperación tras reinicio, R desde historial
Include/OHLCMTF/News.mqh                  CNewsFilter: ventanas fijas + calendario MQL5 (vivo) + CSV (tester)
Include/OHLCMTF/Stats.mqh                 CTradeStats: contabilidad por tipo de salida y por set
Include/OHLCMTF/PositionManager.mqh       CPositionManager: protección progresiva en 4 etapas
Include/OHLCMTF/Context.mqh               instancias globales de los módulos
Include/OHLCMTF/Panel.mqh                 CPanel: panel visual y flechas
Scripts/OHLCMTF/ExportCalendarCSV.mq5     exporta el calendario económico a Common\Files\news_events.csv
```

## Archivo único para el cliente

`python3 build_single_file.py` fusiona el principal y los 14 módulos en `OHLCMTF_Scalper_v16_single.mq5` y lo copia a
`../ENTREGA_CLIENTE/OHLCMTF_Scalper_v16.mq5`. Los módulos son la fuente de verdad. El archivo único v15 que ya estaba en
`ENTREGA_CLIENTE/` no se regenera.

## Instalación

Copiar `Experts/OHLCMTF`, `Include/OHLCMTF` y `Scripts/OHLCMTF` dentro de `<Terminal>/MQL5/` respetando las carpetas, y compilar
`OHLCMTF_Scalper.mq5` en MetaEditor. Los magic numbers son 20260914 (set fijo) y 20260915 (set custom).

## Diferencias funcionales respecto a v14.0 con los valores por defecto

- Sizing con techo duro: si el lote mínimo excede `Hard_Risk_Cap_Percent`, la señal se omite (`Allow_MinLot_Above_Cap=false`).
- Drawdown medido contra el máximo histórico de equity; al superarlo se cierran posiciones y se bloquea el EA 72 h.
- ATR de la vela cerrada; racha reseteada solo por ganancias ≥ 0.25 R; modo spread alto por promedio.
- Para reproducir v14.0: `Allow_MinLot_Above_Cap=true`, `Size_On_Equity=false`, `Use_Total_Drawdown_Limit=false`,
  `Streak_Reset_Min_R=0`, `Use_Avg_Spread_For_Mode=false`.

## Estado de revisión

**Compilado con MetaEditor 5 (build actual, bajo Wine 9): 0 errores, 0 avisos** para `OHLCMTF_Scalper.mq5` y
`ExportCalendarCSV.mq5`; los binarios `.ex5` están en `compilados/`. También compilan limpios el original v14.0 y el
monolítico v14.1 de `old/` (control de la cadena). Revisado además en dos rondas por Codex GPT-5.6: de 21 hallazgos se
aplicaron 10 y se descartaron 11 por ser comportamiento intencional (`Allow_MinLot_Above_Cap`), falsos positivos de C++
(`extern`, `input` en `.mqh`) o casos que el EA no genera (reversiones `INOUT`, fills parciales en oro).
Para recompilar: `compilar_ea.bat` (Windows) o `compilar_ea.sh` (Linux con Wine). Siguiente paso: el A/B contra v14.0 en el
Strategy Tester descrito en `docs/AUDITORIA_v14.md`.

## Validación

El paquete Python `ohlc_quant/` (carpeta hermana) contiene el port de esta lógica y las herramientas de backtest,
Monte Carlo, walk-forward, sensibilidad y estrés sobre ticks reales de XAUUSD.
