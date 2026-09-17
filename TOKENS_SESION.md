# Consumo de tokens de la sesión (2026-09-17)

Estimación hecha a partir de los contadores de contexto visibles durante la sesión (presupuesto de 15.000.000 tokens por turno; el consumo de un turno es la diferencia entre ese presupuesto y el valor al final del turno) y de los informes de uso de los subagentes.

No son datos exactos de facturación; la cifra real puede diferir aproximadamente en ±10 %.

| Turno / tarea                                                              |               Tokens (aprox.) |
| -------------------------------------------------------------------------- | ----------------------------: |
| 1. Auditoría del EA v14.0, build v14.1, informe y herramientas             |                       237.000 |
| 2. Proyecto Python `ohlc_quant`, descarga de datos, tests y simulaciones   |                       169.000 |
| 3. Reestructuración en EA modular v15 y renombrado de scripts              |                        66.000 |
| 4-5. Respuestas sobre uso de CPU y GPU                                     |                         6.000 |
| 6-8. Procesamiento de resultados parciales, revisiones de Codex y descarga |                        83.000 |
| 9. Validación final, correcciones al EA y documento de resultados          |                        66.000 |
| 10. Compilación con MetaEditor/Wine, README, repositorio e informe         |                        30.000 |
| **Sesión principal (Claude Fable 5.1)**                                    |                 **≈ 657.000** |
| Subagente Codex: revisión adversarial del build v14.1                      |                       125.800 |
| Subagente Codex: tests adversariales del proyecto Python                   |                       105.968 |
| Subagente Codex: revisión del EA modular, ronda 1                          |                       101.750 |
| Subagente Codex: revisión del EA modular, ronda 2                          |                       102.677 |
| **Subagentes**                                                             |                 **≈ 436.000** |
| **Total estimado de trabajo**                                              | **≈ 1,09 millones de tokens** |

## Datos reportados por la sesión

| Métrica                      |           Valor |
| ---------------------------- | --------------: |
| **Costo total de la sesión** |   **USD 42,87** |
| Duración de API              | 1 h 32 min 11 s |
| Duración total de la sesión  |    ≈ 2 h 27 min |
| Líneas agregadas             |           1.134 |
| Líneas eliminadas            |             399 |
| Solicitudes con prompt cache |             109 |
| Input servido desde cache    |            99 % |

## Uso por modelo

| Modelo           | Input | Output |             Cache read |             Cache write |         Costo |
| ---------------- | ----: | -----: | ---------------------: | ----------------------: | ------------: |
| Claude Haiku 4.5 | 21,1k | 133,2k |                   8,2M |                  587,6k |      USD 2,24 |
| Claude Fable 5.1 |  4,3k | 378,9k |                  42,9M |                  546,0k |     USD 40,62 |
| **Total**        |       |        | **≈ 51,1M cache read** | **≈ 1,13M cache write** | **USD 42,87** |

### Observaciones de uso

* El **99 % del input** de las 109 solicitudes fue atendido desde prompt cache.
* La sesión se mantuvo con cache **warm**, sin misses visibles en el reporte.
* El panel indicó que **91 % del uso** se produjo con contextos superiores a **150.000 tokens**.
* La sesión tuvo un patrón intensivo en subagentes.
* El consumo interno de GPT-5.6 dentro de los subagentes Codex no aparece desglosado en estos contadores, por lo que el total de **≈ 1,09 millones de tokens** sigue siendo una estimación del trabajo visible.

## Notas

* Las tres pasadas de Codex sobre código MQL5 detectaron **1 mejora menor** y **9 correcciones aplicadas**; **11 hallazgos** se descartaron.
* El coste computacional no incluido en el costo de IA fue de aproximadamente **3 h de máquina con 32 núcleos**, incluyendo descarga de datos, cerca de **30.000 backtests** en mallas y walk-forward, **20.000 corridas de Monte Carlo por escenario** y **352 caminos sintéticos**.

## Valor a cobrar

Costo total reportado de la sesión:

**USD 42,87**

Se cobrará únicamente el **50 %** del costo:

**USD 21,44**
