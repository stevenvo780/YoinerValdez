# Plan v16 — mejorar el rendimiento, no el relato

Fecha: 2026-09-21. Parte de la síntesis `sintesis_auditoria_v14_vs_v15.md`.
Este documento no cambia el robot. Define qué cuenta como mejora y en qué orden se demuestra, antes de tocar `Config.mqh`.

## 1. Qué dice la síntesis, y qué le falta

La síntesis es correcta en el veredicto. En las dos capturas, con el mismo historial (240.031 barras, 68.057.638 ticks), la prueba llamada v14 gana más dinero y con mejor calidad de operaciones que la llamada v15. No hay base para decir que v15 sea más rentable. El drawdown relativo de 8,13 % frente a 31,54 % no demuestra un robot más seguro: el depósito pasó de 300 a 5.000 y la caída en dinero subió de 236,51 a 435,78.

También acierta en lo que no afirma: la causa no está aislada, el mismo número de barras no prueba que los inputs fueran iguales, y la comparación anterior que favorecía a v15 queda descartada.

Lo que la síntesis no cierra, y es lo que decide la v16:

El depósito no explica el empeoramiento. El factor de beneficio, la tasa de acierto y la expectativa por operación no escalan con el capital. Pasaron de 2,95 a 1,73, de 54,55 % a 43,42 % y de 23,65 a 13,55.

Tampoco lo explica el tamaño de la posición. Con los brutos de las capturas:

| | Anterior (300) | Nueva (5.000) |
|---|---:|---:|
| Ganadoras / perdedoras | 42 / 35 | 33 / 43 |
| Ganancia media | 65,60 | 73,75 |
| Pérdida media | 26,69 | 32,66 |
| Ratio ganancia/pérdida | 2,46 | 2,26 |

La relación entre ganancia media y pérdida media casi no cambió. La expectativa cayó porque unas nueve operaciones pasaron de ganadoras a perdedoras. El lote no convierte una ganancia en pérdida si el stop y el objetivo están en el mismo precio. En esta prueba v15 no “arriesga menos”: arriesga dólares parecidos (pérdida media 27 frente a 33) con peor selección o peor salida.

Eso descarta, para estas dos capturas, el relato del `LEEME.md`. Ese relato es verdad con 300: el lote mínimo de 0,01 no cabe en el techo y el robot deja de operar. Aquí hay 76 operaciones contra 77. Con 5.000 el techo del 2,5 % no está omitiendo la muestra.

La guardia de drawdown de v15 tampoco es una buena explicación de esta captura. Salta al 12 % y cierra posiciones. El drawdown relativo reportado es 8,13 %, por debajo de ese umbral. Salvo que MetaTrader mida ese 8,13 % de otra forma que el high-water mark del EA, `DD_Flatten_Positions` no llegó a actuar.

El único cambio de v15 que puede voltear ganadoras en perdedoras sin cambiar el número de operaciones es la geometría del stop y del objetivo: ATR de la vela cerrada, y el modo spread alto (stop ×1,35, el objetivo no se toca). El modo spread alto, por sí solo, ensancha el stop y debería subir la tasa de acierto, no bajarla. El signo observado va al revés. Hay que medirlo, no darlo por causa.

El laboratorio Python no reproduce la captura. Sobre 3,7 años, v14.0 con 300 da factor 1,37 y 457 operaciones, no 2,95 y 77. Si el gráfico del tester es M1, 240.031 barras son del orden de seis meses, no de 3,7 años. Un factor 2,95 en 77 operaciones cabe en una racha. No es el listón de la v16.

## 2. Qué significa “mejor rendimiento”

v16 mejora el rendimiento solo si bate a v15 con el mismo dinero, los mismos costes y sin volver al apalancamiento de la prueba de 300.

No es un objetivo, y no se usa como puerta:

- Superar +1.820,77 o el factor 2,95 de la prueba con 300.
- Bajar el drawdown porcentual subiendo el depósito.
- Operar más veces.
- Elegir el candidato que mejor se vea en 2025-2026 o en la ventana de 77 operaciones.

Sí es la puerta. Todo se compara contra un baseline congelado: `EAParams()` (defaults v15), depósito 5.000, datos Dukascopy XAUUSD ya descargados (2023-01-03 a 2026-09-11), `BrokerSpec()` y `ServerClock(2, "us")`. El baseline se corre una vez y se guarda. No se vuelve a tunear.

En esa muestra larga, el candidato tiene que cumplir las seis cosas a la vez:

1. Factor de beneficio al menos 0,05 por encima del baseline, y no inferior a 1,45.
2. Expectativa en R (`avg_r`) mayor o igual que el baseline.
3. 2023 y 2024 con factor de beneficio de al menos 1,05, y ninguno más de 0,05 por debajo del baseline de ese año.
4. Drawdown máximo porcentual no peor que el baseline más 1 punto, y en todo caso por debajo del 12 % configurado.
5. Retorno dividido por drawdown mayor o igual que el baseline.
6. Walk-forward rodante (IS 6 meses / OOS 2 meses) con factor de beneficio concatenado fuera de muestra no peor que el del propio baseline. El 1,37 publicado es del preset LEAN, no de v15 completo: primero se mide el baseline y ese número es el suelo.

La ventana de las capturas, cuando se tengan las fechas, es una comprobación, no el sitio donde se elige. Si el candidato mejora esas 77 operaciones y falla 2023 o 2024, se rechaza.

Además, en cuanto exista el reporte HTML del cliente: la misma ventana, depósito 5.000, v16 contra v15. Factor de beneficio y expectativa mayores o iguales que la captura nueva (1,73 y 13,55). Si el Strategy Tester y el laboratorio discrepan, manda el Strategy Tester y v16 no se entrega.

Si ningún candidato pasa la puerta, no hay v16 de rendimiento. Se dice eso y no se publica otro set de defaults.

## 3. Qué no se cambia aunque mejore una tabla

Se quedan como están, porque son la corrección de riesgos reales y no son la causa medida de estas capturas:

- `Allow_MinLot_Above_Cap = false`
- `Size_On_Equity = true`
- `Use_Total_Drawdown_Limit`, `DD_Use_Equity_Peak`, `DD_Flatten_Positions`, `Max_Total_Drawdown_Pct = 12`
- `Streak_Reset_Min_R = 0.25`
- Filtro de tendencia y confirmación multi-timeframe. En el estrés publicado, quitarlos cuesta del orden del 35 % y del 49 % de la expectativa.

No entra en v16, porque una pasada anterior ya los dejó iguales o peores que el baseline y mezclarlos fue el fallo de `scripts/improve.py`:

- `Min_Signal_Strength = 5` para los dos sets.
- Piso de fuerza solo para el set custom.
- `Trend_Lookback = 20` o 24.
- `Max_Trades_Per_Day = 3`.
- `Max_Against_Wick_Ratio = 0.42`.
- `TF_Fast = M15`.
- Apagar `Prefer_Expansion_Break` como parte de un paquete. Solo volvería a mirarse si la geometría del apartado 5 falla y se abre una segunda ronda, él solo, con la misma puerta.

`custom_min_signal_strength` no se porta al EA. El simulador dimensiona contra `min_signal_strength` global; el campo nuevo solo filtra. No es un preset entregable.

## 4. Orden de trabajo

### Fase A — Congelar el baseline

Archivos nuevos:

- `ohlc_quant/scripts/v16_gate.py`
- `ohlc_quant/reports/v16/baseline.json`

El script corre solo `EAParams()` a depósito 5.000 y escribe, sin redondear a dos decimales en el JSON: número de operaciones, neto, factor de beneficio, `avg_r`, tasa de acierto, ganancia media, pérdida media, drawdown porcentual, retorno/drawdown, factor por año 2023, 2024, 2025 y 2026, y los contadores `skip_minlot`, `skip_pause`, `dd_latches`.

Año natural: `run_backtest(..., start=f"{y}-01-01", end=f"{y+1}-01-01")` con depósito nuevo. Eso mide el año aislado. No se usa para el factor de la muestra completa.

Walk-forward del baseline con la función ya existente `evaluate_many` / el camino de `scripts/validate_full.py` (IS 6 m, OOS 2 m). Guardar el factor concatenado fuera de muestra en el mismo JSON, clave `wfa_oos_pf`.

No se elige nada en esta fase. Si el baseline a 5.000 no cae cerca del v14.1 publicado a 3.000 (461 operaciones, factor 1,46, drawdown 7,7 %), parar y explicar la diferencia antes de seguir. Una diferencia grande de número de operaciones significa que el port o el depósito no son los que creemos.

### Fase B — Atribuir la captura, un interruptor por fila

Reescribir la cadena de `ohlc_quant/scripts/ab_attribution.py`. Cada fila cambia un solo campo respecto a `EAParams.v140()`, depósito 5.000, no 300:

| Fila | Único cambio sobre v14.0 |
|---|---|
| 0 | ninguno (`EAParams.v140()`) |
| 1 | `atr_closed_bar=True` |
| 2 | `use_avg_spread_for_mode=True` |
| 3 | `streak_reset_min_r=0.25` |
| 4 | `sizing_mode="v141"`, `allow_minlot_above_cap=False`, `size_on_equity=True` |
| 5 | `dd_use_equity_peak=True` |
| 6 | `dd_flatten_positions=True` |
| 7 | `EAParams()` como control de que no quedó otro campo fuera |

La fila 7 tiene que coincidir con el baseline de la fase A. Si no coincide, hay un campo distinto y no se interpreta la tabla.

Columnas obligatorias además de las de `metrics_table`: tasa de acierto, ganancia media, pérdida media, `avg_r`, `skip_minlot`, `skip_pause`, `dd_latches`.

Lectura, antes de proponer una causa al cliente:

- Si la tasa de acierto cae en la fila 1 y no en las otras, la causa de laboratorio es el ATR de vela cerrada.
- Si cae en la fila 2, es el modo de spread. Eso contradice el signo esperado (stop más ancho, más aciertos) y hay que mirar cuántas entradas quedan en modo spread alto.
- Si las filas 4, 5 y 6 no mueven la tasa de acierto y `dd_latches` es 0, sizing y guardia quedan fuera de la explicación. Es lo que predicen las capturas.
- Esta tabla explica el laboratorio. No explica las capturas hasta tener las fechas.

Para las capturas hace falta el reporte, no otro pantallazo. Sin estos datos la fase B no se corre sobre “la ventana del cliente” y no se inventan fechas:

- Fecha inicial y final del Strategy Tester.
- Símbolo exacto, modelo (todos los ticks o OHLC), apalancamiento, moneda de la cuenta.
- El `.set` o la lista de inputs. En especial `HighSpread_Threshold`, `ATR_SL_Multiplier`, `ATR_TP_Multiplier`, `Use_Avg_Spread_For_Mode` y `Allow_MinLot_Above_Cap`.
- El HTML o el XLSX del informe, de las dos pasadas.

Con las fechas, la misma tabla de siete filas se repite con `start` y `end`. Ahí sí se puede decir qué interruptor reproduce la caída de 54 % a 43 % de acierto.

### Fase C — Un solo candidato de estrategia

El único cambio de rendimiento que la validación ya sostiene, y que `improve.py` declaró y no ejecutó, es hacer explícita la geometría que hoy entra por la puerta de atrás.

Hoy el umbral de spread alto es 28 puntos. En Dukascopy la mediana es 43 y el percentil 90 es 75, así que casi toda entrada toma stop ×1,35 (efectivo 1,80×1,35 = 2,43 ATR) y riesgo ×0,45. La malla publicada prefiere stop 2,2-2,6 ATR y objetivo 4,0, y en cuenta raw (sin ese modo) el resultado cae cerca de un 25 %.

Candidato único, un `with_` sobre el baseline, nada más:

```text
atr_sl_mult = 2.2
atr_tp_mult = 4.0
high_spread_threshold = percentil 90 del spread de ESA muestra
```

En Dukascopy el percentil 90 medido por el propio script tiene que salir cerca de 75. Si no sale, no se escribe 75 a mano: se usa el valor medido y se anota. En el bróker del cliente el 75 no se copia. El umbral es el percentil 90 del spread de su informe, o se deja el input y el `LEEME` dice cómo leerlo. Un umbral equivocado apaga o enciende el modo spread en el sitio contrario.

Regla de selección:

- Se mira solo la muestra hasta 2025-06-01, más los años 2023 y 2024 aislados.
- Se toca 2025-06-01 en adelante una sola vez, después de decidir.
- Pasa o no pasa la puerta del apartado 2. No hay segundo candidato en esta ronda.
- `scripts/improve.py` no se usa para decidir. Su `explicit` no se aplica, la última ventana llega hasta 2026-11-01 con datos que acaban el 2026-09-11, y el nombre por defecto pisa `improve_candidates_r2.csv`.

Si C1 no pasa, se para. No se apila fuerza 5, ni lookback, ni sesión 13-20 “a ver si entre todos”. La sesión 13-20 quedó en factor 1,50 en el estrés de v14.1, una diferencia pequeña y ya gastada como observación. No es candidata de v16.

### Fase D — Confirmar una vez

Solo si C1 pasó la puerta dentro de muestra. Una pasada, sin ajustar nada después de verla:

- Fuera de muestra desde 2025-06-01, corrida continua (las operaciones de esa cola sacadas del backtest largo, no un backtest nuevo con depósito reiniciado).
- Walk-forward contra el `wfa_oos_pf` del baseline.
- Estrés ya implementado: spread ×1,5 y ×2, slippage, comisión. No hace falta uno nuevo.
- Monte Carlo bootstrap de las operaciones fuera de muestra, no de la muestra completa.

Si el fuera de muestra o el walk-forward rompen la puerta, C1 se rechaza igual que si hubiera fallado dentro de muestra.

### Fase E — Portar solo si la fase D pasó

Únicos defaults que cambian, en los dos sitios a la vez:

- `mql5/Include/OHLCMTF/Config.mqh`: `ATR_SL_Multiplier`, `ATR_TP_Multiplier`, `HighSpread_Threshold`
- `ohlc_quant/ohlc_quant/engine/params.py`: `atr_sl_mult`, `atr_tp_mult`, `high_spread_threshold`

`HighSpread_Threshold` lleva en el comentario el percentil y la muestra (“p90 Dukascopy 2023-2026, medido en v16_gate”). No se presenta como constante universal.

No se añaden inputs. No se toca `Signals.mqh` salvo que el candidato aprobado lo exija, y C1 no lo exige.

Versión visible:

- Cabecera y `#property description` de `mql5/Experts/OHLCMTF/OHLCMTF_Scalper.mq5`
- `mql5/build_single_file.py`: salida `OHLCMTF_Scalper_v16_single.mq5`
- Copia a `ENTREGA_CLIENTE/` solo después de compilar
- `ENTREGA_CLIENTE/LEEME.md` reescrito en este orden: depósito 5.000, mismos inputs que v15 salvo los tres defaults, qué resultado tiene que salir en el tester para dar por buena la versión, y una frase explícita de que la prueba de +1.820 con 300 no es el objetivo porque arriesgaba varias veces el porcentaje configurado

Tests mínimos en `ohlc_quant/tests/`:

- Los defaults nuevos son 2,2, 4,0 y el umbral congelado en el JSON del baseline.
- `EAParams.v140()` sigue dejando el comportamiento anterior en sizing, ATR en formación y spread instantáneo. La v16 no debe mover la fila 0 de la atribución.
- Una señal con spread por debajo del umbral nuevo no recibe el multiplicador 1,35. Una con spread por encima, sí. Sirve para que el umbral no quede en un comentario.

Compilación: `mql5/compilar_ea.sh` o el `.bat`. Se entrega solo con 0 errores y 0 avisos. El `.ex5` nuevo sustituye al de v15 en `ENTREGA_CLIENTE/` con nombre v16, sin borrar el v15: el cliente tiene que poder repetir las dos pasadas.

### Fase F — La prueba que el cliente puede comparar

Misma ventana que las capturas, depósito 5.000 las dos veces, no 300 contra 5.000.

| Ajuste | v15 | v16 |
|---|---|---|
| Modelo, símbolo, fechas, ticks | idénticos | idénticos |
| Depósito | 5.000 | 5.000 |
| Resto de inputs | el `.set` de la captura nueva | el mismo `.set` |
| Excepción | defaults v15 | solo SL 2,2, TP 4,0 y el umbral de spread medido |

Se considera mejor solo si el informe nuevo cumple la puerta del apartado 2 en el laboratorio y, en el tester, factor de beneficio y expectativa no bajan respecto de la captura de 5.000. El drawdown relativo puede subir algo: con el stop más ancho es esperable. No puede pasar del 12 %.

## 5. Qué se le dice al cliente mientras tanto

v15 no es más rentable que la prueba anterior. La síntesis tiene razón.

La prueba anterior no es el rendimiento repetible del sistema. Son 77 operaciones, del orden de medio año si el gráfico es de un minuto, con un riesgo por operación varias veces mayor que el 0,25-1,25 % escrito en los inputs. El laboratorio, en 3,7 años y con el riesgo corregido, mide un factor cerca de 1,46, no de 2,95.

v16 no va a prometer recuperar los 1.820. Va a intentar subir la calidad de la operación de v15 (factor, R, años planos) sin quitar el techo de riesgo. Si la geometría explícita no pasa la puerta, la respuesta honesta es que v15 ya es el techo conocido y que no hay una v16 de rendimiento.
