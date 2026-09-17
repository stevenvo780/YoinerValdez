#!/bin/bash
cd "$(dirname "$0")/.."
until curl -s -m 15 -o /dev/null -w "%{http_code}" -A "Mozilla/5.0" https://datafeed.dukascopy.com/datafeed/XAUUSD/2025/01/03/BID_candles_min_1.bi5 | grep -q "^200$"; do
  echo "$(date +%H:%M:%S) host aún bloqueado; reintento en 120 s" ; sleep 120
done
echo "$(date +%H:%M:%S) host responde; iniciando descarga de velas"
exec .venv/bin/python scripts/download_candles.py 2023-01-01 2026-09-12 2
