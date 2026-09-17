import datetime as dt
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ohlc_quant.data.dukascopy import download_range_candles

start = dt.date.fromisoformat(sys.argv[1]); end = dt.date.fromisoformat(sys.argv[2])
workers = int(sys.argv[3]) if len(sys.argv) > 3 else 2
out = Path(__file__).resolve().parents[1] / "data" / "bars"
files = download_range_candles("XAUUSD", start, end, out, workers=workers)
print(f"listo: {len(files)} días en {out}", flush=True)
