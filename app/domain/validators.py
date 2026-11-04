# domain/validators.py

import re

import pandas as pd

from app.config.settings import (
    CATALOGOS,
    COLUMNAS_CALCULADAS,
    COLUMNAS_NULABLES,
    COLUMNAS_TEXTO,
    GRUPOS_DISCAPACIDAD,
    GRUPOS_EVENTO,
    GRUPOS_GASTO,
    GRUPOS_INGRESO,
    GRUPOS_RELACION,
    MUNICIPIOS,
    DEPARTAMENTOS,
    SIN_TERRITORIO
)

PATRON_CLASIFICACION = re.compile(
    r"^(A[1-5]|B[1-7]|C([1-9]|1[0-8])|D([1-9]|1[0-9]|2[01]))$"
)


def medir_cuadre_hogares(df):

    grupos = df.groupby("GRUPO_HOGAR").agg(
        filas=("FILA_EXCEL", "size"),
        personas=("NUM_PERSONAS_HOGAR", "first"),
        jefes=("TIP_PARENTESCO", lambda s: (s == 1).sum())
    )

    cuadran = (grupos["filas"] == grupos["personas"]) & (grupos["jefes"] == 1)

    return grupos, cuadran


def errores_vivienda(row):

    errores = []

    if row["COD_DPTO"] not in DEPARTAMENTOS:
        errores.append(f"departamento sin nombre: {row['COD_DPTO']}")

    if row["COD_MPIO"] not in MUNICIPIOS:
        errores.append(f"municipio sin nombre: {row['COD_MPIO']}")
    elif not row["COD_MPIO"].startswith(row["COD_DPTO"]):
        errores.append("ck_dimmunicipio_prefijo")

    if row["IND_TIENE_ENERGIA"] == 2 and row["TIP_ESTRATO_ENERGIA"] != 99:
        errores.append("ck_vivienda_estratoenergia_sinservicio")

    if row["IND_TIENE_ACUEDUCTO"] == 2 and row["TIP_ESTRATO_ACUEDUCTO"] != 99:
        errores.append("ck_vivienda_estratoacueducto_sinservicio")

    if row["NUM_CUARTOS_VIVIENDA"] < 1:
        errores.append("ck_vivienda_cuartos")

    if row["NUM_HOGARES_VIVIENDA"] < 1:
        errores.append("ck_vivienda_hogares")

    if row["COD_CLASE"] == 1 and row["NOM_BARRIO"] in SIN_TERRITORIO:
        errores.append("ck_vivienda_territorio_urbano")

    return errores


def errores_hogar(row):

    errores = []

    if not (
        row["NUM_CUARTOS_UNICOS_DORMIR"]
        <= row["NUM_CUARTOS_DORMIR"]
        <= row["NUM_CUARTOS_EXCLUSIVOS"]
    ):
        errores.append("ck_hogar_jerarquia_cuartos")

    if row["NUM_CUARTOS_EXCLUSIVOS"] > row["NUM_CUARTOS_VIVIENDA"]:
        errores.append("regla 4: más cuartos exclusivos que cuartos de la vivienda")

    if row["TIP_SANITARIO"] == 5 and (
        row["TIP_UBI_SANITARIO"] != 9 or row["TIP_USO_SANITARIO"] != 9
    ):
        errores.append("ck_hogar_sanitario_notiene")

    dias = row["NUM_DIAS_LLEGA"]

    if row["IND_AGUA_LLEGA_7DIAS"] == 2:
        if dias is None or not 0 <= dias <= 6:
            errores.append("ck_hogar_diasagua")
    elif dias is not None:
        errores.append("ck_hogar_diasagua")

    horas = row["NUM_HORAS_LLEGA"]

    if row["IND_AGUA_LLEGA_24HORAS"] == 2:
        if horas is None or not 0 <= horas <= 23:
            errores.append("ck_hogar_horasagua")
    elif horas is not None:
        errores.append("ck_hogar_horasagua")

    if row["NUM_PERSONAS_HOGAR"] < 1:
        errores.append("ck_hogar_personas")

    if row["VLR_TOTAL_GASTOS"] < 0:
        errores.append("ck_hogar_gastototal")

    if not PATRON_CLASIFICACION.match(str(row["CLASIFICACION"])):
        errores.append("ck_hogar_clasificacion")

    for _, indicador, valor in GRUPOS_GASTO:

        if row[indicador] == 1 and row[valor] <= 0:
            errores.append(f"regla 8: {indicador} = 1 sin valor")

        if row[indicador] != 1 and row[valor] != 0:
            errores.append("ck_hogargasto_valor")

    for _, indicador, conteo in GRUPOS_EVENTO:

        if row[indicador] == 1 and (row[conteo] is None or row[conteo] < 1):
            errores.append("ck_hogarevento_conteo")

        if row[indicador] == 2 and row[conteo] is not None:
            errores.append("ck_hogarevento_conteo")

    return errores


def errores_flujos(row):

    errores = []

    edad = row["EDAD_CALCULADA"]

    if not 0 <= edad <= 120:
        errores.append(f"ck_persona_edad: {edad}")

    if row["IND_ENFERMO_30"] == 2 and row["IND_ACUDIO_SALUD"] != 9:
        errores.append("ck_persona_flujo_salud")

    if row["IND_ACUDIO_SALUD"] != 1 and row["IND_FUE_ATENDIDO_SALUD"] != 9:
        errores.append("ck_persona_flujo_atendido")

    if not (row["SEXO_PERSONA"] == 2 and edad >= 8) and (
        row["IND_ESTA_EMBARAZADA"] != 9 or row["IND_TUVO_HIJOS"] != 9
    ):
        errores.append("ck_persona_flujo_mujer")

    if edad >= 5 and (
        row["TIP_CUIDADO_NIÑOS"] != 9 or row["IND_RECIBE_COMIDA"] != 9
    ):
        errores.append("ck_persona_flujo_primerainfancia")

    if edad < 5 and (
        row["IND_LEER_ESCRIBIR"] != 9
        or row["IND_ESTUDIA"] != 9
        or row["NIV_EDUCATIVO"] != 9
        or row["GRADO_ALCANZADO"] != 99
    ):
        errores.append("ck_persona_flujo_educacion")

    if edad < 14 and row["IND_FONDO_PENSIONES"] != 9:
        errores.append("ck_persona_flujo_pension")

    if edad < 8 and (
        row["TIP_ACTIVIDAD_MES"] != 9 or row["TIP_EMPLEADO"] != 99
    ):
        errores.append("ck_persona_flujo_trabajo")

    if row["TIP_ACTIVIDAD_MES"] != 2 and row["NUM_SEM_BUSCANDO"] != 999:
        errores.append("ck_persona_flujo_busqueda")

    if not row["NUM_SEM_BUSCANDO"] <= 999:
        errores.append("ck_persona_semanas")

    return errores


def errores_detalle(row, total_personas):

    errores = []

    otras = [
        row[indicador]
        for _, indicador in GRUPOS_DISCAPACIDAD
        if indicador != "IND_DISCAP_NINGUNA"
    ]

    if row["IND_DISCAP_NINGUNA"] == 1 and 1 in otras:
        errores.append("regla 13: declara ninguna y alguna limitación")

    if (row["IND_PARIENTE_DOMESTICO"] == 1) != (row["TIP_PARENTESCO"] in (16, 18)):
        errores.append("regla 12: indicador de pariente y parentesco no coinciden")

    for _, indicador, referencia in GRUPOS_RELACION:

        orden = row[referencia]

        if row[indicador] == 1 and orden is None:
            errores.append(f"ck_personarelacion_referencia: {indicador} = 1 sin número de orden")

        if row[indicador] != 1 and orden is not None:
            errores.append(f"ck_personarelacion_referencia: {referencia} sin indicador")

        if orden is not None and orden > total_personas:
            errores.append(f"regla 11: {referencia} apunta a una persona que no existe")

    for codigo, indicador, valor, meses in GRUPOS_INGRESO:

        if valor is None or codigo >= 10:
            continue

        if row[indicador] == 1 and row[valor] <= 0:
            errores.append(f"regla 20: {indicador} = 1 sin valor")

        if row[indicador] != 1 and row[valor] != 0:
            errores.append("ck_personaingreso_valor")

    if row["IND_INGR_COSECHA"] == 1 and not 1 <= row["NUM_MES_INGR_COSECHA"] <= 12:
        errores.append("regla 20: cosecha sin meses válidos")

    if not (0 <= row["NUM_MES_INGR_COSECHA"] <= 12 or row["NUM_MES_INGR_COSECHA"] == 99):
        errores.append("ck_personaingreso_meses")

    subsidios = (
        row["VLR_INGR_FAM_ACCION"]
        + row["VLR_INGR_COL_MAYOR"]
        + row["VLR_INGR_OTRO_SUBSIDIO"]
    )

    if row["IND_INGR_ESTADO"] == 1 and subsidios <= 0:
        errores.append("regla 21: subsidio sin valor")

    if row["IND_INGR_ESTADO"] != 1 and subsidios != 0:
        errores.append("ck_personaingreso_valor")

    return errores


def detectar_filas_corruptas(df):

    grupos, cuadran = medir_cuadre_hogares(df)

    hogares_malos = grupos[~cuadran]

    columnas_obligatorias = [
        col for col in df.columns
        if col not in COLUMNAS_TEXTO
        and col not in COLUMNAS_NULABLES
        and col not in COLUMNAS_CALCULADAS
    ]

    motivos = {}

    def fila_corrupta(row):

        errores = []

        # 1. columnas obligatorias: sin ellas no se puede seguir revisando
        for col in columnas_obligatorias:
            if row[col] is None:
                errores.append(f"{col} vacía o no numérica")

        if not errores:

            # 2. catálogos
            for col, valores in CATALOGOS.items():
                if row[col] not in valores:
                    errores.append(f"{col} fuera de catálogo: {row[col]}")

            # 3. consistencia, misma lógica de los CHECK
            errores += errores_vivienda(row)
            errores += errores_hogar(row)
            errores += errores_flujos(row)

            total = grupos.at[row["GRUPO_HOGAR"], "filas"]
            errores += errores_detalle(row, total)

        # 4. hogar que no cuadra
        if row["GRUPO_HOGAR"] in hogares_malos.index:
            g = hogares_malos.loc[row["GRUPO_HOGAR"]]
            errores.append(
                f"regla 10: {g['filas']} filas, {g['personas']} declaradas, "
                f"{g['jefes']} jefes"
            )

        if row["ESTADO_ORDEN"] == "imposible":
            errores.append("regla 11: referencias contradictorias entre personas")

        # 🔥 El motivo se guarda aparte: apply trabaja sobre una copia de la fila
        if errores:
            motivos[row.name] = ", ".join(dict.fromkeys(errores))
            return True

        return False

    mask_corruptas = df.apply(fila_corrupta, axis=1)

    # 🔥 Se aparta el hogar completo, no solo la persona
    grupos_malos = df.loc[mask_corruptas, "GRUPO_HOGAR"].unique()
    mask_hogar = df["GRUPO_HOGAR"].isin(grupos_malos)

    df_validas = df[~mask_hogar].copy()

    df_corruptas = df.loc[
        mask_hogar,
        ["FILA_EXCEL", "IDHOGAR", "IDVIVIENDA"]
    ].copy()

    df_corruptas["__errores__"] = pd.Series(motivos, dtype=object).reindex(
        df_corruptas.index
    )

    df_corruptas["__errores__"] = df_corruptas["__errores__"].fillna(
        "hogar excluido por error en otra persona"
    )

    return df_validas, df_corruptas


def detectar_avisos(df):

    def filas(mask, aviso):
        parte = df.loc[mask, ["FILA_EXCEL", "IDHOGAR"]].copy()
        parte["AVISO"] = aviso
        return parte

    def un_registro_por_hogar(mask):
        return mask & ~df["GRUPO_HOGAR"].duplicated()

    nivel = df["NIV_EDUCATIVO"]
    grado = df["GRADO_ALCANZADO"]

    columnas_ingreso = sorted({g[1] for g in GRUPOS_INGRESO})
    sin_flujo_ingreso = (df[columnas_ingreso] != 99).any(axis=1)

    rurales = (df["COD_CLASE"] != 1)
    sin_vereda = df["NOM_VEREDA"].isin(SIN_TERRITORIO)
    sin_corregimiento = df["NOM_CORREGIMIENTO"].isin(SIN_TERRITORIO)

    subsidio_codigo = (
        (df["VLR_INGR_FAM_ACCION"] == 9)
        | (df["VLR_INGR_COL_MAYOR"] == 9)
        | (df["VLR_INGR_OTRO_SUBSIDIO"] == 9)
    )

    total_gasto = sum(df[g[2]] for g in GRUPOS_GASTO)

    hogares_vivienda = df.groupby("IDVIVIENDA")["IDHOGAR"].transform("nunique")

    avisos = [
        filas(
            un_registro_por_hogar((df["IND_TIENE_COCINA"] == 2) & (df["TIP_USO_COCINA"] != 9)),
            "regla 7: hogar sin cocina con uso de cocina declarado"
        ),
        filas(
            un_registro_por_hogar((df["TIP_PREPARA_ALIMENTOS"] == 5) & (df["TIP_ENERGIA_COCINA"] != 7)),
            "regla 7: no preparan alimentos y declaran energía para cocinar"
        ),
        filas(
            un_registro_por_hogar(rurales & sin_vereda & sin_corregimiento),
            "regla 2: zona rural sin vereda ni corregimiento"
        ),
        filas(
            un_registro_por_hogar(total_gasto != df["VLR_TOTAL_GASTOS"]),
            "regla 8: total de gastos distinto a la suma de rubros"
        ),
        filas(
            un_registro_por_hogar(df["ESTADO_ORDEN"] == "ambigua"),
            "qtordenpersona: más de una forma de ubicar las referencias"
        ),
        filas(
            un_registro_por_hogar(hogares_vivienda != df["NUM_HOGARES_VIVIENDA"]),
            "idvivienda: la vivienda no tiene todos los hogares declarados"
        ),
        filas(
            (df["EDAD_CALCULADA"] < 8) & sin_flujo_ingreso,
            "regla 17: menor de 8 años con indicador de ingreso distinto de 99"
        ),
        filas(
            ((nivel == 2) & ~grado.isin(range(1, 6)))
            | ((nivel == 3) & ~grado.isin(range(6, 10)))
            | ((nivel == 4) & ~grado.isin(range(10, 12))),
            "regla 18: grado no coincide con el nivel educativo"
        ),
        filas(
            subsidio_codigo,
            "regla 21: subsidio con valor 9"
        )
    ]

    return pd.concat(avisos, ignore_index=True)
