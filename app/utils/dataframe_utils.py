# utils/dataframe_utils.py

from decimal import Decimal, InvalidOperation

import numpy as np
import pandas as pd

from app.config.settings import COLUMNAS_TEXTO


def clean_columns(df):

    df.columns = (
        df.columns
        .str.strip()
        .str.replace(" ", "_")
        .str.upper()
    )

    return df


def normalize_nulls(df):

    null_values = ["", " ", "NULL", "None", "nan"]

    return df.replace(null_values, np.nan)


def texto_a_entero(valor):

    if pd.isna(valor):
        return None

    try:
        numero = Decimal(str(valor).strip())
    except InvalidOperation:
        return None

    if numero != int(numero):
        return None

    return int(numero)


def texto_a_decimal(valor):

    if pd.isna(valor):
        return None

    try:
        return Decimal(str(valor).strip())
    except InvalidOperation:
        return None


def convertir_numericos(df):

    columnas = [col for col in df.columns if col not in COLUMNAS_TEXTO]

    for col in columnas:

        # 🔥 Montos con Decimal: las sumas de pesos deben ser exactas
        funcion = texto_a_decimal if col.startswith("VLR_") else texto_a_entero

        df[col] = pd.Series(
            [funcion(valor) for valor in df[col].tolist()],
            index=df.index,
            dtype=object
        )

    return df.copy()


def limpiar_nombres(df):

    for col in ["NOM_CORREGIMIENTO", "NOM_VEREDA", "NOM_BARRIO"]:
        df[col] = df[col].str.strip()

    return df


def anular_valores(df, col, mask):

    valores = df[col].to_numpy(dtype=object, copy=True)
    valores[mask.to_numpy()] = None

    df[col] = pd.Series(valores, index=df.index, dtype=object)

    return df


def filas_para_insertar(df):

    columnas = [
        [None if pd.isna(valor) else valor for valor in df[col].tolist()]
        for col in df.columns
    ]

    return list(zip(*columnas))
