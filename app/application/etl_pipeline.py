# application/etl_pipeline.py

from app.config.settings import (
    GRUPOS_DISCAPACIDAD,
    GRUPOS_EVENTO,
    GRUPOS_GASTO,
    GRUPOS_INGRESO,
    GRUPOS_PRIVACION,
    GRUPOS_RELACION,
    MAPA_HOGAR,
    MAPA_PERSONA,
    MAPA_VIVIENDA,
    MINIMO_HOGARES_CUADRAN,
    TABLA_HOGAR,
    TABLA_HOGAR_EVENTO,
    TABLA_HOGAR_GASTO,
    TABLA_HOGAR_PRIVACION_IPM,
    TABLA_PERSONA,
    TABLA_PERSONA_DISCAPACIDAD,
    TABLA_PERSONA_INGRESO,
    TABLA_PERSONA_RELACION,
    TABLA_VIVIENDA
)

from app.domain.rules import (
    asignar_orden_personas,
    asignar_territorio,
    construir_hogares,
    construir_viviendas,
    convertir_centinelas,
    girar_grupo,
    girar_relaciones
)

from app.domain.validators import medir_cuadre_hogares


def run_reconstruccion(df):

    stats = {}

    # 1. centinelas autorizados
    df, stats_centinelas = convertir_centinelas(df)
    stats["valores convertidos a nulo"] = sum(stats_centinelas.values())

    # 2. hogares
    df = construir_hogares(df)

    grupos, cuadran = medir_cuadre_hogares(df)
    proporcion = cuadran.mean()

    stats["hogares reconstruidos"] = len(grupos)
    stats["hogares que cuadran"] = int(cuadran.sum())

    # 🔥 Control: si el archivo cambió de forma, mejor detenerse
    if proporcion < MINIMO_HOGARES_CUADRAN:
        raise ValueError(
            f"Solo cuadra el {proporcion:.2%} de los hogares. "
            "Revise el archivo antes de cargar."
        )

    # 3. viviendas y orden de personas
    df = construir_viviendas(df)
    df = asignar_orden_personas(df)

    stats["viviendas reconstruidas"] = df["IDVIVIENDA"].nunique()

    for estado, total in (
        df.drop_duplicates("GRUPO_HOGAR")["ESTADO_ORDEN"].value_counts().items()
    ):
        stats[f"orden de personas: {estado}"] = int(total)

    return df, stats


def mapear(df, mapa, llave):

    columnas = df.drop_duplicates(llave)[list(mapa)]

    return columnas.rename(columns=mapa).reset_index(drop=True)


def run_tablas(df, existentes):

    df, codigos = asignar_territorio(df, existentes)

    df = df.reset_index(drop=True)
    df["IDPERSONA"] = df.index + 1

    hogares = df.drop_duplicates("IDHOGAR")

    tablas = {
        TABLA_VIVIENDA: mapear(df, MAPA_VIVIENDA, "IDVIVIENDA"),
        TABLA_HOGAR: mapear(df, MAPA_HOGAR, "IDHOGAR"),
        TABLA_HOGAR_GASTO: girar_grupo(
            hogares, "idhogar", "cdrubrogasto", GRUPOS_GASTO, ["fggasto", "mngasto"]
        ),
        TABLA_HOGAR_EVENTO: girar_grupo(
            hogares, "idhogar", "cdtipoevento", GRUPOS_EVENTO, ["fgevento", "qtevento"]
        ),
        TABLA_HOGAR_PRIVACION_IPM: girar_grupo(
            hogares, "idhogar", "cdprivacionipm", GRUPOS_PRIVACION, ["fgprivacion"]
        ),
        TABLA_PERSONA: mapear(df, MAPA_PERSONA, "IDPERSONA"),
        TABLA_PERSONA_DISCAPACIDAD: girar_grupo(
            df, "idpersona", "cdtipodiscapacidad", GRUPOS_DISCAPACIDAD, ["fgdiscapacidad"]
        ),
        TABLA_PERSONA_INGRESO: girar_grupo(
            df, "idpersona", "cdfuenteingreso", GRUPOS_INGRESO,
            ["fgingreso", "mningreso", "qtmesesingreso"]
        ),
        TABLA_PERSONA_RELACION: girar_relaciones(df, GRUPOS_RELACION)
    }

    return tablas, codigos
