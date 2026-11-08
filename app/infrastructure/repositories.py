# infrastructure/repositories.py

from app.config.settings import (
    DEPARTAMENTOS,
    MUNICIPIOS,
    TABLA_BARRIO,
    TABLA_CORREGIMIENTO,
    TABLA_DEPARTAMENTO,
    TABLA_MUNICIPIO,
    TABLA_VEREDA,
    TABLAS_CARGA,
    TAMANO_LOTE
)

from app.utils.dataframe_utils import filas_para_insertar


def leer_territorio(engine):

    conn = engine.raw_connection()

    try:
        cursor = conn.cursor()

        existentes = {}

        for nombre, tabla, codigo, texto in [
            ("corregimiento", TABLA_CORREGIMIENTO, "cdcorregimiento", "nmcorregimiento"),
            ("vereda", TABLA_VEREDA, "cdvereda", "nmvereda"),
            ("barrio", TABLA_BARRIO, "cdbarrio", "nmbarrio")
        ]:
            cursor.execute(f"SELECT {texto}, {codigo} FROM {tabla}")
            existentes[nombre] = {fila[0]: fila[1] for fila in cursor.fetchall()}

        return existentes

    finally:
        conn.close()


def insertar_dimensiones(cursor, codigos):

    # 🔥 Las dimensiones no se reemplazan: solo entran los valores nuevos
    for cddpto, nombre in DEPARTAMENTOS.items():
        cursor.execute(
            f"IF NOT EXISTS (SELECT 1 FROM {TABLA_DEPARTAMENTO} WHERE cddpto = ?) "
            f"INSERT INTO {TABLA_DEPARTAMENTO} (cddpto, nmdepartamento) VALUES (?, ?)",
            cddpto, cddpto, nombre
        )

    for cdmunicipio, nombre in MUNICIPIOS.items():
        cursor.execute(
            f"IF NOT EXISTS (SELECT 1 FROM {TABLA_MUNICIPIO} WHERE cdmunicipio = ?) "
            f"INSERT INTO {TABLA_MUNICIPIO} (cdmunicipio, cddpto, nmmunicipio) VALUES (?, ?, ?)",
            cdmunicipio, cdmunicipio, cdmunicipio[:2], nombre
        )

    cdmunicipio = list(MUNICIPIOS)[0]

    for nombre, codigo in codigos["corregimiento"].items():
        cursor.execute(
            f"IF NOT EXISTS (SELECT 1 FROM {TABLA_CORREGIMIENTO} WHERE cdcorregimiento = ?) "
            f"INSERT INTO {TABLA_CORREGIMIENTO} (cdcorregimiento, cdmunicipio, nmcorregimiento) "
            "VALUES (?, ?, ?)",
            codigo, codigo, cdmunicipio, nombre
        )

    # 🔥 cdcorregimiento queda nulo: cada vereda aparece con varios corregimientos
    for nombre, codigo in codigos["vereda"].items():
        cursor.execute(
            f"IF NOT EXISTS (SELECT 1 FROM {TABLA_VEREDA} WHERE cdvereda = ?) "
            f"INSERT INTO {TABLA_VEREDA} (cdvereda, cdcorregimiento, nmvereda) "
            "VALUES (?, NULL, ?)",
            codigo, codigo, nombre
        )

    for nombre, codigo in codigos["barrio"].items():
        cursor.execute(
            f"IF NOT EXISTS (SELECT 1 FROM {TABLA_BARRIO} WHERE cdbarrio = ?) "
            f"INSERT INTO {TABLA_BARRIO} (cdbarrio, cdmunicipio, nmbarrio) VALUES (?, ?, ?)",
            codigo, codigo, cdmunicipio, nombre
        )


def aislar_error(cursor, query, tabla, lote, inicio):

    # 🔥 Fila por fila, solo dentro del lote que falló
    for i, fila in enumerate(lote):

        try:
            cursor.execute(query, fila)

        except Exception as row_error:
            print(f"\n💥 FILA CON ERROR en {tabla}: posición {inicio + i}")
            print(f"➡️ Llave: {fila[:2]}")
            print("\n❌ ERROR DETALLE REAL:", row_error)
            raise Exception(f"❌ Fila problemática encontrada en {tabla}")


def insertar_tabla(cursor, tabla, df):

    columnas = list(df.columns)

    query = f"""
        INSERT INTO {tabla} ({",".join(columnas)})
        VALUES ({",".join(["?" for _ in columnas])})
    """

    filas = filas_para_insertar(df)

    for inicio in range(0, len(filas), TAMANO_LOTE):

        lote = filas[inicio:inicio + TAMANO_LOTE]

        cursor.execute("SAVE TRANSACTION antes_lote")

        try:
            cursor.executemany(query, lote)

        except Exception as e:
            print(f"\n💥 ERROR MASIVO DETECTADO en {tabla}:", e)
            print("🔎 Iniciando aislamiento real del error...\n")

            cursor.execute("ROLLBACK TRANSACTION antes_lote")
            aislar_error(cursor, query, tabla, lote, inicio)

            raise

    print(f"✅ {tabla}: {len(filas)} registros")


def cargar_tablas(engine, tablas, codigos):

    conn = engine.raw_connection()

    try:
        cursor = conn.cursor()
        cursor.fast_executemany = True

        # 🔥 Una sola transacción: si algo falla, los datos anteriores siguen intactos
        for tabla in TABLAS_CARGA:
            cursor.execute(f"DELETE FROM {tabla}")

        insertar_dimensiones(cursor, codigos)

        for tabla in reversed(TABLAS_CARGA):
            insertar_tabla(cursor, tabla, tablas[tabla])

        conn.commit()
        print("✅ Transacción confirmada")

    except Exception:
        conn.rollback()
        print("↩️ Transacción revertida: la base quedó como estaba")
        raise

    finally:
        conn.close()
