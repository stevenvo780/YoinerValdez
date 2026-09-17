from __future__ import annotations

import numpy as np
from numba import njit


@njit(cache=True)
def atr_wilder(h: np.ndarray, l: np.ndarray, c: np.ndarray, period: int) -> np.ndarray:
    n = len(h)
    out = np.full(n, np.nan)
    if n < period + 1:
        return out
    tr = np.empty(n)
    tr[0] = h[0] - l[0]
    for i in range(1, n):
        hl = h[i] - l[i]
        hc = abs(h[i] - c[i - 1])
        lc = abs(l[i] - c[i - 1])
        tr[i] = max(hl, max(hc, lc))
    s = 0.0
    for i in range(period):
        s += tr[i]
    out[period - 1] = s / period
    for i in range(period, n):
        out[i] = (out[i - 1] * (period - 1) + tr[i]) / period
    return out


@njit(cache=True)
def rolling_max_shifted(x: np.ndarray, window: int, shift: int) -> np.ndarray:
    n = len(x)
    out = np.full(n, np.nan)
    for i in range(n):
        end = i - shift
        start = end - window + 1
        if start < 0:
            continue
        m = x[start]
        for j in range(start + 1, end + 1):
            if x[j] > m:
                m = x[j]
        out[i] = m
    return out


@njit(cache=True)
def rolling_min_shifted(x: np.ndarray, window: int, shift: int) -> np.ndarray:
    n = len(x)
    out = np.full(n, np.nan)
    for i in range(n):
        end = i - shift
        start = end - window + 1
        if start < 0:
            continue
        m = x[start]
        for j in range(start + 1, end + 1):
            if x[j] < m:
                m = x[j]
        out[i] = m
    return out


@njit(cache=True)
def structure_trend(h: np.ndarray, l: np.ndarray, lookback: int, min_conf: int) -> np.ndarray:
    n = len(h)
    out = np.zeros(n, dtype=np.int8)
    if lookback < 6:
        return out
    seg = max(lookback // 3, 2)
    for i in range(n):
        if i + 1 < lookback + 5:
            continue
        e1 = i
        s1 = e1 - seg + 1
        e2 = s1 - 1
        s2 = e2 - seg + 1
        e3 = s2 - 1
        s3 = e3 - seg + 1
        if s3 < 0:
            continue
        h1 = h[s1]; l1 = l[s1]
        for j in range(s1 + 1, e1 + 1):
            if h[j] > h1: h1 = h[j]
            if l[j] < l1: l1 = l[j]
        h2 = h[s2]; l2 = l[s2]
        for j in range(s2 + 1, e2 + 1):
            if h[j] > h2: h2 = h[j]
            if l[j] < l2: l2 = l[j]
        h3 = h[s3]; l3 = l[s3]
        for j in range(s3 + 1, e3 + 1):
            if h[j] > h3: h3 = h[j]
            if l[j] < l3: l3 = l[j]
        bull = 0; bear = 0
        if h1 > h2 and l1 > l2: bull += 1
        if h2 > h3 and l2 > l3: bull += 1
        if h1 > h3 and l1 > l3: bull += 1
        if h1 < h2 and l1 < l2: bear += 1
        if h2 < h3 and l2 < l3: bear += 1
        if h1 < h3 and l1 < l3: bear += 1
        if bull >= min_conf and bull > bear:
            out[i] = 1
        elif bear >= min_conf and bear > bull:
            out[i] = -1
    return out
