# infrastructure/loaders.py

import pandas as pd
from pathlib import Path


def load_file(path):

    ext = Path(path).suffix.lower()

    if ext == ".csv":
        return pd.read_csv(
            path,
            sep=";",
            dtype=str,
            low_memory=False,
            encoding="utf-8"  # 🔥 FIJO
        )

    if ext in [".xlsx", ".xls"]:
        return pd.read_excel(path, dtype=str)

    raise ValueError("Formato no soportado")