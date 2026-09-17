import datetime as dt
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ohlc_quant.data.dukascopy import download_range

start = dt.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else dt.date(2023, 1, 1)
end = dt.date.fromisoformat(sys.argv[2]) if len(sys.argv) > 2 else dt.date(2026, 9, 12)
out = Path(__file__).resolve().parents[1] / "data" / "bars"
files = download_range("XAUUSD", start, end, out, workers=int(sys.argv[3]) if len(sys.argv) > 3 else 4)
print(f"listo: {len(files)} días en {out}")
