# infrastructure/corrupt_exporter.py

import json
from datetime import datetime


def export_corruptas(df):

    if df.empty:
        return

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    path_json = f"output/corruptas_{timestamp}.json"
    path_csv = f"output/corruptas_{timestamp}.csv"

    # JSON
    with open(path_json, "w", encoding="utf-8") as f:
        json.dump(
            df.to_dict(orient="records"),
            f,
            ensure_ascii=False,
            indent=2,
            default=str
        )

    # CSV
    df.to_csv(path_csv, sep=";", index=False)

    print(f"\n🚨 Filas corruptas detectadas: {len(df)}")
    print(f"📁 JSON: {path_json}")
    print(f"📁 CSV: {path_csv}\n")


def export_avisos(df):

    if df.empty:
        return

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    path_csv = f"output/avisos_{timestamp}.csv"

    df.to_csv(path_csv, sep=";", index=False)

    print(f"\n⚠️ Avisos (no excluyen datos): {len(df)}")
    for aviso, total in df["AVISO"].value_counts().items():
        print(total, aviso)
    print(f"📁 CSV: {path_csv}\n")
