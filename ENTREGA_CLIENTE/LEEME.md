# OHLCMTF Scalper v15 — qué es y cómo se usa

## El bot es UN solo archivo, igual que antes

- **`OHLCMTF_Scalper_v15.mq5`** → el robot completo (código fuente). Es la versión corregida del `expert 3.3.mq5` que enviaste.
- **`OHLCMTF_Scalper_v15.ex5`** → el mismo robot ya compilado, listo para arrastrar al gráfico.

Se instala exactamente como el anterior:

1. En MetaTrader 5: *Archivo → Abrir carpeta de datos → MQL5 → Experts*.
2. Copiar ahí `OHLCMTF_Scalper_v15.mq5` (y opcionalmente el `.ex5`).
3. Si copiaste solo el `.mq5`: abrirlo en MetaEditor (F4 en el terminal) y pulsar **Compilar** (F7). Debe decir `0 errors, 0 warnings`.
4. En el Navegador del terminal aparece **OHLCMTF_Scalper_v15** bajo *Asesores Expertos*. Arrastrarlo al gráfico de XAUUSD como siempre.

No hay que instalar carpetas ni librerías adicionales. Todo va dentro del archivo.

## Qué cambió respecto al bot anterior (lo importante)

| Antes (v14.0) | Ahora (v15) |
|---|---|
| Con $300 arriesgaba entre 4 % y 13 % de la cuenta por operación sin avisar (el lote mínimo 0.01 de oro no cabe en 0.25-1.25 %). | Si el lote mínimo supera el techo de riesgo (2.5 %), **no abre la operación** y lo dice en el log y en el panel ("RIESGO REAL"). |
| El límite de drawdown del 12 % no funcionaba (por eso el backtest llegó a 30 %). | Mide el drawdown contra el máximo histórico de la cuenta, **cierra todo** al superarlo y bloquea el robot 72 h (o hasta reset manual). |
| No se sabía qué señal (H1 o M5) generó cada operación. | Cada set lleva su propio número mágico y etiqueta (F / C) y el panel muestra las estadísticas de cada uno. |
| Si se reiniciaba el terminal perdía la cuenta de operaciones del día, la racha y el stop original. | Recupera todo desde el historial y variables globales. |
| Filtro de noticias solo por horas fijas. | Filtro por **calendario económico real** (activar `Use_Calendar_Filter`). Para backtests, el script `ExportCalendarCSV` genera el archivo de eventos. |
| Sin validación de parámetros. | Si un parámetro es incoherente, el robot no arranca y explica por qué. |

Todos los parámetros mantienen los mismos nombres y valores por defecto. Los nuevos están al final de cada grupo y en los grupos 13-14.

## Capital: esto es lo más importante

**Con $300 el robot corregido casi no va a operar** (omitirá 9 de cada 10 señales por riesgo). No es un fallo: es que con lote
mínimo 0.01 en oro cada operación necesita $1.000-3.500 de cuenta para arriesgar el 1 %. El backtest anterior de +$1.820 con $300 se
conseguía arriesgando 10 veces más de lo configurado.

Con **$3.000-5.000** el robot opera normalmente. Sobre 3,7 años de datos reales de XAUUSD el resultado fue: +63 % total (unos 14 %
anuales), drawdown máximo 7,7 %, con dos años flojos (2023-2024, +2-3 %) y el beneficio concentrado en 2025-2026. Detalle en
`docs/VALIDACION_RESULTADOS.md` del proyecto completo.

## Ajustes recomendados para cuenta real (opcionales)

- `Hard_Risk_Cap_Percent` = 1.5 (en vez de 2.5).
- `Min_Risk_Percent` = `Max_Risk_Percent` = 0.75 (riesgo fijo).
- `Close_Before_Weekend` = true y `Friday_Entry_Cutoff_Hour` = 18.
- `DD_Pause_Hours` = 0 (tras un corte por drawdown, revisar antes de reanudar; se reanuda con `DD_Manual_Reset` = true y reiniciar).
- `Use_Calendar_Filter` = true con `Calendar_Currencies` = "USD".
- `Max_Spread_Points` = 60 en cuentas raw / 100 en estándar.

## Antes de cuenta real

Probar 4-8 semanas en **demo** con el mismo bróker y el capital previsto. Si el drawdown supera el 15 %, parar y revisar.

## Otros archivos de esta carpeta

- `ExportCalendarCSV.mq5` / `.ex5`: script auxiliar (va en *MQL5 → Scripts*). Solo hace falta si se quiere probar el filtro de noticias en el Strategy Tester.
