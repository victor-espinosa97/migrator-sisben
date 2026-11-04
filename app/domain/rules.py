# domain/rules.py

import pandas as pd

from app.config.settings import (
    BARRIO_ENMASCARADO,
    CENTINELAS,
    CENTINELAS_REFERENCIA,
    COLUMNAS_FIRMA_HOGAR,
    COLUMNAS_REFERENCIA,
    COLUMNAS_VIVIENDA,
    SIN_TERRITORIO
)

from app.utils.dataframe_utils import anular_valores


def convertir_centinelas(df):

    stats = {}

    for col, centinela, indicador, valor_aplica in CENTINELAS:
        mask = (df[col] == centinela) & (df[indicador] != valor_aplica)
        df = anular_valores(df, col, mask)
        stats[col] = int(mask.sum())

    for col in COLUMNAS_REFERENCIA:
        mask = df[col].isin(CENTINELAS_REFERENCIA)
        df = anular_valores(df, col, mask)
        stats[col] = int(mask.sum())

    return df, stats


def construir_hogares(df):

    df["GRUPO_HOGAR"] = df.groupby(
        COLUMNAS_FIRMA_HOGAR,
        dropna=False,
        sort=False
    ).ngroup()

    return df


def construir_viviendas(df):

    hogares = df.drop_duplicates("GRUPO_HOGAR").copy()

    # 🔥 Quien declara un solo hogar tiene vivienda propia
    hogares["CLAVE_VIVIENDA"] = "S" + hogares["GRUPO_HOGAR"].astype(str)

    compartidos = hogares[hogares["NUM_HOGARES_VIVIENDA"] != 1].copy()

    # 🔥 Misma firma: el 1.º hogar 1 va con el 1.º hogar 2, en orden de archivo
    firma = compartidos.groupby(
        COLUMNAS_VIVIENDA,
        dropna=False,
        sort=False
    ).ngroup()

    turno = compartidos.groupby([firma, compartidos["IDE_HOGAR"]]).cumcount()

    hogares.loc[compartidos.index, "CLAVE_VIVIENDA"] = (
        "C" + firma.astype(str) + "-" + turno.astype(str)
    )

    hogares["IDVIVIENDA"] = pd.factorize(hogares["CLAVE_VIVIENDA"])[0] + 1
    hogares["IDHOGAR"] = (
        hogares["IDVIVIENDA"].astype(str) + "-" + hogares["IDE_HOGAR"].astype(str)
    )

    claves = hogares[["GRUPO_HOGAR", "IDVIVIENDA", "IDHOGAR"]]

    return df.merge(claves, on="GRUPO_HOGAR", how="left")


def referencias_de(fila, total):

    if fila["IND_CONYUGE_VIVE_HOGAR"] == 1 and fila["IDE_CONYUGE"] is not None:
        conyuge = fila["IDE_CONYUGE"] if fila["IDE_CONYUGE"] <= total else None
    else:
        conyuge = None

    if fila["IND_PADRE_VIVE_HOGAR"] == 1 and fila["IDE_PADRE"] is not None:
        padre = fila["IDE_PADRE"] if fila["IDE_PADRE"] <= total else None
    else:
        padre = None

    return conyuge, padre


def posicion_valida(personas, ubicadas):

    for i, persona in enumerate(personas):

        conyuge = persona["CONYUGE"]

        if conyuge in ubicadas:
            otra = ubicadas[conyuge]

            if otra == i:
                return False

            # 🔥 Si A dice que su cónyuge es B, B debe decir que es A
            regreso = personas[otra]["CONYUGE"]
            if regreso in ubicadas and ubicadas[regreso] != i:
                return False

        padre = persona["PADRE"]

        if padre in ubicadas:
            otra = ubicadas[padre]

            if otra == i:
                return False

            if personas[otra]["EDAD_CALCULADA"] - persona["EDAD_CALCULADA"] < 10:
                return False

    return True


def buscar_soluciones(personas, posiciones):

    soluciones = []
    ubicadas = {}
    usadas = set()

    def ubicar(k):

        if len(soluciones) > 30:
            return

        if k == len(posiciones):
            soluciones.append(dict(ubicadas))
            return

        for i in range(len(personas)):

            if i in usadas:
                continue

            ubicadas[posiciones[k]] = i
            usadas.add(i)

            if posicion_valida(personas, ubicadas):
                ubicar(k + 1)

            usadas.discard(i)
            del ubicadas[posiciones[k]]

    ubicar(0)

    return soluciones


def elegir_solucion(personas, soluciones):

    def destinos(solucion):
        return [
            (solucion.get(p["CONYUGE"]), solucion.get(p["PADRE"]))
            for p in personas
        ]

    distintas = []
    for solucion in soluciones:
        if destinos(solucion) not in [destinos(d) for d in distintas]:
            distintas.append(solucion)

    if len(distintas) == 1:
        return distintas[0], "unica"

    jefes = [i for i, p in enumerate(personas) if p["TIP_PARENTESCO"] == 1]
    con_jefe = [s for s in distintas if jefes and s.get(1) == jefes[0]]

    if len(con_jefe) == 1:
        return con_jefe[0], "unica_con_jefe_primero"

    # 🔥 Queda cargada, pero sale en avisos
    return (con_jefe or distintas)[0], "ambigua"


def ordenar_hogar(personas):

    posiciones = sorted({
        valor
        for persona in personas
        for valor in (persona["CONYUGE"], persona["PADRE"])
        if valor is not None
    })

    if not posiciones:
        ubicadas, estado = {}, "sin_referencias"
    else:
        soluciones = buscar_soluciones(personas, posiciones)

        if not soluciones:
            return None, "imposible"

        ubicadas, estado = elegir_solucion(personas, soluciones)

    # 🔥 Quienes nadie referencia ocupan los números libres
    libres = [n for n in range(1, len(personas) + 1) if n not in ubicadas]
    restantes = [i for i in range(len(personas)) if i not in ubicadas.values()]
    restantes.sort(key=lambda i: personas[i]["TIP_PARENTESCO"])

    orden = {persona: numero for numero, persona in ubicadas.items()}
    orden.update(zip(restantes, libres))

    return [orden[i] for i in range(len(personas))], estado


def asignar_orden_personas(df):

    orden = {}
    estados = {}

    for grupo, filas in df.groupby("GRUPO_HOGAR", sort=False):

        columnas = [
            "FILA_EXCEL",
            "EDAD_CALCULADA",
            "TIP_PARENTESCO",
            "IND_CONYUGE_VIVE_HOGAR",
            "IDE_CONYUGE",
            "IND_PADRE_VIVE_HOGAR",
            "IDE_PADRE"
        ]

        personas = filas[columnas].to_dict("records")

        for persona in personas:
            persona["CONYUGE"], persona["PADRE"] = referencias_de(
                persona,
                len(personas)
            )

        numeros, estado = ordenar_hogar(personas)
        estados[grupo] = estado

        if numeros:
            orden.update(zip(filas.index, numeros))

    df["QTORDENPERSONA"] = pd.Series(orden, dtype=object)
    df["ESTADO_ORDEN"] = df["GRUPO_HOGAR"].map(estados)

    return df


def asignar_codigos(nombres, existentes):

    codigos = dict(existentes)
    siguiente = max(codigos.values(), default=0) + 1

    for nombre in sorted(set(nombres)):
        if nombre not in codigos:
            codigos[nombre] = siguiente
            siguiente += 1

    return codigos


def asignar_territorio(df, existentes):

    corregimientos = df.loc[
        ~df["NOM_CORREGIMIENTO"].isin(SIN_TERRITORIO),
        "NOM_CORREGIMIENTO"
    ]

    veredas = df.loc[
        ~df["NOM_VEREDA"].isin(SIN_TERRITORIO),
        "NOM_VEREDA"
    ]

    # 🔥 BARRIO_S4 solo es un barrio en cabecera; en lo rural equivale a nulo
    es_barrio = (df["COD_CLASE"] == 1) | (df["NOM_BARRIO"] != BARRIO_ENMASCARADO)
    barrios = df.loc[es_barrio, "NOM_BARRIO"]

    codigos = {
        "corregimiento": asignar_codigos(corregimientos, existentes["corregimiento"]),
        "vereda": asignar_codigos(veredas, existentes["vereda"]),
        "barrio": asignar_codigos(barrios, existentes["barrio"])
    }

    df["CDCORREGIMIENTO"] = df["NOM_CORREGIMIENTO"].map(codigos["corregimiento"])
    df["CDVEREDA"] = df["NOM_VEREDA"].map(codigos["vereda"])
    df["CDBARRIO"] = df["NOM_BARRIO"].where(es_barrio).map(codigos["barrio"])

    return df, codigos


def girar_grupo(df, llave, codigo, grupos, destinos):

    partes = []

    for grupo in grupos:

        parte = pd.DataFrame({llave: df[llave.upper()].to_numpy()})
        parte[codigo] = grupo[0]

        for destino, origen in zip(destinos, grupo[1:]):
            parte[destino] = (
                df[origen].to_numpy(dtype=object) if origen else None
            )

        partes.append(parte)

    return pd.concat(partes, ignore_index=True)


def girar_relaciones(df, grupos):

    numeros = df.set_index(["IDHOGAR", "QTORDENPERSONA"])["IDPERSONA"].to_dict()

    partes = []

    for codigo, indicador, referencia in grupos:

        referidas = [
            None if orden is None else numeros.get((hogar, orden))
            for hogar, orden in zip(df["IDHOGAR"], df[referencia])
        ]

        partes.append(pd.DataFrame({
            "idpersona": df["IDPERSONA"].to_numpy(),
            "cdtiporelacion": codigo,
            "fgvivehogar": df[indicador].to_numpy(dtype=object),
            "idpersonarelacionada": pd.Series(referidas, dtype=object)
        }))

    return pd.concat(partes, ignore_index=True)
