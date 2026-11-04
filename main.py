from app.infrastructure.loaders import load_file
from app.infrastructure.corrupt_exporter import export_avisos, export_corruptas
from app.infrastructure.database import crear_engine
from app.infrastructure.repositories import cargar_tablas, leer_territorio

from app.utils.dataframe_utils import (
    clean_columns,
    convertir_numericos,
    limpiar_nombres,
    normalize_nulls
)

from app.application.etl_pipeline import run_reconstruccion, run_tablas

from app.domain.validators import detectar_avisos, detectar_filas_corruptas

from app.config.settings import INPUT_FILE, SOLO_VALIDAR


def main():

    print("Leyendo archivo...")
    df = load_file(INPUT_FILE)

    print("\n--- VALIDACIÓN DE LECTURA ---")
    print(df.iloc[0]["cod_mpio"], len(df), "filas", len(df.columns), "columnas")

    # 🔥 LIMPIEZA BASE
    print("Limpiando columnas...")
    df = clean_columns(df)

    print("Normalizando nulls...")
    df = normalize_nulls(df)

    # 🔥 Número de fila en el Excel: fila 1 son los títulos
    df["FILA_EXCEL"] = df.index + 2

    print("Convirtiendo tipos...")
    df = convertir_numericos(df)
    df = limpiar_nombres(df)

    print("Reconstruyendo hogares, viviendas y orden de personas...")
    df, stats = run_reconstruccion(df)

    print("\nResumen de reconstrucción:")
    for k, v in stats.items():
        print(k, v)

    print("\nDetectando filas corruptas...")
    df, df_corruptas = detectar_filas_corruptas(df)

    export_corruptas(df_corruptas)

    print("Detectando avisos...")
    export_avisos(detectar_avisos(df))

    print("Conectando a la base de datos...")

    if SOLO_VALIDAR:
        engine = None
        existentes = {"corregimiento": {}, "vereda": {}, "barrio": {}}
    else:
        engine = crear_engine()
        existentes = leer_territorio(engine)

    print("Girando grupos repetidos...")
    tablas, codigos = run_tablas(df, existentes)

    print("\nFilas por tabla:")
    for tabla, datos in tablas.items():
        print(tabla, len(datos))

    if SOLO_VALIDAR:
        print("\nSOLO_VALIDAR activo: no se tocó la base de datos")
    else:
        print("\nInsertando en la base de datos...")
        cargar_tablas(engine, tablas, codigos)

    print("ETL finalizado")


if __name__ == "__main__":
    main()
