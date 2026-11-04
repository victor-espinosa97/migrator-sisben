# infrastructure/database.py

from sqlalchemy import create_engine, text

from app.config.settings import DATABASE_URL


def crear_engine():

    engine = create_engine(
        DATABASE_URL,
        fast_executemany=True
    )

    # 🔎 Validar conexión: si falla, el proceso se detiene
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
        print("✅ Conexión a la BD exitosa")

    return engine
