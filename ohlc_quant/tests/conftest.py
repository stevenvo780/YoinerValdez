import numpy as np
import pandas as pd
import pytest

from ohlc_quant.data.bars import build_market
from ohlc_quant.data.synthetic import synthetic_m1
from ohlc_quant.engine.params import BrokerSpec, ServerClock


@pytest.fixture(scope="session")
def m1_syn():
    return synthetic_m1(days=120, seed=11)


@pytest.fixture(scope="session")
def md_syn(m1_syn):
    return build_market(m1_syn, ServerClock(2, "us"))


@pytest.fixture
def broker():
    return BrokerSpec()


def make_m1(prices, start="2024-03-04 08:00", spread=0.3, freq="1min"):
    prices = np.asarray(prices, dtype=float)
    idx = pd.date_range(start, periods=len(prices), freq=freq)
    o = prices
    c = np.concatenate([prices[1:], prices[-1:]])
    h = np.maximum(o, c) + 0.05
    l = np.minimum(o, c) - 0.05
    return pd.DataFrame({"open": o, "high": h, "low": l, "close": c, "ask_open": o + spread, "ask_close": c + spread,
                         "spread_mean": spread, "spread_max": spread, "ticks": 10}, index=idx)
