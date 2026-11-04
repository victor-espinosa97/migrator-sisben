# 01 — Patrones de la app "detallado de alumnos"

Fuente: lectura completa de los 9 archivos `.py` (351 líneas en total), `requirements.txt`, `.gitignore`, `README.md` y el historial git (3 commits) de `detallado-alumnos/`.

## Lo primero que hay que saber

**`detallado-alumnos` no tiene varias de las cosas que el migrador necesita.** No se conecta a ninguna base de datos. Es un proceso de archivo a archivo: lee un CSV, lo limpia y escribe un CSV y un Parquet.

| Lo que se pidió copiar | ¿Existe en detallado-alumnos? |
|---|---|
| Forma de configurar la conexión | **No.** No hay conexión, ni `.env`, ni variables de entorno. |
| Librería de base de datos | **No.** Ni SQLAlchemy, ni pymysql, ni pyodbc. |
| Inserción por lotes y transacciones | **No.** Solo escribe archivos. |
| Estilo de logs | **Parcial.** Solo `print`. No usa `logging` ni archivo de log. |
| Manejo de errores con excepciones y reintentos | **No.** Solo hay un `raise ValueError` en el lector. |
| Lectura de Excel | **Parcial.** La rama existe, pero la ruta configurada es un CSV. |
| Pruebas | **No hay.** |
| Validación de datos | **Sí**, pero con el defecto descrito en la sección 6. |

Por eso se revisó también `mvp_etl_upload_to_bd`, la otra app de la misma carpeta, que sí inserta en base de datos. Sus partes se citan aquí como referencia y están marcadas como tal. **Decisión tomada: esa app es el modelo para las piezas de base de datos**, con los ajustes indicados al final de este documento.

---

## 1. Árbol de carpetas y archivos

```
detallado-alumnos/
├── main.py                              Orquesta el flujo de inicio a fin, con prints de avance
├── requirements.txt                     Dependencias con versión fija
├── README.md                            Finalidad y pasos del proceso (no dice cómo ejecutarlo)
├── .gitignore                           Excluye /data/*, /output/*, /env
├── app/                                 Sin archivos __init__.py (paquetes de espacio de nombres)
│   ├── config/
│   │   └── settings.py                  Constantes: rutas, llaves y listas de columnas
│   ├── application/
│   │   └── etl_pipeline.py              run_cleaning(): aplica las reglas en orden y devuelve (df, stats)
│   ├── domain/
│   │   ├── rules.py                     completar_por_grupo(): rellena nulos con ffill/bfill por llave
│   │   └── validators.py                detectar_filas_corruptas(): separa válidas de corruptas
│   ├── infrastructure/
│   │   ├── loaders.py                   load_file(): lee CSV o Excel según la extensión
│   │   ├── exporters.py                 export_parquet() y export_csv()
│   │   └── corrupt_exporter.py          export_corruptas(): JSON y CSV con marca de tiempo
│   └── utils/
│       └── dataframe_utils.py           clean_columns, normalize_nulls, normalize_text, quitar_tildes_pero_enie
├── data/                                Archivos de entrada (fuera de git)
└── output/                              Archivos de salida (fuera de git)
```

La organización sigue cuatro capas: `config`, `application`, `domain` e `infrastructure`, más `utils`.

## 2. Librerías y versiones

`requirements.txt` transcrito:

```
# requirements.txt

numpy==2.4.2
pandas==3.0.0
openpyxl==3.1.5
python-dotenv==1.2.1
pyarrow==23.0.1
```

Entorno real (`venv/pyvenv.cfg`): **Python 3.14.3**.

| Librería | Uso real |
|---|---|
| pandas | Todo el procesamiento |
| numpy | Solo `np.nan` en `normalize_nulls` |
| pyarrow | Motor de `to_parquet` |
| openpyxl | Motor de `read_excel` (la rama no se usa con la ruta actual) |
| python-dotenv | **Declarada pero nunca importada** |
| Biblioteca estándar | `pathlib`, `json`, `datetime`, `csv`, `unicodedata` |

## 3. Configuración

Solo hay constantes de Python en `app/config/settings.py`. No hay `.env` ni argumentos de línea de comandos. Forma exacta (la lista larga se abrevia aquí; son 25 columnas):

```python
# config/settings.py

INPUT_FILE = "data/estudiantes.csv"

OUTPUT_PARQUET = "output/estudiantes_limpio.parquet"
OUTPUT_CSV = "output/estudiantes_limpio_utf_8.csv"

KEY_ESTUDIANTE = "NUI"
KEY_INSTITUCION = "INSTITUCION"

COLUMNAS_POR_ESTUDIANTE = [
    "FECHA_NACIMIENTO",
    "GENERO",
    ...
]

COLUMNAS_FECHA = [
    "FECHA_NACIMIENTO"
]

COLUMNAS_POR_INSTITUCION = [
    "DANE"
]

COLUMNAS_POR_SEDE = [
    "CODIGO_DANE_SEDE",
    "ZONA_SEDE"
]
```

Las rutas son relativas a la raíz del proyecto. `corrupt_exporter.py` además tiene `output/` escrito directamente en el código.

**Referencia en `mvp_etl_upload_to_bd`** (`app/core/config.py` y `.env.template`):

```python
# core/config.py

import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")
```

```
DATABASE_URL=mssql+pyodbc://usuario:password@servidor/bd?driver=ODBC+Driver+17+for+SQL+Server
```

Esa plantilla apunta a **SQL Server**, no a MySQL. El archivo `.env` real no se abrió.

## 4. Conexión a la base de datos

No existe en `detallado-alumnos`.

**Referencia en `mvp_etl_upload_to_bd`** (`app/infrastructure/database.py`): SQLAlchemy 2.0.46 con pyodbc 5.3.0 y `create_engine(DATABASE_URL, fast_executemany=True)`. Prueba la conexión con `SELECT 1` al importar el módulo e imprime `✅` o `❌`. Si falla, solo imprime y sigue. `pyodbc` está instalado en su `venv`, pero no aparece en su `requirements.txt`.

## 5. Lectura de Excel

`app/infrastructure/loaders.py`, completo:

```python
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
```

Patrón clave: **todo se lee como texto** (`dtype=str`). Se probó esa misma llamada con el Excel del SISBÉN: tarda **69,7 segundos**, trae las 104.292 filas y 151 columnas, y conserva los ceros a la izquierda (`05`, `05615`). Sirve tal cual.

## 6. Validación antes de procesar

`detectar_filas_corruptas(df)` en `app/domain/validators.py`. Es una función interna `fila_corrupta(row)` aplicada con `df.apply(..., axis=1)`. Acumula los motivos en una lista `errores` y devuelve `(df_validas, df_corruptas)`. Valida estructura, no contenido, según su propio comentario (`Validación REAL: estructura, no contenido`).

**Defecto confirmado por ejecución.** La función escribe el motivo así:

```python
if errores:
    row["__errores__"] = ", ".join(errores)
    return True
```

`apply` entrega una copia de la fila, de modo que esa escritura se pierde. Se ejecutó con 3 filas de prueba: detectó 2 corruptas, pero el resultado salió con las columnas `DOC, INSTITUCION, NOMBRE1, JORNADA`, **sin `__errores__`**. Es decir, la app dice cuáles filas están mal, pero **no por qué**. El migrador necesita exactamente lo segundo, así que no se puede copiar sin corregir (ver observaciones en `03-plan-migrador.md`).

## 7. Manejo de errores

- No hay `try/except` en ningún archivo. Una excepción detiene el programa con la traza de Python.
- No hay reintentos.
- **Una fila mala no detiene el proceso:** se aparta, se exporta y el proceso sigue con las demás.

`export_corruptas(df)` escribe `output/corruptas_{timestamp}.json` y `.csv` con la fila completa, e imprime:

```python
print(f"\n🚨 Filas corruptas detectadas: {len(df)}")
print(f"📁 JSON: {path_json}")
print(f"📁 CSV: {path_csv}\n")
```

**Referencia en `mvp_etl_upload_to_bd`:** ante un error masivo abre una conexión nueva y prueba fila por fila hasta encontrar la que falla, imprimiendo sus valores y el mensaje del motor. Es la pieza más aprovechable para decir "cuál fila y por qué". Pero esa app también recorta textos (`val[:1000]`, `str(v)[:1]`) y convierte en `None` lo que no puede interpretar, usando `except:` sin tipo. Eso contradice el requisito de no arreglar datos.

## 8. Registro de lo que va pasando

Solo `print` a consola, en español, con emojis y signos de avance. No hay `logging`, archivo de log ni niveles. Ejemplo de `main.py`:

```python
print("Leyendo archivo...")
print("Limpiando columnas...")
print("Normalizando nulls...")
print("Detectando filas corruptas...")
print("Aplicando reglas de limpieza...")
print("\nValores completados:")
for k, v in stats.items():
    print(k, v)
print("\nGuardando resultados...")
print("ETL finalizado")
```

También imprime una validación rápida de lectura (`--- VALIDACIÓN DE LECTURA ---`) y un resumen de métricas a partir del diccionario `stats`.

## 9. Lotes y transacciones

`detallado-alumnos` no inserta nada. Procesa el `DataFrame` completo en memoria y escribe al final.

**Referencia en `mvp_etl_upload_to_bd`:** lotes de 1.000 filas con `cursor.executemany` y `conn.commit()` por lote. Si el lote 5 falla, los lotes 1 a 4 ya quedaron guardados. Para el SISBÉN eso dejaría una carga a medias.

## 10. Convención de nombres e idioma

| Elemento | Convención real | Ejemplos |
|---|---|---|
| Archivos y carpetas | Inglés, `snake_case` | `loaders.py`, `etl_pipeline.py` |
| Funciones | **Mezcla** español e inglés, `snake_case` | `load_file`, `run_cleaning`, `clean_columns`, `detectar_filas_corruptas`, `completar_por_grupo` |
| Variables | Mayormente español | `errores`, `doc`, `nombre`, `resultado`; también `key`, `stats`, `filled` |
| Constantes | `MAYUSCULAS` en español o mixto | `COLUMNAS_POR_ESTUDIANTE`, `KEY_ESTUDIANTE`, `INPUT_FILE` |
| Columnas del `DataFrame` | Mayúsculas | `clean_columns` deja `DOC`, `NOMBRE1` |
| Comentarios | **Español**, con emojis | `# 🔥 LIMPIEZA BASE`, `# 🔥 NUEVO: detectar corruptas` |
| Docstrings | **Ninguno** | |
| Anotaciones de tipo | **Ninguna** | |
| Clases | **Ninguna**; todo son funciones | |

Otros hábitos de estilo:

- Una línea en blanco después de cada `def`.
- La primera línea del archivo suele ser un comentario con su ruta: `# infrastructure/loaders.py`.
- Las funciones de transformación devuelven el `DataFrame`, y a veces una tupla con métricas: `df, stats`.

## 11. Pruebas

No tiene. No hay carpeta `tests`, ni `pytest`, ni scripts de verificación. La única comprobación es el `print` de la primera fila en `main.py`.

## 12. Cómo se ejecuta

El `README.md` no lo dice. Por la estructura, debe correrse **desde la raíz del proyecto**, porque las rutas son relativas y los imports parten de `app`:

```bash
venv/bin/python main.py
```

Se comprobó que los imports funcionan desde la raíz. **No se ejecutó `main.py` completo** porque habría sobrescrito tus archivos de `output/`.

---

## PLANTILLA A REPLICAR

Estas decisiones se copian tal cual en la app nueva.

**Estructura**

1. Mismas capas y nombres: `main.py`, `app/config/settings.py`, `app/application/etl_pipeline.py`, `app/domain/rules.py`, `app/domain/validators.py`, `app/infrastructure/loaders.py`, `app/infrastructure/corrupt_exporter.py`, `app/utils/dataframe_utils.py`.
2. Sin archivos `__init__.py`.
3. Carpeta `output/` fuera de git. En lugar de `data/`, el Excel se lee desde `insumos/`, para no duplicar un archivo confidencial de 58 MB.
4. Ejecución con `python main.py` desde la raíz, sin argumentos.

**Librerías**

5. Python 3.14.3 con las mismas versiones: pandas 3.0.0, numpy 2.4.2, openpyxl 3.1.5, python-dotenv 1.2.1. `pyarrow` no se incluye porque no se escribe Parquet.
6. Las versiones van fijas en `requirements.txt`, con el comentario `# requirements.txt` en la primera línea.

**Configuración**

7. Todo lo que no sea secreto va como constante en `settings.py`, con listas de columnas por nivel de agrupación, al estilo de `COLUMNAS_POR_ESTUDIANTE`.

**Código**

8. Solo funciones. Sin clases, docstrings ni anotaciones de tipo.
9. Comentarios en español, con el mismo tono, incluidos los `# 🔥`.
10. Primera línea de cada archivo con su ruta en comentario.
11. Funciones nuevas con nombre en español, como las de `domain`. Se conservan los nombres en inglés de las funciones copiadas (`load_file`, `clean_columns`, `normalize_nulls`).
12. `main.py` lineal: un `print` de avance y una llamada por paso.
13. `run_...(df)` en `application/` devuelve `df, stats`, y `main.py` imprime las métricas.

**Datos**

14. `load_file(path)` idéntico, con `dtype=str`.
15. `clean_columns` y `normalize_nulls` idénticos. Las 151 columnas siguen siendo únicas tras pasarlas a mayúsculas (verificado).
16. `detectar_filas_corruptas(df)` devuelve `(df_validas, df_corruptas)`, con motivos acumulados en una lista `errores`.
17. `export_corruptas(df)` con la misma salida `output/corruptas_{timestamp}.json` y `.csv`, y los mismos mensajes `🚨` y `📁`. Solo guarda fila de Excel, claves generadas y motivo, por tratarse de datos sensibles.

**Lo que NO se replica**

18. `completar_por_grupo` (rellena nulos con ffill/bfill): contradice "no arreglar datos".
19. La escritura de `__errores__` tal como está: pierde el motivo.
20. `normalize_text`: quitaría las tildes a los nombres territoriales.

**Base de datos: se toma de `mvp_etl_upload_to_bd`**

21. `.env` y `.env.template` con `DATABASE_URL`, en el formato `mssql+pyodbc://...?driver=ODBC+Driver+17+for+SQL+Server`.
22. `load_dotenv()` y `os.getenv("DATABASE_URL")`, dentro de `app/config/settings.py`, para conservar la estructura de `detallado-alumnos`.
23. `app/infrastructure/database.py`: `create_engine(DATABASE_URL, fast_executemany=True)` y prueba con `SELECT 1`.
24. `app/infrastructure/repositories.py`: `engine.raw_connection()`, `cursor.executemany` con marcadores `?` y aislamiento fila por fila ante un error.
25. SQLAlchemy 2.0.46 y pyodbc 5.3.0 en `requirements.txt`. `pyodbc` falta en el de la app de origen.

**De esa app NO se toma**

26. El recorte de textos (`val[:1000]`, `str(v)[:1]`) ni la conversión a `None` con `except:` sin tipo.
27. El `commit` por lote: aquí es una sola transacción, con `ROLLBACK` si algo falla.
28. Seguir cuando falla la conexión: aquí el proceso se detiene.
29. FastAPI y el resto de la capa web. El migrador se ejecuta con `python main.py`.
