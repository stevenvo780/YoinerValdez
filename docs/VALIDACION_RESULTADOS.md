# Resultados de la validación cuantitativa — OHLCMTF SCALPER v14 sobre XAUUSD

Fecha: 2026-09-17. Datos: ticks/velas M1 Dukascopy XAUUSD, 2023-01-03 → 2026-09-11 (1.151 días, 1,31 M de velas M1, sin huecos anómalos,
precio 1.804 → 5.597). Hora de servidor simulada UTC+2/+3 con DST de EE. UU. Spread real mediano 43 pts, p90 75, p99 122.
Motor: port en Python del EA (`ohlc_quant/`), 95 tests. Informes crudos en `ohlc_quant/reports/full/` (VALIDACION.md + CSV),
`reports/grid/`, `reports/synthetic_v141_256/`, `reports/full_stress_*`.

## 1. Veredicto

**Hay una ventaja estadística modesta y dependiente del régimen. No es un sistema listo para real; sí es un candidato para demo con capital ≥ $3.000 y expectativas bajas.**

| Configuración | n | Neto | PF | DD máx | Expectativa | Riesgo real medio/máx |
|---|---|---|---|---|---|---|
| v14.0 · $300 (original) | 457 | +$1.545 (+515%) | 1.37 | 24.7% | $3.38 | 4.49% / 12.84% |
| v14.1 · $300 | 75 | +$78 | 1.36 | 15.8% | $1.04 | 2.07% / 2.49% (872 señales omitidas) |
| v14.1 · $3.000 | 461 | +$1.888 (+63%, ~14%/año) | 1.46 | 7.7% | $4.09 (0.14 R) | 0.61% / 2.45% |
| LEAN (solo set fijo H1) · $3.000 | 162 | +$757 (+25%) | 1.49 | 6.7% | $4.67 | 0.73% / 2.16% |
| Solo set custom (M5) · $3.000 | 434 | +$1.603 | 1.42 | 9.5% | $3.69 | 0.62% / 2.48% |

- El backtest original (+$1.820 con $300) se reproduce en espíritu: con $300 y lote 0.01 el sistema arriesga 4-13% por operación. Ese rendimiento es apalancamiento, no estrategia.
- Con el sizing corregido, $300 no permite operar (872 de 946 señales exceden el techo del 2.5%). El barrido de depósito muestra que el sizing es coherente a partir de **$2.000** (10 omisiones) y limpio desde **$5.000**.
- Capital para 1% de riesgo con SL de ATR×1.8: $1.135 con ATR mediano, $3.494 con ATR p90.

## 2. Dependencia temporal y de outliers (v14.1 $3.000)

| Año | n | Neto | PF | DD |
|---|---|---|---|---|
| 2023 | 138 | +$99 | 1.16 | 5.2% |
| 2024 | 128 | +$70 | 1.08 | 6.7% |
| 2025 | 121 | +$649 | 1.57 | 5.2% |
| 2026 (8,5 meses) | 71 | +$1.055 | 1.77 | 9.4% |

- Dos años prácticamente planos (2023-2024) y todo el beneficio en el mercado alcista de oro 2025-2026.
- Sin las 18 mejores operaciones (4%): PF 1.04, +$155. Sin el mejor mes (2025-10): PF 1.36. Sin los viernes: PF 1.29. Sin ambos: PF 1.21.
- Por fuerza de señal: fuerza 4 → $1.15/operación; fuerza 5 → $6.28; fuerza 6 → $7.38. El score discrimina.
- Salidas: 286 SL (−$14.0 medio) frente a 175 TP (+$33.7 medio). Sistema de cola derecha: pocas ganancias grandes pagan muchas pérdidas pequeñas.

## 3. Monte Carlo (20.000 corridas sobre las 461 operaciones, retornos fraccionales)

| | DD p50 | DD p95 | DD p99 | P(DD ≥ 20%) | Ruina (50%) | P(neto < 0) |
|---|---|---|---|---|---|---|
| v14.1 $3.000 barajado | 8.7% | 13.4% | 16.0% | 0.1% | 0% | 0% |
| v14.1 $3.000 bootstrap | 8.8% | 15.2% | 19.2% | 0.7% | 0% | 0.4% |
| v14.0 $300 bootstrap | 51% | 74% | 83% | 100% | 9.7% | 4.7% |

Con riesgo real del 0.6% el drawdown esperado queda por debajo del 12% configurado en el 85-90% de los escenarios; racha perdedora p99 de 14.

## 4. Fuera de muestra y walk-forward (preset LEAN, malla lookback × SL)

- Partición 70/30 por fecha: mejores parámetros in-sample → OOS PF 1.22, expectativa $3.40; defaults → OOS PF 1.69, $11.26. Optimizar empeora: el OOS coincide con el régimen alcista y los defaults lo aprovechan mejor que lo optimizado en 2023-2024.
- Walk-forward rodante (IS 6 m / OOS 2 m, 19 ventanas): eficiencia mediana 0.38, 47% de ventanas con eficiencia ≥ 0.5, 68% de ventanas OOS positivas, **PF concatenado OOS 1.37 (+$543 en 154 operaciones)**.
- Walk-forward anclado: eficiencia mediana 1.19, 58% positivas, PF OOS 1.36.
- Parámetros elegidos inestables entre ventanas (lookback 8-14, SL 1.4-2.2). Sobre la ventana parcial hasta abril de 2026 el WFA rodante daba PF 0.94: el resultado positivo depende de los últimos meses.

## 5. Sensibilidad (LEAN $3.000, 3,7 años)

- Mesetas amplias: puntuación 0.96 en lookback × SL y 1.00 en margen × cuerpo (el 96% de esa malla rinde ≥ 50% del máximo).
- Parámetros sensibles (±20% mueve la expectativa más de 20%): `min_body_ratio` (−27%), `atr_sl_mult` (−24% en ambos sentidos), `trend_lookback` (−21 a −25%), `session_end_hour` 18 (−16%).
- Insensibles: `pp_trail_start_r`, `max_against_wick_ratio`, `min_breakout_atr_mult` hasta 0.35.
- Malla de 9.720 combinaciones (7 parámetros): en 2023-2024 el 96% rinde PF > 1 (mediana 1.29); en 2025-2026 el 90% (mediana 1.26); en el período completo el 94% (mediana 1.26, 152 operaciones por combinación). La zona rentable es amplia. Preferencias consistentes: SL 2.2-2.6 ATR mejor que 1.4-1.8, TP 4.0 mejor que 2.4, tendencia 20-28 barras mejor que 40, fuerza mínima 3-4 mejor que 5, cuerpo 0.45-0.55 mejor que 0.65.

## 6. Estrés de ejecución y configuración

| Escenario | LEAN vs base | v14.1 vs base |
|---|---|---|
| Spread ×1.5 / ×2 | −18% / −24% | — / −29% |
| Spread ×0.5 (cuenta raw) | — | **−25%** (497 operaciones, PF 1.34, DD 9%) |
| Slippage 30 pts | −14% | — |
| Latencia 1 min | −25% | +4% |
| Comisión $7/lote | −1.5% | — |
| Sin confirmación multi-TF | −38% | −49% |
| Sin filtro de tendencia | −35% | — |
| Sin protección progresiva | +0.5% | — |
| Sin filtro de sesión | −5% (DD 8.8%) | −6% (DD 13.5%) |
| Reloj UTC+0 / UTC+2 sin DST | +43% / +38% | −3% / — |
| Set custom en M15 / M30 | — | PF 1.25 / 1.20 |
| Sesión 13-20 | — | PF 1.50 |

Hallazgo importante: con el spread real de Dukascopy (mediana 43 pts > `HighSpread_Threshold` 28) el **99% de las entradas ocurren en "modo spread alto"**: SL ×1.35 (2.43 ATR) y riesgo ×0.45. Ese modo mejora el sistema (coincide con la preferencia de la malla por SL anchos) y en una cuenta raw con spread bajo desaparece y el rendimiento cae un 25%. La configuración efectiva debe hacerse explícita: `ATR_SL_Multiplier` 2.2-2.4 y riesgo 0.5-0.6% directamente.

## 7. Hipótesis nula

La estrategia sobre 96 caminos sintéticos de un año sin estructura (paseo aleatorio con regímenes de volatilidad, saltos y gaps): mediana de PF 0.95, 44% de caminos con neto positivo. El PF real 1.46 queda en el percentil 96 y la expectativa en el 92. Sobre 256 caminos de dos años: 39% positivos, PF máximo 1.77. Evidencia de ventaja real al nivel de significancia habitual, pero no contundente dada la concentración temporal.

## 8. Recomendaciones operativas

1. Capital mínimo $3.000-5.000; riesgo fijo 0.5-0.75% (`Min_Risk_Percent = Max_Risk_Percent`), `Hard_Risk_Cap_Percent` 1.5.
2. Hacer explícito el modo spread alto: `ATR_SL_Multiplier` 2.2-2.4, `ATR_TP_Multiplier` 4.0, y subir `HighSpread_Threshold` al p90 real del bróker (75 pts en Dukascopy) para que solo actúe en picos.
3. Mantener confirmación multi-TF y filtro de tendencia (los dos filtros que sostienen la expectativa); la protección progresiva es neutra en el set fijo.
4. Sesión: el resultado depende del reloj del bróker; verificar en demo que 7-20 servidor cubre Londres + Nueva York. Sesión 13-20 rinde igual con menos operaciones.
5. El set custom (M5) aporta dos tercios de las operaciones y del neto pero con más drawdown; el fijo tiene mejor expectativa por operación. Decisión razonable: ambos con `Max_Trades_Per_Day` 3, o solo fijo si se prioriza DD.
6. Esperar años planos: 2023 y 2024 rindieron 2-3%. El plan de retirada debe basarse en el DD p95 del Monte Carlo (15%), no en el rendimiento.
7. Demo ≥ 8 semanas comparando cada entrada con la señal del motor Python sobre los mismos datos.

## 9. Reproducir

```bash
cd ohlc_quant && .venv/bin/python scripts/validate_full.py                   # reports/full/VALIDACION.md
.venv/bin/python scripts/grid_search.py 2023-01-01 2026-09-13 lean 3000      # reports/grid/
.venv/bin/python -m ohlc_quant synthetic-mc --paths 256 --days 730 --preset v141 --deposit 3000
.venv/bin/python -m ohlc_quant stress --preset v141 --deposit 3000
```
