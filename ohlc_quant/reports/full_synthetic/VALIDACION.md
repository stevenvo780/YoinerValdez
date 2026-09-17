# Validación cuantitativa OHLCMTF SCALPER v14 sobre XAUUSD (ticks Dukascopy)
Datos: 2024-01-01 00:00:00+00:00 → 2025-02-23 23:59:00+00:00 UTC · 432,000 velas M1 · 419 días · hora servidor UTC+2/+3 (DST US)

## 1. Backtests base
- v140_$300: señales=217 stats={'skip_minlot': 0, 'skip_spread': 0, 'skip_pause': 0, 'skip_daily': 11, 'skip_dd': 0, 'skip_cooldown': 0, 'skip_maxday': 0, 'skip_busy': 90, 'dd_latches': 0, 'pp_mods': 155, 'skip_high_spread': 0, 'skip_margin': 0, 'signals': 217}
- v141_$300: señales=219 stats={'skip_minlot': 182, 'skip_spread': 0, 'skip_pause': 0, 'skip_daily': 0, 'skip_dd': 0, 'skip_cooldown': 0, 'skip_maxday': 0, 'skip_busy': 10, 'dd_latches': 0, 'pp_mods': 48, 'skip_high_spread': 0, 'skip_margin': 0, 'signals': 219}
- v141_$3000: señales=219 stats={'skip_minlot': 0, 'skip_spread': 0, 'skip_pause': 0, 'skip_daily': 0, 'skip_dd': 0, 'skip_cooldown': 0, 'skip_maxday': 0, 'skip_busy': 101, 'dd_latches': 0, 'pp_mods': 158, 'skip_high_spread': 0, 'skip_margin': 0, 'signals': 219}
- lean_$3000: señales=68 stats={'skip_minlot': 0, 'skip_spread': 0, 'skip_pause': 0, 'skip_daily': 0, 'skip_dd': 0, 'skip_cooldown': 0, 'skip_maxday': 0, 'skip_busy': 15, 'dd_latches': 0, 'pp_mods': 99, 'skip_high_spread': 0, 'skip_margin': 0, 'signals': 68}
- v141_$3000_solo_fijo: señales=68 stats={'skip_minlot': 0, 'skip_spread': 0, 'skip_pause': 0, 'skip_daily': 0, 'skip_dd': 0, 'skip_cooldown': 0, 'skip_maxday': 0, 'skip_busy': 15, 'dd_latches': 0, 'pp_mods': 99, 'skip_high_spread': 0, 'skip_margin': 0, 'signals': 68}
- v141_$3000_solo_custom: señales=151 stats={'skip_minlot': 0, 'skip_spread': 0, 'skip_pause': 0, 'skip_daily': 0, 'skip_dd': 0, 'skip_cooldown': 0, 'skip_maxday': 0, 'skip_busy': 52, 'dd_latches': 0, 'pp_mods': 123, 'skip_high_spread': 0, 'skip_margin': 0, 'signals': 151}
```
                            n    net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct
v140_$300              116.00  -5.11           1.00     43.10       -0.04       57.41             7.00            -0.03   0.01       -1.70          7.94         27.46
v141_$300               27.00  38.79           1.56     51.85        1.44        8.11             3.00             1.52   0.24       12.93          2.15          2.49
v141_$3000             118.00 -71.64           0.95     43.22       -0.61        7.19             8.00            -0.32   0.00       -2.39          0.81          2.03
lean_$3000              53.00 178.11           1.24     45.28        3.36        6.51             8.00             0.84   0.06        5.94          0.88          1.89
v141_$3000_solo_fijo    53.00 164.56           1.22     45.28        3.10        6.16             8.00             0.82   0.06        5.49          0.88          1.89
v141_$3000_solo_custom  99.00  29.21           1.03     44.44        0.30        9.62             7.00             0.10   0.00        0.97          0.80          2.08
```

## 2. Riesgo real por operación y capital necesario
- v140_$300: {"n_perdedoras": 66, "riesgo_real_mediana_pct": 6.819932535699509, "riesgo_real_p90_pct": 12.732433560655451, "riesgo_real_max_pct": 24.586387340720865, "volumenes": [0.01]}
- v141_$3000: {"n_perdedoras": 67, "riesgo_real_mediana_pct": 0.8158514739560129, "riesgo_real_p90_pct": 1.4586358260146899, "riesgo_real_max_pct": 2.0305740140869015, "volumenes": [0.01, 0.02, 0.03]}
```
  atr_quantil   atr  sl_dist  riesgo_minlot_$  capital_0.5%  capital_1.0%  capital_1.25%  capital_2.5%
0         p10  3.65     6.57             6.57       1313.81        656.90         525.52        262.76
1         p25  4.17     7.50             7.50       1500.62        750.31         600.25        300.12
2         p50  9.67    17.41            17.41       3482.20       1741.10        1392.88        696.44
3         p75 14.63    26.34            26.34       5267.90       2633.95        2107.16       1053.58
4         p90 19.04    34.27            34.27       6853.62       3426.81        2741.45       1370.72
```
Barrido de depósito (v141):
```
            n     net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct  skip_minlot
$300    27.00   38.79           1.56     51.85        1.44        8.11             3.00             1.52   0.24       12.93          2.15          2.49          182
$500    46.00   11.39           1.07     45.65        0.25        7.43             5.00             0.28   0.08        2.28          1.64          2.41          144
$1000   58.00  -49.49           0.85     41.38       -0.85       13.32             8.00            -0.35   0.00       -4.95          1.09          2.35          126
$2000  113.00   73.16           1.06     44.25        0.65        9.23             8.00             0.35   0.02        3.66          1.06          2.44           10
$5000  118.00 -112.63           0.93     43.22       -0.95        5.03             8.00            -0.44   0.00       -2.25          0.52          1.22            0
$10000 118.00 -189.62           0.90     43.22       -1.61        4.58             8.00            -0.41   0.00       -1.90          0.33          1.23            0
```

## 3. Distribución temporal (v141 $3000)
Por mes:
```
             n    net
open_time            
2024-01-31   9 -79.39
2024-02-29   7  31.95
2024-03-31   7 -74.39
2024-04-30  16 138.41
2024-05-31  10 -66.81
2024-06-30   5 -13.48
2024-07-31   9   0.44
2024-08-31   5   9.23
2024-09-30  10   4.94
2024-10-31   8  21.49
2024-11-30  11   3.19
2024-12-31   4  81.94
2025-01-31   9 -60.12
2025-02-28   8 -69.05
```
Por día de la semana:
```
      n     net
Lun  28   29.37
Mar  28  -98.49
Mié  21   24.58
Jue  19 -119.98
Vie  22   92.89
```
Exclusiones:
```
                            n     net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct
todo                   118.00  -71.64           0.95     43.22       -0.61        5.67             8.00            -0.42   0.00       -2.39          0.81          2.03
sin_mejor_mes(2024-04) 102.00 -210.04           0.82     42.16       -2.06        8.72             8.00            -0.80  -0.04       -7.00          0.75          2.03
sin_mejor_dia(Vie)      96.00 -164.53           0.86     42.71       -1.71       10.66             8.00            -0.51  -0.01       -5.48          0.79          2.03
sin_ambos               83.00 -338.74           0.65     40.96       -4.08       12.13             8.00            -0.92  -0.07      -11.29          0.73          2.03
sin_top5               113.00 -439.80           0.70     40.71       -3.89       15.68             8.00            -0.93  -0.07      -14.66          0.78          2.03
sin_peor_mes(2024-01)  109.00    7.75           1.01     44.95        0.07        5.16             6.00             0.05   0.04        0.26          0.82          2.03
```
Por set:
```
        count     sum  mean
set                        
CUSTOM     90   67.99  0.76
FIJO       28 -139.62 -4.99
```
Por salida:
```
      count      sum   mean
exit                       
SL       84 -1431.04 -17.04
TP       34  1359.40  39.98
```
Por fuerza de señal:
```
          count     sum   mean
strength                      
4            40  -42.59  -1.06
5            57  183.21   3.21
6            21 -212.26 -10.11
```

## 4. Monte Carlo sobre las operaciones (v141 $3000 y v140 $300)
v141_$3000:
```
        mode    sizing   runs    k  dd_p50  dd_p95  dd_p99  p_dd_ge_12  p_dd_ge_20  p_dd_ge_30  p_ruin_50  streak_p95  streak_p99  final_p05  final_p50  final_p95  p_net_negative  median_loss_pct
0    shuffle  tal_cual  20000 1.00   12.05   17.44   19.92       50.66        0.94        0.00       0.00       11.00       14.00    2928.36    2928.36    2928.36          100.00             0.63
1    shuffle  tal_cual  20000 1.00   12.05   17.44   19.92       50.66        0.94        0.00       0.00       11.00       14.00    2928.36    2928.36    2928.36          100.00             0.63
2  bootstrap  tal_cual  20000 1.00   12.49   23.34   28.31       53.75       11.95        0.54       0.00       12.00       14.01    2417.84    2924.56    3557.92           58.66             0.63
3  bootstrap  tal_cual  20000 1.00   12.49   23.34   28.31       53.75       11.95        0.54       0.00       12.00       14.01    2417.84    2924.56    3557.92           58.66             0.63
4      block  tal_cual  20000 1.00    9.71   17.67   21.60       29.40        1.99        0.00       0.00       12.00       15.00    2586.76    2960.61    3393.89           56.31             0.63
5      block  tal_cual  20000 1.00    9.71   17.67   21.60       29.40        1.99        0.00       0.00       12.00       15.00    2586.76    2960.61    3393.89           56.31             0.63
```
v140_$300:
```
        mode        sizing   runs    k  dd_p50  dd_p95  dd_p99  p_dd_ge_12  p_dd_ge_20  p_dd_ge_30  p_ruin_50  streak_p95  streak_p99  final_p05  final_p50  final_p95  p_net_negative  median_loss_pct
0    shuffle      tal_cual  20000 1.00   70.89   84.67   88.60      100.00      100.00      100.00      47.38       11.00       14.00     294.89     294.89     294.89          100.00             5.05
1    shuffle  mediana=1.0%  20000 0.20   18.88   27.95   31.95       97.25       40.62        2.38       0.00       11.00       14.00     337.91     337.91     337.91            0.00             5.05
2  bootstrap      tal_cual  20000 1.00   72.23   92.64   96.15      100.00      100.00       99.94      54.68       12.00       15.00      38.73     286.45    2232.45           51.52             5.05
3  bootstrap  mediana=1.0%  20000 0.20   19.41   35.73   43.30       89.94       46.94       12.90       0.10       12.00       15.00     223.43     335.65     513.28           32.91             5.05
4      block      tal_cual  20000 1.00   60.76   83.77   89.75      100.00      100.00       99.76      39.00       11.00       13.00      81.38     318.55    1332.09           46.97             5.05
5      block  mediana=1.0%  20000 0.20   14.11   24.73   30.50       68.44       15.92        1.17       0.00       11.00       13.00     259.01     342.74     466.76           22.17             5.05
```

## 5. Partición temporal 70/30 (malla en IS, una sola evaluación OOS)
IS 2024-01-01 02:00:00 → 2024-10-21 01:59:18; OOS 2024-10-21 01:59:18 → 2025-02-24 02:00:00
```
    structure_lookback  atr_sl_mult   n    net  profit_factor  expectancy  max_dd_pct
1                    8         1.60  42 246.42           1.50        5.87        4.70
6                   10         1.60  41 233.43           1.47        5.69        5.09
11                  12         1.60  39 181.99           1.38        4.67        4.80
16                  14         1.60  39 179.72           1.37        4.61        4.80
21                  16         1.60  39 179.72           1.37        4.61        4.80
2                    8         1.80  41 157.99           1.26        3.85        5.38
7                   10         1.80  39 126.72           1.21        3.25        6.21
10                  12         1.40  40 122.56           1.28        3.06        4.69
20                  16         1.40  40 120.29           1.27        3.01        4.69
15                  14         1.40  40 120.29           1.27        3.01        4.69
```
```
                 n    net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct
OOS_mejor_IS 15.00 140.40           2.22     60.00        9.36        2.51             2.00             1.73   0.27        4.68          0.85          1.31
OOS_defaults 15.00  65.11           1.37     53.33        4.34        2.91             2.00             0.73   0.01        2.17          0.97          1.51
```

## 6. Walk-forward rodante (IS 6m / OOS 2m / paso 2m, preset LEAN $3000)
```
     is_start      is_end     oos_end  p:structure_lookback  p:atr_sl_mult  is_n  is_pf  is_exp  oos_n  oos_pf  oos_exp  oos_net  oos_dd_pct  efficiency
0  2024-01-01  2024-07-01  2024-09-01                     8           1.60    28   1.86   11.07      9    0.18    -9.50   -85.49        3.38       -0.86
1  2024-03-01  2024-09-01  2024-11-01                     8           1.60    28   1.38    5.52      7    3.96     6.78    47.47        1.04        1.23
2  2024-05-01  2024-11-01  2025-01-01                     8           1.60    22   1.09    0.77      6   21.50    28.73   172.38        1.70       37.16
```
```
{
  "ventanas": 3,
  "eficiencia_media": 12.509238054265197,
  "pct_ventanas_eff>=0.5": 66.66666666666666,
  "pct_ventanas_oos_positivas": 66.66666666666666,
  "oos_neto_total": 134.36050074767127,
  "oos_trades": 22,
  "oos_pf_concatenado": 2.0477555502658666,
  "estabilidad_params": {
    "structure_lookback": {
      "distintos": 1,
      "moda": 8
    },
    "atr_sl_mult": {
      "distintos": 1,
      "moda": 1.6
    }
  }
}
```
Walk-forward anclado:
```
{
  "ventanas": 3,
  "eficiencia_media": 1.7882834337416096,
  "pct_ventanas_eff>=0.5": 66.66666666666666,
  "pct_ventanas_oos_positivas": 66.66666666666666,
  "oos_neto_total": 134.36050074767127,
  "oos_trades": 22,
  "oos_pf_concatenado": 2.0477555502658666,
  "estabilidad_params": {
    "structure_lookback": {
      "distintos": 1,
      "moda": 8
    },
    "atr_sl_mult": {
      "distintos": 1,
      "moda": 1.6
    }
  }
}
```

## 7. Sensibilidad ±10/20 % (LEAN $3000)
```
                     param  delta  valor   n     net   pf  expectancy  max_dd_pct  exp_vs_base_pct
0                     base    NaN    NaN  53  178.11 1.24        3.36        6.51             0.00
1       structure_lookback  -0.20  10.00  54  203.60 1.26        3.77        6.21            12.20
2       structure_lookback  -0.10  11.00  53  178.11 1.24        3.36        6.51             0.00
3       structure_lookback   0.10  13.00  53  175.83 1.23        3.32        6.51            -1.30
4       structure_lookback   0.20  14.00  53  175.83 1.23        3.32        6.51            -1.30
5    min_breakout_atr_mult  -0.20   0.22  55  242.61 1.34        4.41        6.57            31.30
6    min_breakout_atr_mult  -0.10   0.25  55  230.84 1.32        4.20        6.57            24.90
7    min_breakout_atr_mult   0.10   0.31  52   79.06 1.10        1.52        6.39           -54.80
8    min_breakout_atr_mult   0.20   0.34  52   79.30 1.11        1.53        6.38           -54.60
9           min_body_ratio  -0.20   0.44  56  224.34 1.30        4.01        6.16            19.20
10          min_body_ratio  -0.10   0.50  54  198.65 1.26        3.68        6.16             9.50
11          min_body_ratio   0.10   0.61  52  154.73 1.20        2.98        6.37           -11.50
12          min_body_ratio   0.20   0.66  45  287.51 1.46        6.39        5.42            90.10
13  max_against_wick_ratio  -0.20   0.28  49  128.69 1.18        2.63        6.51           -21.80
14  max_against_wick_ratio  -0.10   0.32  52  187.57 1.25        3.61        6.51             7.30
15  max_against_wick_ratio   0.10   0.39  54  164.82 1.22        3.05        6.54            -9.20
16  max_against_wick_ratio   0.20   0.42  56  132.25 1.17        2.36        6.53           -29.70
17             atr_sl_mult  -0.20   1.44  55  169.13 1.31        3.08        4.75            -8.50
18             atr_sl_mult  -0.10   1.62  54  300.78 1.50        5.57        4.86            65.70
19             atr_sl_mult   0.10   1.98  53   91.29 1.11        1.72        7.99           -48.70
20             atr_sl_mult   0.20   2.16  53   25.34 1.03        0.48        8.27           -85.80
21             atr_tp_mult  -0.20   2.56  54   28.93 1.04        0.54        7.35           -84.10
22             atr_tp_mult  -0.10   2.88  54  122.19 1.16        2.26        6.47           -32.70
23             atr_tp_mult   0.10   3.52  51  281.17 1.40        5.51        6.03            64.10
24             atr_tp_mult   0.20   3.84  51  236.94 1.33        4.65        6.61            38.20
25          trend_lookback  -0.20  22.00  51 -134.22 0.84       -2.63       11.38          -178.30
26          trend_lookback  -0.10  25.00  51  138.11 1.18        2.71        6.82           -19.40
27          trend_lookback   0.10  31.00  50  289.57 1.43        5.79        5.18            72.30
28          trend_lookback   0.20  34.00  48  346.57 1.58        7.22        3.90           114.90
29             pp_stage2_r  -0.20   0.80  53  209.99 1.33        3.96        4.79            17.90
30             pp_stage2_r  -0.10   0.90  53  281.83 1.44        5.32        4.79            58.20
31             pp_stage2_r   0.10   1.10  53  195.37 1.26        3.69        6.48             9.70
32             pp_stage2_r   0.20   1.20  53  187.33 1.25        3.53        6.49             5.20
33        pp_trail_start_r  -0.20   1.76  53  178.11 1.24        3.36        6.51             0.00
34        pp_trail_start_r  -0.10   1.98  53  178.11 1.24        3.36        6.51             0.00
35        pp_trail_start_r   0.10   2.42  53  178.11 1.24        3.36        6.51             0.00
36        pp_trail_start_r   0.20   2.64  53  178.11 1.24        3.36        6.51             0.00
37      session_start_hour  -0.20   6.00  54  148.01 1.19        2.74        6.53           -18.40
38      session_start_hour  -0.10   6.00  54  148.01 1.19        2.74        6.53           -18.40
39      session_start_hour   0.10   8.00  50  143.41 1.20        2.87        6.27           -14.60
40      session_start_hour   0.20   8.00  50  143.41 1.20        2.87        6.27           -14.60
41        session_end_hour  -0.20  16.00  34   46.83 1.09        1.38        5.17           -59.00
42        session_end_hour  -0.10  18.00  48   88.44 1.13        1.84        6.22           -45.20
43        session_end_hour   0.10  22.00  59  160.26 1.20        2.72        8.84           -19.20
44        session_end_hour   0.20  24.00  64  199.93 1.24        3.12        7.77            -7.00
45     min_signal_strength  -0.20   3.00  52  235.69 1.33        4.53        6.07            34.90
46     min_signal_strength  -0.10   3.00  52  235.69 1.33        4.53        6.07            34.90
47     min_signal_strength   0.10   5.00  48  123.81 1.18        2.58        6.21           -23.20
48     min_signal_strength   0.20   5.00  48  123.81 1.18        2.58        6.21           -23.20
```
Malla structure_lookback × atr_sl_mult (expectancy), meseta=0.32
```
structure_lookback   8     10    12    14    16
atr_sl_mult                                    
1.4                3.50  3.08  2.81  2.77  2.77
1.6                6.79  6.64  5.71  5.67  5.67
1.8                4.23  3.77  3.36  3.32  3.32
2.0                2.49  1.97  1.59  1.55  1.55
2.2                0.41 -0.19 -0.24 -0.28 -0.28
```
Malla min_breakout_atr_mult × min_body_ratio (expectancy), meseta=0.56
```
min_breakout_atr_mult  0.15  0.20  0.28  0.35  0.45
min_body_ratio                                     
0.45                   4.60  4.60  4.01  1.69  2.05
0.50                   4.31  4.31  3.68  1.57  2.38
0.55                   4.41  4.41  3.36  1.53  2.44
0.60                   4.06  4.06  2.98  2.02  2.86
0.65                   6.52  7.42  5.90  4.67  4.52
```

## 8. Estrés de ejecución y de configuración (LEAN $3000)
```
                        n     net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct  exp_vs_base_pct
base                53.00  178.11           1.24     45.28        3.36        6.51             8.00             0.84   0.06        5.94          0.88          1.89             0.00
path_optimista      53.00  178.11           1.24     45.28        3.36        6.51             8.00             0.84   0.06        5.94          0.88          1.89             0.00
spread_x1.5         53.00  104.58           1.14     43.40        1.97        7.02             8.00             0.46   0.01        3.49          0.86          1.91           -41.30
spread_x2           53.00   87.67           1.12     43.40        1.65        7.03             8.00             0.39  -0.02        2.92          0.86          1.91           -50.80
spread_+20pts       53.00  105.10           1.15     43.40        1.98        7.02             8.00             0.47   0.01        3.50          0.86          1.91           -41.00
slippage_10pts      53.00  173.05           1.23     45.28        3.27        6.59             8.00             0.81   0.06        5.77          0.88          1.89            -2.80
slippage_30pts      53.00  137.93           1.18     32.08        2.60        7.51             8.00             0.57   0.03        4.60          0.89          1.89           -22.60
comision_7$/lot     53.00  173.35           1.23     45.28        3.27        6.57             8.00             0.81   0.06        5.78          0.88          1.89            -2.70
latencia_1min       54.00   70.84           1.09     42.59        1.31        7.88             8.00             0.28   0.01        2.36          0.91          1.91           -61.00
latencia_2min       54.00  151.71           1.21     44.44        2.81        5.52             8.00             0.85   0.00        5.06          0.87          1.90           -16.40
stops_level_30      53.00  178.11           1.24     45.28        3.36        6.51             8.00             0.84   0.06        5.94          0.88          1.89             0.00
sin_PP              52.00  -27.70           0.97     34.62       -0.53        8.43             7.00            -0.10  -0.06       -0.92          0.91          1.89          -115.90
solo_fijo           53.00  178.11           1.24     45.28        3.36        6.51             8.00             0.84   0.06        5.94          0.88          1.89             0.00
solo_custom          0.00    0.00           0.00      0.00        0.00        0.00             0.00             0.00   0.00        0.00          0.00          0.00          -100.00
sin_sesion          66.00  112.84           1.12     48.48        1.71        7.59             5.00             0.47   0.06        3.76          0.90          2.08           -49.10
sin_tendencia      113.00   35.00           1.02     45.13        0.31        9.28             7.00             0.12   0.04        1.17          0.89          2.24           -90.80
sin_mtf             74.00 -148.80           0.87     41.89       -2.01       12.84             7.00            -0.35  -0.11       -4.96          0.88          1.88          -159.80
cierre_viernes      52.00  186.09           1.27     46.15        3.58        4.92             8.00             1.20   0.04        6.20          0.89          1.95             6.50
reloj_UTC+0         58.00 -139.07           0.85     48.28       -2.40       12.06             4.00            -0.37  -0.05       -4.64          0.98          2.00          -171.30
reloj_UTC+2_sinDST  53.00  216.16           1.30     49.06        4.08        5.02             5.00             1.33   0.09        7.21          0.86          1.89            21.40
reloj_UTC+3_EU      53.00  178.11           1.24     45.28        3.36        6.51             8.00             0.84   0.06        5.94          0.88          1.89             0.00
```
Tipos de bróker:
```
                          n    net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct
raw_0.01lot_7$        53.00 173.35           1.23     45.28        3.27        6.57             8.00             0.81   0.06        5.78          0.88          1.89
std_0.01lot_spread+15 53.00 130.40           1.18     43.40        2.46        6.24             8.00             0.65   0.03        4.35          0.85          1.91
micro_0.001lot        53.00   1.24           1.00     45.28        0.02        4.56             8.00             0.01   0.06        0.04          0.40          0.75
cent_0.01lot_x100     53.00  13.23           1.05     45.28        0.25        2.66             8.00             0.16   0.06        0.44          0.34          0.58
```

## 9. Sensibilidad de sesión y del set custom (v141 $3000)
```
                   n    net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct
sesion_7-20   118.00 -71.64           0.95     43.22       -0.61        7.19             8.00            -0.32   0.00       -2.39          0.81          2.03
sesion_8-18    95.00 -59.48           0.95     40.00       -0.63        7.74             8.00            -0.24  -0.03       -1.98          0.75          1.83
sesion_9-17    83.00 124.02           1.14     43.37        1.49        5.98             6.00             0.62   0.04        4.13          0.72          1.78
sesion_13-20   86.00 129.07           1.12     47.67        1.50        7.31             4.00             0.58   0.09        4.30          0.83          2.02
sin_sesion    140.00 -82.06           0.95     44.29       -0.59        7.81             8.00            -0.34  -0.02       -2.74          0.85          2.24
custom_M15    126.00  69.68           1.04     42.86        0.55        9.34            10.00             0.24   0.04        2.32          0.85          1.99
custom_M30    116.00 618.38           1.49     50.00        5.33        6.10             5.00             2.93   0.13       20.61          0.77          2.05
trend_D1      120.00  93.82           1.06     45.83        0.78        8.18             7.00             0.38   0.04        3.13          0.80          2.08
min_str_5      87.00  38.34           1.03     41.38        0.44        7.03             8.00             0.17  -0.02        1.28          0.86          1.91
min_str_3     121.00 -32.97           0.98     42.98       -0.27        6.91             9.00            -0.15   0.00       -1.10          0.83          2.04
sin_expansion 134.00 154.11           1.10     44.03        1.15        8.13             8.00             0.60   0.02        5.14          0.79          1.97
```

## 10. Por año (v141 $3000, defaults)
```
          n     net  profit_factor  win_rate  expectancy  max_dd_pct  max_loss_streak  recovery_factor  avg_r  return_pct  avg_risk_pct  max_risk_pct
2024 101.00   57.53           1.05     45.54        0.57        7.19             8.00             0.26   0.05        1.92          0.77          2.03
2025  17.00 -129.16           0.56     29.41       -7.60        4.74             5.00            -0.91  -0.30       -4.31          1.06          1.25
```

## 11. Hipótesis nula: la misma estrategia sobre caminos sintéticos sin estructura (paseo aleatorio con regímenes de volatilidad)
- v140_$300 vs 96 caminos sintéticos de 365 días: expectancy real=-0.04 (percentil sintético 67), PF real=1.00 (percentil 67), neto sintético mediana=-239, P(neto>0)=32%
- v141_$3000 vs 96 caminos sintéticos de 365 días: expectancy real=-0.61 (percentil sintético 48), PF real=0.95 (percentil 47), neto sintético mediana=-53, P(neto>0)=44%

Tiempo total: 4s