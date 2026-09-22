"""Genera el experto v16 de un solo archivo y lo copia a la entrega del cliente."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAIN = ROOT / "Experts/OHLCMTF/OHLCMTF_Scalper.mq5"
OUT = ROOT / "OHLCMTF_Scalper_v16_single.mq5"
CLIENT = ROOT.parent / "ENTREGA_CLIENTE" / "OHLCMTF_Scalper_v16.mq5"
seen: set[str] = set()


def expand(path: Path) -> str:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*#include\s+<OHLCMTF/(\w+\.mqh)>', line)
        if m:
            name = m.group(1)
            if name not in seen:
                seen.add(name)
                out.append(f"//==================== {name} ====================")
                out.append(expand(ROOT / "Include/OHLCMTF" / name))
            continue
        if re.match(r'\s*#(ifndef|define|endif)\s+OHLCMTF_\w+_MQH', line) or re.match(r'\s*#endif\s*$', line) and False:
            continue
        out.append(line)
    return "\n".join(out)


text = expand(MAIN)
text = re.sub(r'^#endif\s*$', '', text, flags=re.M)
header = ("//+------------------------------------------------------------------+\n"
          "//| OHLCMTF_Scalper_v16.mq5 — ARCHIVO ÚNICO generado                  |\n"
          "//| a partir de Experts/OHLCMTF + Include/OHLCMTF (no editar a mano;  |\n"
          "//| regenerar con build_single_file.py). Misma lógica que el modular. |\n"
          "//| Identificación: OHLCMTF SCALPER v16                               |\n"
          "//+------------------------------------------------------------------+\n")
payload = header + text
OUT.write_text(payload, encoding="utf-8")
CLIENT.parent.mkdir(parents=True, exist_ok=True)
CLIENT.write_text(payload, encoding="utf-8")
print(f"{OUT.name}: {len(text.splitlines())} líneas, módulos: {sorted(seen)}")
print(f"entrega: {CLIENT}")
