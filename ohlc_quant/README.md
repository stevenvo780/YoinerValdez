# ohlc_quant — validación cuantitativa del EA OHLCMTF SCALPER v14 (XAUUSD)

Port fiel de la lógica del EA (v14.0 y v14.1) a Python para poder simular fuera de MetaTrader:
señales vectorizadas sobre velas cerradas, simulador de ejecución en Numba sobre barras M1
reconstruidas de ticks reales (Dukascopy), y un conjunto de análisis de robustez.

## Instalación

```bash
python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"
```

## Datos

```bash
.venv/bin/python scripts/download_candles.py 2023-01-01 2026-09-12   # velas M1 bid/ask Dukascopy → data/bars/*.parquet (2 peticiones/día)
.venv/bin/python -m ohlc_quant download 2023-01-01 2026-09-12        # alternativa desde ticks (24 peticiones/día, más lento)
```

Dukascopy limita el ritmo: el cliente lleva limitador (1.5 req/s) y backoff; con más de 2-3 sesiones concurrentes bloquea la IP durante minutos.

Los tiempos se convierten a hora de servidor de bróker con `--utc-offset 2 --dst us` (EET alineado al DST de
Nueva York, el estándar de los brókers de oro). `--dst eu|none` para otros brókers.

## Comandos

| Comando | Qué hace |
|---|---|
| `backtest` | Backtest completo; métricas, por set, por mes/día, exclusiones, riesgo real. |
| `compare` | v14.0 vs v14.1 vs preset LEAN con los mismos datos. |
| `attribution` | Ambos sets / solo fijo / solo custom. |
| `capital` | Capital necesario por cuantil de ATR y barrido de depósitos. |
| `mc` | Monte Carlo (barajado, bootstrap, bloques) sobre los trades del backtest, tal cual y con sizing corregido. |
| `report FICHERO` | Mismo análisis sobre un reporte exportado del Strategy Tester (xlsx/html). |
| `mc-summary` | Monte Carlo aproximado a partir del resumen del reporte (sin lista de trades). |
| `wfa` | Walk-forward (rodante o anclado) con malla de parámetros y eficiencia OOS/IS. |
| `oos` | Partición temporal 70/30: malla en IS, evaluación única en OOS. |
| `sensitivity` | ±10/20 % uno a uno y malla 2D con puntuación de meseta. |
| `stress` | Spread ×1.5/×2/+20 pts, slippage, comisión, latencia, stops level, sin PP, sin filtros, relojes alternativos, tipos de bróker. |
| `synthetic-mc` | La estrategia sobre N caminos sintéticos calibrados (regímenes de volatilidad, saltos, gaps de fin de semana). |

Opciones comunes: `--preset v16|v15|v141|v140|lean`, `--set param=valor` (cualquier campo de `EAParams`), `--broker campo=valor`,
`--deposit`, `--start/--end`, `--synthetic DIAS` (datos sintéticos en vez de reales), `--workers`.

`v15` y `v141` son los defaults congelados del robot v15. `v16` es el robot entregado en `ENTREGA_CLIENTE/OHLCMTF_Scalper_v16.mq5`.
No uses `v141` para medir la v16: después del cambio, `v141` sigue siendo la v15.

```bash
.venv/bin/python -m ohlc_quant compare --deposit 300
.venv/bin/python -m ohlc_quant backtest --preset v15 --deposit 5000
.venv/bin/python -m ohlc_quant backtest --preset v16 --deposit 5000
.venv/bin/python -m ohlc_quant backtest --preset v141 --deposit 3000 --set use_custom_pair=false
.venv/bin/python -m ohlc_quant wfa --preset lean --deposit 3000 --grid '{"structure_lookback":[8,12,16],"atr_sl_mult":[1.5,1.8,2.2]}'
.venv/bin/python -m ohlc_quant stress --preset lean --deposit 3000
.venv/bin/python -m ohlc_quant report ~/ReportTester-12345.xlsx --deposit 300
```

## Supuestos del simulador

- Evaluación de señales en la apertura de cada vela del TF de entrada, con velas cerradas (índice ≥1); sin look-ahead (hay tests).
- Ejecución al primer tick de la vela M1 (ask para compras, bid para ventas); SL/TP comprobados contra el rango de cada M1.
  Si SL y TP caen en la misma M1 se asume SL (pesimista); `stress` incluye la variante optimista.
- Gestión progresiva de SL evaluada al inicio de cada M1 con su precio de apertura (el EA lo hace por tick).
- El spread promedio de 25 ticks del EA se aproxima con el spread medio de la M1 anterior.
- Sin swap. Comisión por lote configurable. Slippage de relleno configurable.
- Sizing `v140` reproduce el original (lote mínimo forzado); `v141` aplica el techo duro de riesgo.

## Validación completa

```bash
.venv/bin/python scripts/validate_full.py            # datos reales → reports/full/VALIDACION.md + CSVs
.venv/bin/python scripts/validate_full.py --synthetic 420   # prueba del pipeline sobre datos sintéticos
```

Secciones: backtests base (v14.0/v14.1/LEAN, $300 y $3000), riesgo real y capital, distribución temporal y exclusiones,
Monte Carlo, partición 70/30, walk-forward rodante y anclado, sensibilidad 1D/2D, estrés, sesión/sets, por año e
hipótesis nula (la estrategia sobre 96 caminos sintéticos sin estructura: `synthetic-mc`).

## Tests

```bash
.venv/bin/python -m pytest -n 12
```

Cubren indicadores contra referencias independientes, alineación de velas y hora de servidor, ausencia de look-ahead,
invariantes del simulador (riesgo real ≤ techo, una posición a la vez, guardias de equity/diario/racha, cooldown, PP,
cierre de fin de semana), métricas, Monte Carlo, parser de reportes, sizing, walk-forward, sensibilidad, estrés y CLI.
