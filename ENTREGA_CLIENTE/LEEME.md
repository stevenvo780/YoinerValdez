# OHLCMTF Scalper v16 — cómo se usa

Este archivo es para quien opera el robot en MetaTrader 5. No hace falta programar.

La versión que hay que instalar es **v16**. El archivo es `OHLCMTF_Scalper_v16.mq5`. El v15 sigue en esta carpeta por si se quiere repetir la prueba anterior; no se usan los dos a la vez.

## Instalación

1. Abrir MetaTrader 5.
2. *Archivo → Abrir carpeta de datos → MQL5 → Experts*.
3. Copiar ahí `OHLCMTF_Scalper_v16.mq5`. No hace falta copiar carpetas ni librerías: el robot va entero en ese archivo.
4. En MetaTrader, pulsar F4 para abrir MetaEditor. Abrir el archivo y pulsar **Compilar** (F7). Tiene que decir `0 errors, 0 warnings`.
5. Volver al terminal. En el *Navegador*, bajo *Asesores Expertos*, aparece **OHLCMTF_Scalper_v16**.
6. Abrir un gráfico de **XAUUSD** (el oro de tu bróker; si el símbolo tiene otro nombre, ese es el que hay que usar). La temporalidad del gráfico no importa: el robot mira por dentro las velas H1 y M5.
7. Arrastrar el asesor al gráfico. Activar *Algo Trading* (el botón de la barra superior). En la ventana de propiedades, pestaña *Común*, marcar *Permitir trading algorítmico*.
8. Pulsar Aceptar. En la esquina del gráfico debe verse una cara sonriente, no una cruz. El panel del robot aparece sobre el gráfico.

No hay un `.ex5` ya compilado de la v16. Hay que compilarlo en el MetaEditor de tu terminal. El `.ex5` de la v15 que está en esta carpeta es solo de la versión anterior.

## No poner las dos versiones juntas

v15 y v16 usan los mismos números mágicos. Si las dos están sobre el mismo oro, se pisan las operaciones. Deja solo la v16 en el gráfico y quita la v15.

## Qué hace la v16, sin tocar parámetros

Al arrastrarla, los valores por defecto ya son los medidos. No hace falta cambiarlos para usarla como se entregó:

| Parámetro | v15 | v16 (dejarlo así) |
|---|---|---|
| `Structure_Lookback` | 12 | **10** |
| `ATR_TP_Multiplier` | 3.20 | **3.0** |
| `Prefer_Expansion_Break` | true | **false** |
| `Use_Progressive_Protection` | true | **false** |

El stop de la entrada y el objetivo siguen activos. Lo que está apagado es el traslado del stop por etapas (la protección progresiva). La guardia de drawdown no se tocó: si la cuenta cae un 12 % desde su máximo, el robot cierra y se bloquea 72 horas.

Tampoco se aflojó el riesgo. Si el lote mínimo de 0,01 no cabe en el techo del 2,5 % de la cuenta, **no abre** y lo dice en el panel como "RIESGO REAL".

## Capital

Hace falta una cuenta de **3.000 a 5.000** en la moneda del oro (normalmente dólares). Con 300 el robot casi no opera: el lote mínimo de oro arriesgaría mucho más de lo que el techo permite, y por eso omite la señal. Eso no es un fallo.

La prueba vieja de unos +1.820 con 300 no es el objetivo. Esa cuenta arriesgaba varias veces el porcentaje escrito en los parámetros. No se compara un backtest de 300 con uno de 5.000.

## Qué se midió, y qué no

En el laboratorio, con las mismas velas de oro de 2023 a 2026 y **el mismo depósito de 5.000**, la v16 ganó más que la v15 y con menos caída:

| | v15 | v16 |
|---|---:|---:|
| Beneficio neto | 1.860 | 2.697 |
| Factor de beneficio | 1,43 | 1,49 |
| Caída máxima | 5,8 % | 5,4 % |
| Riesgo real máximo de una operación | 2,3 % | 2,1 % |

2023 y 2024 siguieron en positivo. Esto es una simulación sobre datos Dukascopy, no una promesa de la cuenta del bróker. El spread, la comisión y el nombre del símbolo cambian el resultado. Antes de dinero real: **demo de 4 a 8 semanas** con el mismo bróker y el capital que se piensa usar. Si la caída pasa del 15 %, parar y revisar.

## Ajustes solo si se sabe por qué

Si no, dejar los defaults. Opcionales, para una cuenta real ya en demo:

- `Hard_Risk_Cap_Percent` = 1.5 si se quiere un techo más bajo que 2.5.
- `Min_Risk_Percent` = `Max_Risk_Percent` = 0.75 para arriesgar siempre lo mismo.
- `Close_Before_Weekend` = true y `Friday_Entry_Cutoff_Hour` = 18 para no dejar la operación abierta el fin de semana.
- `Use_Calendar_Filter` = true y `Calendar_Currencies` = "USD" para no operar encima de noticias grandes. En el Strategy Tester hace falta antes el script de abajo.
- `Max_Spread_Points` = 60 en cuenta raw, o 100 en cuenta estándar, para no entrar con el spread disparado.

## El v15, por si hay que compararlo

`OHLCMTF_Scalper_v15.mq5` y `OHLCMTF_Scalper_v15.ex5` son la entrega anterior. Se instala igual (copiar a *Experts* y, si hace falta, compilar). Sirve para repetir el backtest viejo. Para operar, usar la v16.

Respecto al robot original (v14), la v15 ya había corregido esto, y la v16 lo conserva:

| Antes (v14) | Desde la v15 |
|---|---|
| Con 300 arriesgaba entre 4 % y 13 % por operación sin avisar. | Si el lote mínimo supera el techo, no abre. |
| El límite de drawdown del 12 % no funcionaba. | Mide la caída contra el máximo de la cuenta, cierra todo y bloquea 72 h. |
| No se distinguía la señal H1 de la M5. | Cada una tiene su número mágico y su etiqueta (F o C) en el panel. |
| Al reiniciar el terminal perdía la cuenta del día y el stop original. | Lo recupera del historial. |
| Un parámetro incoherente arrancaba igual. | El robot no arranca y dice cuál está mal. |

## Script de calendario

`ExportCalendarCSV.mq5` (y su `.ex5`) no es el robot. Va en *MQL5 → Scripts*. Solo hace falta si se quiere probar el filtro de noticias dentro del Strategy Tester: se ejecuta una vez, genera `news_events.csv`, y el robot lo lee si `Use_Calendar_Filter` está en true.
