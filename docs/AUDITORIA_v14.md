# Auditoría OHLCMTF SCALPER v14.0 ELITE → build v14.1 AUDIT

Fecha: 2026-09-17 · Fuente auditada: `expert 3.3.mq5` (1512 líneas) · Backtest: XAUUSD, $300, 77 operaciones.
Entregables en esta carpeta:

| Archivo | Qué es |
|---|---|
| `mql5/` | EA v15 modular (Experts + Include/OHLCMTF + Scripts) con todas las correcciones `[AUDIT-nn]`. |
| `old/OHLCMTF_SCALPER_v14_1_AUDIT_monolitico.mq5` | Build monolítico intermedio v14.1 (referencia; cada cambio etiquetado `[AUDIT-nn]`). |
| `old/expert 3.3.mq5` | Original v14.0 sin tocar. |
| `ohlc_quant/` | Proyecto Python: port de la estrategia, backtest sobre ticks reales, Monte Carlo, walk-forward, sensibilidad, estrés, parser de reportes MT5. |
| `mql5/Scripts/OHLCMTF/ExportCalendarCSV.mq5` | Script MT5 que vuelca el calendario económico a `Common\Files\news_events.csv` para backtestear el filtro de noticias. |

**Estado de compilación:** el EA v15 modular (`mql5/`), el script de calendario, el original v14.0 y el monolítico v14.1 compilan con
MetaEditor 5 con **0 errores y 0 avisos** (compilados bajo Wine el 2026-09-17; binarios en `mql5/compilados/`). **Qué NO se probó:** el EA
no se ha ejecutado en el Strategy Tester de MetaTrader (requiere un terminal conectado a un bróker con historial). Su lógica sí se ejecutó
a través del port en Python (`ohlc_quant/`) sobre 3,7 años de ticks reales; los resultados están en `docs/VALIDACION_RESULTADOS.md`.

---

## 1. Resumen ejecutivo

**Veredicto: ALTO RIESGO. No está listo para cuenta real con $300, y el backtest presentado no mide lo que el código dice controlar.**

1. El riesgo real por operación fue de **~9% del depósito en promedio y 25% en la peor** (pérdida media $26.69 y máxima $74.82 sobre $300), contra un 0.25%–1.25% configurado y un techo de 2.5%. La causa es `CalcDynamicVolume` forzando `SYMBOL_VOLUME_MIN` (línea 924) con una cuenta infracapitalizada. El beneficio de $1,820 es un artefacto de ese apalancamiento involuntario, no de la estrategia.
2. El límite de drawdown del 12% **nunca actuó**: `CheckTotalDrawdown` (líneas 568-578) mide solo la pérdida flotante contra el balance actual, se pone a cero en cada cierre y además solo se consulta cuando no hay posición abierta. Por eso el DD real fue 30-31%.
3. Con el sizing corregido (v14.1), con $300 **la mayoría de las señales se omitirán** porque 0.01 lotes de XAUUSD con SL de ATR×1.8 excede el 2.5%. El capital mínimo coherente con los inputs es **$1,000-3,000 para el techo del 2.5% y $2,500-7,500 para operar al 1%** con los SL observados.
4. 77 operaciones no bastan para validar ~90 inputs; el sistema efectivo tiene unos 12 parámetros sensibles y solo hay muestra para optimizar 1-2. Marzo y los viernes concentran el resultado; sin el reporte de operaciones no se puede cuantificar (el script entregado lo hace en segundos).
5. Los dos sets de señales no eran distinguibles en el reporte. v14.1 les da magic y comentario propios; hay que re-correr el backtest tres veces (ambos, solo fijo, solo custom) para atribuir.
6. El código base es sólido en lo que respecta a look-ahead (todas las decisiones usan índice ≥1), pero el ATR y el ATR% leían la vela en formación; corregido.

Camino recomendado: compilar v14.1 → repetir el backtest con el mismo período y `Allow_MinLot_Above_Cap=false` → si el EA casi no opera con $300, decidir capital real o cambiar de instrumento/bróker con lote 0.001 → validación walk-forward + OOS + Monte Carlo del §6 → demo 4-8 semanas con spread real → real con `DD_Pause_Hours=0`.

---

## 2. Hallazgos priorizados

Referencias de línea = `expert 3.3.mq5` original. Estado = cómo lo trata v14.1.

### CRÍTICO

| # | Hallazgo | Líneas | Estado v14.1 |
|---|---|---|---|
| C1 | **Lote mínimo forzado por encima del techo de riesgo.** `if(vol < minVol) vol = minVol;` sin comprobar que `minVol × riesgo/lot ≤ Hard_Risk_Cap`. Con $300 y SL≈$25-75 por 0.01 lot, cada trade arriesga 8-25%. | 918-925 | `[AUDIT-01]` omite la señal si el lote mínimo excede el cap (`Allow_MinLot_Above_Cap=false`), aplica un `capVol` absoluto, registra riesgo REAL en log y panel, y `PrintMinLotDiagnostic()` en OnInit dice cuánto capital hace falta. |
| C2 | **Límite de drawdown total inoperante.** DD = (balance−equity)/balance: flotante, se resetea a 0 al cerrar; solo se evalúa en `ExecuteTrade`, es decir cuando NO hay posición (equity≈balance → DD≈0). Es código muerto en la práctica. | 568-578, 1040 | `[AUDIT-02]` `EquityGuardTick()` en cada tick: high-water mark de equity persistido, DD = (HWM−equity)/HWM, al superar el límite → `FlattenAll()` cierra posiciones y pendientes, latch persistido (72 h por defecto o reset manual con `DD_Manual_Reset`). |
| C3 | **Sizing sobre `ACCOUNT_BALANCE`** ignora pérdidas flotantes (no aplica hoy porque solo hay una posición, pero sí tras un reinicio con posición abierta o si se relaja ese límite). | 905 | `[AUDIT-01]` `RiskBase()` = min(balance, equity) con `Size_On_Equity=true`. |
| C4 | **Cuenta infracapitalizada para el instrumento.** No es un bug de código: con XAUUSD (0.01 lot = $1 por $1 de movimiento) y ATR H1 de $15-40 el SL vale $27-72; ningún sizing porcentual funciona por debajo de ~$1,000. | — | Diagnóstico en OnInit; el EA deja de operar en vez de exceder el cap. Decisión del operador: capital, o bróker con `VOLUME_MIN=0.001`, o instrumento con contrato menor. |

### IMPORTANTE

| # | Hallazgo | Líneas | Estado v14.1 |
|---|---|---|---|
| I1 | **Sets indistinguibles.** Ambos sets usan `g_magic=20260914` y comentario `R###`. Imposible atribuir P&L por set en el reporte. | 196, 655, 665, 947-953 | `[AUDIT-03]` magic 20260914 (fijo) / 20260915 (custom), comentario `R###F` / `R###C`, `Use_Fixed_Set` para apagar el set fijo, contadores por set en panel y resumen final. |
| I2 | **ATR y ATR% de la vela en formación** (`atr_buf[0]`, `iClose(...,0)`): valor que cambia dentro de la vela; no es look-ahead pero sí no reproducible tick a tick y contradice la regla "solo velas cerradas". | 489, 538, 820 | `[AUDIT-04]` índice 1 en ambos. Cambia ligeramente el backtest: hay que re-correr. |
| I3 | **Racha de pérdidas reseteada por cualquier ganancia >0**, incluidos cierres en breakeven+25 pts (+$0.25). Tres pérdidas, un BE, tres pérdidas: nunca pausa. | 369-382 | `[AUDIT-08]` solo una ganancia ≥ `Streak_Reset_Min_R` (0.25 R) resetea. |
| I4 | **Contabilidad de salidas depende de `g_cur_ticket`**: si el deal de entrada llega antes de que `PositionSelectByTicket` funcione (ocurre en vivo), `g_cur_ticket` queda 0 y la salida se ignora → racha no cuenta. `DEAL_ENTRY_OUT_BY` no se maneja. | 340, 355 | `[AUDIT-13]` R y TP se recuperan del deal de entrada (`DEAL_SL/DEAL_TP`) o de variable global; maneja OUT_BY. |
| I5 | **Reinicio del terminal:** `g_last_bar_*=0` re-evalúa la última vela cerrada (puede reabrir una señal ya operada); `g_trades_today`, racha, pausa y balance de inicio de día se pierden; el R inicial se recupera del comentario, que algunos brókers sobrescriben. | 198-199, 268-272, 958-1003 | `[AUDIT-05]` `g_last_bar_*` = vela actual en OnInit; `RecoverDailyStateFromHistory()`; R desde `HistorySelectByPosition` → `DEAL_SL` del deal IN; racha/pausa/HWM en variables globales del terminal (se borran al inicio de cada pasada del tester). |
| I6 | **Órdenes límite (si `Use_Limit_Orders=true`):** (a) una pendiente no cuenta como posición → se puede colocar una segunda; (b) `OrderOpen(..., price, price, ...)` pasa `stoplimit=price` (algunos servidores devuelven 10013); (c) SL/TP calculados desde ask/bid, no desde el precio límite. | 895-898, 1139, 1147, 1127-1128 | `[AUDIT-06]` `HasOpenExposure()` incluye pendientes; `stoplimit=0`; SL/TP relativos al límite. |
| I7 | **`sent = trade.PositionOpen(...)` sin comprobar retcode.** `CTrade` puede devolver true con retcodes distintos de DONE en modo asíncrono o en algunos rechazos; se incrementaría `g_trades_today` sin posición. | 1155-1159 | `[AUDIT-07]` `SendOK()` exige DONE / PLACED / DONE_PARTIAL. |
| I8 | **Modo spread alto decidido con el spread instantáneo del primer tick de la vela** (xx:00:00), justo cuando los proveedores ensanchan. Sesgo hacia SL×1.35 y riesgo×0.45 sin motivo. | 1049-1053 | `[AUDIT-09]` usa el promedio muestreado (`Use_Avg_Spread_For_Mode=true`); el techo `Max_Spread_Points` sigue usando el instantáneo. |
| I9 | **Sin validación de inputs.** `Trend_Lookback<6` desactiva silenciosamente el filtro de tendencia (retorna 0 → bloquea todo si `Block_When_No_Trend`); etapas PP no monotónicas; `Min_Risk>Max_Risk`; `Session_Start>=End`; `TF_Fast>=TF_Slow`. | 250-301 | `[AUDIT-11]` `ValidateInputs()` → `INIT_PARAMETERS_INCORRECT` con mensaje por cada input. |
| I10 | **Filtro de noticias por reloj fijo y desactivado**; sin calendario. | 146-176, 611-628 | `[AUDIT-10]` §7 de este informe. Ventanas legado se conservan. |
| I11 | **Sin gestión del fin de semana.** El set fijo puede abrir el viernes a las 19:00 y quedar expuesto al gap del domingo con SL de servidor (con lote mínimo forzado, un gap de $30 = 10% de la cuenta). | — | `[AUDIT-12]` `Close_Before_Weekend`, `Weekend_Close_Hour`, `Friday_Entry_Cutoff_Hour` (desactivados por defecto para no alterar el backtest; recomendados en real). |
| I12 | **Límite diario solo bloquea entradas**; con posición abierta el día puede perder más del 4.5%. | 1025-1038 | `[AUDIT-12]` `DailyGuardTick()` cada tick + `Daily_Loss_Flatten` opcional. |

### MENOR

| # | Hallazgo | Líneas | Estado |
|---|---|---|---|
| M1 | Filtro de volatilidad inerte con los defaults: ATR% ∈ [0.025%, 1.8%] siempre se cumple en oro (ATR H1 de $1 a $70 sobre $3,500). Solo el `sweet_spot` del scoring hace algo, y premia volatilidad ALTA (≥0.38% ≈ $13+ de ATR), lo que agranda el SL justo cuando el lote mínimo ya sobrepasa el cap. | 103-104, 822-826 | Sin cambio de defaults (restricción). Recomendación en §5. |
| M2 | Scoring con menos grados de libertad de lo que parece: con `Require_HigherTF_Confirm=true` el punto MTF es automático y con `Require_Trend_Alignment && Block_When_No_Trend` el punto de tendencia también → base efectiva 3, y `Min_Signal_Strength=4` exige solo 1 de {margen≥0.50×ATR, cuerpo≥0.65, sweet_spot}. | 829-851 | Documentado. |
| M3 | `Cooldown_Seconds=180` es irrelevante para velas H1/M5 (la siguiente evaluación siempre está a ≥300 s). | 95 | Sin cambio. |
| M4 | Sesión: la vela H1 que cierra a las 20:00 se evalúa con `hour=20` → bloqueada; la que cierra a las 07:00 (06:00-07:00, Asia) se evalúa con `hour=7` → permitida. Off-by-one benigno pero contradice "Asia bloqueada". | 551-563 | Documentado; ajustar `Session_Start_Hour=8` si se quiere excluir la vela 06-07. |
| M5 | `OrderCalcMargin` siempre con `ORDER_TYPE_BUY` (para sells la diferencia es despreciable en oro). | 929 | Sin cambio. |
| M6 | `Sharpe 7.05` y `AHPR 1.0289` del reporte están inflados por el apalancamiento involuntario (2.9% de crecimiento medio por trade). No usarlos como evidencia. | — | — |
| M7 | Zona horaria: todos los filtros usan `TimeCurrent()` (servidor). La mayoría de brókers de oro usan EET/EEST alineado al DST de Nueva York, así que la sesión 7-20 se mantiene estable respecto a NY y se desplaza 1 h respecto a Londres/UTC durante las 2-3 semanas de desfase de DST (marzo y octubre-noviembre). No cambia con el DST del PC. En el tester, `TimeGMT()` se emula igual al tiempo del servidor, así que un filtro en GMT no sería backtesteable; por eso v14.1 conserva hora de servidor y lo documenta en los inputs. | 556, 614 | Documentado. |

---

## 3. Mapa de cambios en el código (v14.1)

Todos los inputs originales conservan nombre y valor por defecto. Los nuevos están en los grupos 19 y 20.

| Etiqueta | Función(es) | Cambia el backtest con defaults? |
|---|---|---|
| AUDIT-01 | `RiskBase`, `CalcDynamicVolume`, `PrintMinLotDiagnostic` | **Sí** (omite señales que excedan el cap). Es el objetivo. |
| AUDIT-02 | `EquityGuardTick`, `FlattenAll`, `LoadPersistentState`, `SavePersistentState` | **Sí** (puede cerrar posiciones y pausar 72 h). |
| AUDIT-03 | `IsOurMagic`, `SetFromMagic`, `BuildRiskComment`, contadores `g_set_*` | No (solo etiquetado). |
| AUDIT-04 | `GetATRValue`, `GetATRPct` | Ligeramente (ATR de vela cerrada). |
| AUDIT-05 | `OnInit`, `RecoverDailyStateFromHistory`, `RiskDistanceFromHistory`, `RecoverOpenPositionState` | No en tester. |
| AUDIT-06 | `HasOpenExposure`, `CountPendingOrders`, `ExecuteTrade` (rama límite) | Solo si `Use_Limit_Orders=true`. |
| AUDIT-07 | `SendOK` | No. |
| AUDIT-08 | `OnTradeTransaction` | **Sí** (pausas por racha más frecuentes). |
| AUDIT-09 | `ExecuteTrade` | Ligeramente (modo spread alto según promedio). |
| AUDIT-10 | `LoadCalendarEvents`, `LoadCalendarFromCSV`, `IsCalendarBlocked`, `IsNewsTime` | No (off por defecto). |
| AUDIT-11 | `ValidateInputs` | No. |
| AUDIT-12 | `WeekendCloseTick`, `DailyGuardTick`, `CheckSessionFilter` | No (off por defecto). |
| AUDIT-13 | `OnTradeTransaction`, `AccountExitDeal` | No. |
| AUDIT-14 | `NormalizeTradePrice`, `CalcDynamicVolume` (`OrderCalcProfit`), modos de expiración en `ExecuteTrade` | No (robustez de ejecución; correcciones sugeridas por la revisión de Codex). |

Para reproducir exactamente v14.0 con v14.1 (comparación A/B): `Allow_MinLot_Above_Cap=true`, `Size_On_Equity=false`, `Use_Total_Drawdown_Limit=false`, `Streak_Reset_Min_R=0`, `Use_Avg_Spread_For_Mode=false`. Quedará solo la diferencia del ATR de vela cerrada.

---

## 4. Respuesta a los nueve riesgos planteados

1. **Doble set de señales.** Coexisten así: el set fijo se evalúa al abrir cada vela H1 y el custom al abrir cada vela `TF_Fast`; cuando coinciden (xx:00) el fijo va primero y el custom queda bloqueado por `HasOpenExposure`. Ambos comparten el mismo ATR (`ATR_Timeframe`=H1) para margen de ruptura, SL y TP: **una entrada en M5 lleva un SL de tamaño H1** (esto es probablemente lo que hace que el set custom sea "operable" y también lo que multiplica el riesgo con lote mínimo). En v14.1 cada set tiene magic y etiqueta; el script `ohlc_quant report <fichero>` (o `ohlc_quant/scripts/analyze_mt5_report_standalone.py`) separa las métricas. Recomendación: elegir UN set tras la atribución. Si el custom aporta la mayoría de los trades con peor expectativa (lo habitual en M5 con SL de H1), apagarlo reduce grados de libertad y coste de spread.
2. **DD 12% que solo bloquea.** Ver C2. Además de que solo bloqueaba, no medía DD real. Corregido con HWM + flatten + latch.
3. **`SYMBOL_VOLUME_MIN`.** Confirmado por los propios números del reporte: pérdida media $26.69 (8.9% de $300) y máxima $74.82 (24.9%). Con riesgo 0.25-1.25% las pérdidas deberían ser de $0.75-$3.75. El script calcula `pérdida / balance previo` por operación y lista los volúmenes usados para cerrar la cuestión con datos.
4. **~90 inputs vs 77 trades.** Ver §5. Regla práctica: ≥30-50 trades por parámetro optimizado → con 77 trades solo cabe optimizar 1-2. Cualquier parámetro que haya sido "tocado" mirando este backtest ya contaminó el período; por eso la validación (§6) exige datos nunca vistos.
5. **Marzo y viernes.** No puedo recalcularlo sin la tabla de operaciones (el resumen no trae P&L por trade). El script lo hace (`[6] EXCLUSIONES`: sin mejor mes, sin mejor día, sin ambos, sin las 3 mejores operaciones). Criterio de aceptación: PF > 1.5 y expectativa > 0 en los cuatro escenarios; si "sin marzo" cae por debajo de 1.3, el sistema depende de un régimen.
6. **Noticias.** §7.
7. **Balance vs equity.** C3, corregido.
8. **Un símbolo, un período.** §6.
9. **Zona horaria.** M7.

---

## 5. Versión con menos grados de libertad

De los ~90 inputs, 45 son de panel, noticias legado, calendario y ergonomía. De los ~45 que afectan a las señales, estos son los que de verdad mueven el resultado (por impacto esperado, de mayor a menor):

| Grupo | Inputs que importan | Por qué |
|---|---|---|
| Ruptura | `Structure_Lookback`, `Min_Breakout_ATR_Mult`, `Min_Body_Ratio` | Definen qué es una ruptura válida; son los únicos con sensibilidad continua fuerte. |
| Salidas | `ATR_SL_Multiplier`, `ATR_TP_Multiplier`, `PP_Stage2_R` (BE), `PP_Trail_Start_R` | Determinan la distribución de R por trade. |
| Tendencia | `Trend_Lookback`, `Trend_Timeframe` | Sesgo direccional. |
| Sesión | `Session_Start_Hour`, `Session_End_Hour` | Cambia el universo de velas. |
| Riesgo | `Max_Risk_Percent` (o el único `Risk_Percent`) | No afecta a la señal, sí al DD. |

Propuesta "LEAN" (sin tocar el código: son solo valores fijados y documentados como *no optimizables*):

- Congelar: `Max_Breakout_ATR_Mult=2.2`, `Max_Against_Wick_Ratio=0.35`, `Require_Close_Beyond=true`, `Prefer_Expansion_Break=true`, `Min_Swing_Confirmations=2`, `Require_HigherTF_Confirm=true`, todo el grupo 8 de spread salvo `Max_Spread_Points`, `Cooldown_Seconds`, `Max_Trades_Per_Day`, `PP_Stage1_*`, `PP_Stage3_*`, `PP_Lock_Fraction`, `PP_Trail_ATR_Mult`, `PP_Trail_Structure_Lookback`, `PP_Min_Step_Points`.
- Desactivar el scoring dinámico como fuente de riesgo variable: `Min_Risk_Percent = Max_Risk_Percent = 0.75` (un solo riesgo). El TP variable por fuerza (`×(1+0.35·ratio)`) queda, es una función del mismo score.
- `Use_Volatility_Filter=false` (inerte con los defaults, M1) o subir `ATR_Min_Pct` a 0.20 si se quiere que haga algo real.
- Un solo set: el que gane la atribución.
- Optimizar como máximo: `Structure_Lookback` {8,12,16} × `ATR_SL_Multiplier` {1.5,1.8,2.2}. Nada más. El resto de "plateaus" se evalúa con sensibilidad ±20% (§6, paso 4), no con optimización.

Resultado: 6 parámetros vivos, 2 optimizables.

---

## 6. Plan de validación (Strategy Tester MT5)

Prerrequisitos: datos de ticks reales del bróker objetivo (Tick Data Suite o el propio historial del bróker), spread **variable real** (no "spread actual" ni fijo), comisión configurada, `Modelado = Cada tick basado en ticks reales`. Depósito de prueba: el capital real previsto (no $300).

1. **Compilar v14.1 y reproducir v14.0** (A/B del §3) sobre el mismo período: debe dar resultados casi idénticos. Si difiere mucho, hay un error en el port; parar aquí.
2. **Backtest v14.1 con defaults**: anotar cuántas señales omite por lote mínimo (log y panel). Si es >30% de las señales, la cuenta es demasiado pequeña; decidir capital antes de seguir.
3. **Atribución por set**: tres corridas (ambos / `Use_Fixed_Set=false` / `Use_Custom_Pair=false`) → `ohlc_quant report <fichero>` (o `ohlc_quant/scripts/analyze_mt5_report_standalone.py`) sobre cada reporte. Elegir un set.
4. **Sensibilidad** de los 6 parámetros vivos: ±20% uno a uno. Un sistema robusto pierde <30% de expectativa con ±20% en cualquier parámetro. Si un parámetro concreto lo hunde, está sobreajustado.
5. **Partición temporal.** Con todo el histórico disponible (ideal ≥3 años de XAUUSD, que incluyen 2022-2023 rango, 2024-2025 tendencia y los episodios de volatilidad extrema): 70% in-sample / 30% out-of-sample **por fecha**, el OOS al final y sin haberlo mirado nunca. El backtest de 77 trades ya está contaminado: trátese como in-sample.
6. **Walk-forward anclado**: ventanas de 6 meses IS → 2 meses OOS, rodando cada 2 meses (Strategy Tester → Optimización "Forward" al 25-33%, o manual). Optimizar solo los 2 parámetros del §5 en cada ventana. Métrica de aceptación: eficiencia WF = (expectativa OOS / expectativa IS) ≥ 0.5 en ≥ 70% de las ventanas, y OOS concatenado con PF ≥ 1.4 y DD ≤ 15%.
7. **Monte Carlo** sobre el OOS concatenado con `analyze_mt5_report.py --runs 20000 --cap 1.0`: aceptar si P(DD ≥ 20%) < 5% y P(ruina) ≈ 0 en modo bootstrap con el sizing corregido. (Como referencia, con el resumen del backtest actual y sizing v14.0 la aproximación da p95 de DD ≈ 53% y P(DD ≥ 30%) ≈ 17%.)
8. **Exclusiones** (script, bloque 6): PF > 1.5 sin el mejor mes, sin el mejor día y sin las 3 mejores operaciones.
9. **Estrés de ejecución**: repetir el mejor backtest con spread ×2 y slippage de 20-40 puntos (input `Slippage_Points` no simula slippage; usar la opción de "Retraso" de ejecución del tester y un spread fijo alto). El PF no debe caer por debajo de 1.3.
10. **Demo en VPS** ≥ 4 semanas con el mismo bróker, comparando cada operación con la señal del tester (mismo período): desviación media de precio de entrada ≤ 1× spread.

---

## 7. Filtro de noticias real

Implementado en v14.1 (`[AUDIT-10]`):

- **En vivo**: `CalendarValueHistory` + `CalendarEventById` de la API estándar de MQL5 (sin librerías externas). Filtra por divisa (`Calendar_Currencies`, por defecto USD; para oro conviene "USD" y opcionalmente "EUR,GBP") e importancia mínima (`Calendar_Min_Importance=HIGH`: NFP, CPI, FOMC, PCE, GDP). Ventana `Calendar_Block_Before_Min` / `Calendar_Block_After_Min` (30/30 por defecto; para FOMC usar 30/60). Recarga cada `Calendar_Refresh_Min`. Si la API falla (bróker sin calendario) hace fallback al CSV y lo avisa.
- **En el tester** las funciones de calendario no están disponibles; el EA lee `Common\Files\news_events.csv` (formato `YYYY.MM.DD HH:MM;USD;HIGH;Nonfarm Payrolls`, hora del servidor). El script `tools/ExportCalendarCSV.mq5` lo genera desde un terminal conectado para el rango de fechas del backtest. Así el filtro es **backtesteable con los mismos eventos que verá en vivo**.
- `Calendar_Close_Positions=true` cierra la posición abierta al entrar en la ventana (recomendado con lote mínimo forzado; con sizing correcto es opcional).
- Las cuatro ventanas fijas legado siguen disponibles para eventos no cubiertos por el calendario (discursos, subastas).
- Recomendación operativa: activar `Use_Calendar_Filter=true` con USD/HIGH y medir en el backtest cuántas operaciones evita y qué P&L tenían; si el filtro elimina operaciones ganadoras netas, reducir la ventana posterior antes que desactivarlo.

---

## 8. Checklist de preparación para cuenta real

**Capital y sizing**
- [ ] Capital ≥ el que imprime `PrintMinLotDiagnostic()` en OnInit para operar al `Max_Risk_Percent` (orientativo: $2,500-7,500 para 1% en XAUUSD con lote 0.01).
- [ ] `Allow_MinLot_Above_Cap=false`. Log de cada entrada muestra "RIESGO REAL" ≤ `Hard_Risk_Cap_Percent`.
- [ ] `Hard_Risk_Cap_Percent` bajado a 1.5% para real (2.5% × 6 trades/día = 15% de exposición diaria teórica).

**Ejecución**
- [ ] Spread real del bróker en XAUUSD medido una semana en el panel (promedio y máximo en aperturas de hora) vs el spread usado en el backtest. Si el real es >1.5× el del test, repetir el backtest con ese spread.
- [ ] `Max_Spread_Points` fijado (45-60 puntos en cuentas raw; 80-100 en estándar). En v14.0 está desactivado.
- [ ] Slippage: `Slippage_Points=40` es la desviación máxima aceptada, no una simulación. Medir en demo la diferencia entre precio de señal y `POSITION_PRICE_OPEN`.
- [ ] VPS en el mismo datacenter del bróker (latencia < 5 ms); el EA opera en apertura de vela, cuando la cola de órdenes es máxima.
- [ ] Tipo de relleno: `SetTypeFillingBySymbol` cubre FOK/IOC; verificar que el bróker no exige `ORDER_FILLING_RETURN`.

**Fines de semana y gaps**
- [ ] `Close_Before_Weekend=true`, `Weekend_Close_Hour=21`, `Friday_Entry_Cutoff_Hour=18` (servidor). El pico de operaciones de viernes del backtest hace esto obligatorio.
- [ ] Entender que el SL es de servidor: en un gap se ejecuta al primer precio disponible.

**Reinicios y recuperación**
- [ ] Probar en demo: abrir posición, cerrar el terminal, reabrir → el log debe imprimir "RECUPERACIÓN: posición #… R=… pts (fuente: historial/GV)" y el panel el R correcto. Verificar que el trailing no salta de etapa.
- [ ] Probar: reinicio tras 2 pérdidas → "racha=2" en el log de recuperación.
- [ ] Probar: `DD_Manual_Reset` levanta el latch y se vuelve a `false` antes de dejar el EA corriendo.
- [ ] Variables globales del terminal (`OHLC14_<login>_<símbolo>_*`) visibles en F3; no borrarlas manualmente con el EA corriendo.

**Protección**
- [ ] `DD_Pause_Hours=0` (reset manual) en real: una pausa automática de 72 h y re-base del HWM permite cortes sucesivos del 12%.
- [ ] Elegir la base del HWM: `DD_Use_Equity_Peak=true` (por defecto) cuenta como drawdown la devolución de beneficio flotante no realizado (una operación que llega a +3R y cierra en +1R ya suma DD); `false` usa el máximo de balance cerrado y es la métrica "balance peak → equity trough" habitual. Con riesgo del 1% y límite del 12% la diferencia rara vez dispara el latch, pero conviene decidirlo conscientemente.
- [ ] `Daily_Loss_Flatten=true`.
- [ ] `Use_Calendar_Filter=true` con `Calendar_Currencies="USD"`.
- [ ] Alarma externa (correo/push del terminal) sobre las cadenas "GUARDIA DE EQUITY", "LÍMITE DE PÉRDIDA DIARIA" y "❌ ERROR al enviar orden".

**Operativa**
- [ ] Un solo set activo tras la atribución (§4.1).
- [ ] Revisar semanalmente el "RESUMEN PARCIAL" del log: proporción de TP completo vs ganancia parcial; si la ganancia parcial domina, el trailing/BE está recortando la cola derecha.
- [ ] Plan de retirada escrito: si el DD real supera el p95 del Monte Carlo OOS, apagar y revisar.

---

## 9. Notas de implementación para quien compile

- Requiere `#include <Trade\Trade.mqh>` estándar; sin dependencias externas.
- `DEAL_SL` / `DEAL_TP` en `HistoryDealGetDouble` existen desde builds de 2020; si el compilador los rechaza, el bróker/terminal es demasiado viejo y el fallback por comentario sigue funcionando.
- En optimización, `GlobalVariablesDeleteAll(GV_PREFIX)` limpia el estado al inicio de cada pasada (MQL_TESTER). En vivo no se borra nunca.
- `Sleep(300)` dentro de `FlattenAll` es ignorado por el tester y da tiempo al servidor en vivo entre reintentos.
- El panel añade cinco líneas (sets, riesgo real, HWM/DD, calendario); `ArrayResize(lines, 90)` deja margen.
