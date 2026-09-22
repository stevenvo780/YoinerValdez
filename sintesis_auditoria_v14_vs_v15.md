# Síntesis corregida: OHLCMTF v14 frente a v15

## 1. Veredicto

**En las dos pruebas presentadas, la versión anterior obtuvo mejores resultados de rentabilidad. La nueva ganó menos y acumuló más pérdidas brutas. El cliente tiene razón sobre esas dos observaciones.**

No hay evidencia suficiente para afirmar que v15 sea «más potente» si con ello se entiende más rentable. Sí incorpora controles adicionales documentados, pero eso no demuestra una mejora global ni una mayor seguridad operativa ya validada.

**Resultado observado: peor rentabilidad en la prueba nueva. Causa exacta: todavía no demostrada.**

Se identifican las capturas como «anterior/v14» y «nueva/v15» según lo indicado en la conversación; las imágenes no acreditan por sí solas el archivo ejecutable ni sus parámetros completos.

## 2. Comparación correcta de las capturas

Los importes están expresados en la moneda del reporte, no identificada en las capturas. Las pérdidas se muestran en magnitud positiva para facilitar la comparación. [1][2]

| Métrica | Anterior | Nueva |
|---|---:|---:|
| Depósito inicial | 300,00 | 5.000,00 |
| Beneficio neto | 1.820,77 | 1.029,43 |
| Beneficio bruto | 2.755,02 | 2.433,79 |
| Pérdidas brutas | 934,25 | 1.404,36 |
| Factor de beneficio | 2,95 | 1,73 |
| Beneficio esperado por operación | 23,65 | 13,55 |
| Operaciones ganadoras | 42 de 77 (54,55 %) | 33 de 76 (43,42 %) |
| Factor de recuperación | 7,70 | 2,36 |
| Drawdown máximo de equity, en dinero | 236,51 | 435,78 |
| Drawdown relativo de equity | 31,54 % | 8,13 % |
| Total de operaciones | 77 | 76 |
| Barras procesadas | 240.031 | 240.031 |
| Ticks procesados | 68.057.638 | 68.057.638 |

Cálculos sobre esos datos:

- **Beneficio neto: 791,34 menos, una caída del 43,46 %.**
- **Pérdidas brutas: 470,11 más, un aumento del 50,32 %.**
- El factor de beneficio pasó de 2,95 a 1,73: la relación entre ganancias brutas y pérdidas brutas también empeoró. No es solo una diferencia en el porcentaje de retorno sobre el depósito.

## 3. Por qué el menor drawdown porcentual no demuestra superioridad

La nueva muestra un drawdown relativo menor, pero comenzó con un capital **16,67 veces mayor**. Al mismo tiempo, su caída máxima monetaria aumentó de 236,51 a 435,78. [1][2]

Por tanto, es correcto decir que **la nueva prueba tuvo menor drawdown porcentual**, pero no que el nuevo código haya reducido por sí solo el riesgo. La diferencia de capital impide aislar ese efecto. Tampoco deben confundirse las pérdidas brutas acumuladas con el drawdown: son medidas distintas.

## 4. Qué cambió y qué puede explicar el resultado

La documentación del repositorio describe un techo efectivo de riesgo por operación, protección de drawdown respecto al máximo de equity, ATR de vela cerrada, uso del spread promedio y cambios en el reinicio de las rachas de pérdidas. [3][4]

Estos cambios pueden modificar qué operaciones se toman, su tamaño, sus salidas y las pausas del robot. Son **mecanismos posibles**, no una explicación causal ya comprobada de la diferencia observada.

No es válido atribuir toda la caída a que «ahora arriesga menos» ni afirmar que existe un error específico sin contrastar operaciones y registros. Además, 77 frente a 76 operaciones no sustenta la explicación de que el nuevo resultado se deba simplemente a haber dejado de operar masivamente. [1][2]

El repositorio reconoce que la validación documentada se realizó mediante un port en Python y que, al preparar esa entrega, estaba pendiente el contraste nativo en el Strategy Tester de MT5. Esos resultados no sustituyen una comparación controlada de ambas versiones en MT5. [4]

## 5. Qué falta para determinar la causa

Repetir ambas versiones con **el mismo depósito**, período, bróker, símbolo, historial, modelado, apalancamiento, costes y parámetros comunes; después comparar entradas, lotajes, stop loss, objetivos, cierres y señales rechazadas. Para separar efectos, cambiar una protección o ajuste cada vez.

Que las capturas tengan el mismo número de barras y ticks no demuestra que todos los demás ajustes sean idénticos. Esta auditoría no ejecutó ese contraste nativo y no establece cuál versión rendirá mejor en el futuro.

## 6. Rectificación de la primera respuesta

La primera comparación de esta conversación utilizó cifras incorrectas para la versión anterior y afirmó erróneamente que los historiales tenían diferentes cantidades de barras y ticks. **Esa comparación y su conclusión favorable a v15 quedan descartadas.**

**Conclusión final: v15 tiene controles adicionales documentados, pero no una mejora de rendimiento demostrada. En las pruebas aportadas, la anterior fue más rentable. Falta aislar la causa del deterioro antes de atribuirlo al código o a la configuración.**

## Fuentes

[1] Captura aportada por el usuario como prueba anterior: `be4c8bab-4f4a-4587-bcf3-ea86dc18cfd1.png`. Depósito 300,00; beneficio neto 1.820,77; 77 operaciones.

[2] Captura aportada por el usuario como prueba nueva: `9cfde8c6-9e7b-41c9-a1b6-a2f461d523db.png`. Depósito 5.000,00; beneficio neto 1.029,43; 76 operaciones.

[3] [README técnico de v15: diferencias funcionales y estado de revisión](https://github.com/stevenvo780/YoinerValdez/blob/7af893a05785f64c27a6338f50f9acbef6ae215f/mql5/README.md).

[4] [Auditoría del repositorio: cambios y límites de la validación](https://github.com/stevenvo780/YoinerValdez/blob/7af893a05785f64c27a6338f50f9acbef6ae215f/docs/AUDITORIA_v14.md).

Las referencias al repositorio están fijadas al commit `7af893a05785f64c27a6338f50f9acbef6ae215f`. Se utilizan para describir los cambios y el alcance de sus pruebas, no para adoptar sin revisión todas las conclusiones del informe original.
