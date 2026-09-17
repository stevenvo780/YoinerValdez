# Consumo de tokens de la sesión (2026-09-17)

Estimación hecha a partir de los contadores de contexto visibles durante la sesión (presupuesto de 15.000.000 tokens por turno; el
consumo de un turno es la diferencia entre ese presupuesto y el valor al final del turno) y de los informes de uso de los
subagentes. No son datos de facturación; la cifra real puede diferir en ±10 %.

| Turno / tarea | Tokens (aprox.) |
|---|---|
| 1. Auditoría del EA v14.0, build v14.1, informe y herramientas | 237.000 |
| 2. Proyecto Python `ohlc_quant`, descarga de datos, tests, simulaciones | 169.000 |
| 3. Reestructuración en EA modular v15 y renombrado de scripts | 66.000 |
| 4-5. Respuestas sobre uso de CPU y GPU | 6.000 |
| 6-8. Procesamiento de resultados parciales, revisiones de Codex y descarga | 83.000 |
| 9. Validación final, correcciones al EA y documento de resultados | 66.000 |
| 10. Compilación con MetaEditor/Wine, README, repositorio, este informe | 30.000 |
| **Sesión principal (Claude Fable 5.1)** | **≈ 657.000** |
| Subagente Codex: revisión adversarial del build v14.1 | 125.800 |
| Subagente Codex: tests adversariales del proyecto Python | 105.968 |
| Subagente Codex: revisión del EA modular, ronda 1 | 101.750 |
| Subagente Codex: revisión del EA modular, ronda 2 | 102.677 |
| **Subagentes (tokens del envoltorio Claude; el consumo interno de GPT-5.6 no es visible)** | **≈ 436.000** |
| **Total estimado** | **≈ 1.09 millones de tokens** |

Notas:
- Las tres pasadas de Codex sobre código MQL5 detectaron 1 mejora menor y 9 correcciones aplicadas; 11 hallazgos se descartaron.
- El coste computacional no incluido aquí: 3 h de máquina (32 núcleos) en descarga de datos, ~30.000 backtests en mallas y
  walk-forward, 20.000 corridas de Monte Carlo por escenario y 352 caminos sintéticos.
