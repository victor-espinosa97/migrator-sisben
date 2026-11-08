## 🧠 Finalidad de la app

Es un **proceso ETL que migra el archivo Excel del SISBÉN IV a SQL Server**, en un modelo normalizado de 16 tablas. Es la app gemela de `detallado-alumnos`: misma estructura y mismo estilo, con la conexión a base de datos tomada de `mvp_etl_upload_to_bd`.

---

## 🗂️ Nombres de las tablas

Las tablas usan el código `PLN001###`. En el código Python están en `settings.py` como constantes `TABLA_*`.

| Tabla | Nombre funcional | Depende de | Quién la llena |
|---|---|---|---|
| `PLN001001` | catDominio | — | `02_sisben_iv_catalogos_sqlserver.sql` |
| `PLN001002` | catDominioValor | PLN001001 | `02_sisben_iv_catalogos_sqlserver.sql` |
| `PLN001003` | dimDepartamento | — | Migrador (solo valores nuevos) |
| `PLN001004` | dimMunicipio | PLN001003 | Migrador (solo valores nuevos) |
| `PLN001005` | dimCorregimiento | PLN001004 | Migrador (solo valores nuevos) |
| `PLN001006` | dimVereda | PLN001005 | Migrador (solo valores nuevos) |
| `PLN001007` | dimBarrio | PLN001004 | Migrador (solo valores nuevos) |
| `PLN001008` | Vivienda | PLN001004 – PLN001007 | Migrador, desde el Excel |
| `PLN001009` | Hogar | PLN001008 | Migrador, desde el Excel |
| `PLN001010` | HogarGasto | PLN001009 | Migrador, desde el Excel |
| `PLN001011` | HogarEvento | PLN001009 | Migrador, desde el Excel |
| `PLN001012` | HogarPrivacionIpm | PLN001009 | Migrador, desde el Excel |
| `PLN001013` | Persona | PLN001009 | Migrador, desde el Excel |
| `PLN001014` | PersonaRelacion | PLN001013 (dos veces) | Migrador, desde el Excel |
| `PLN001015` | PersonaDiscapacidad | PLN001013 | Migrador, desde el Excel |
| `PLN001016` | PersonaIngreso | PLN001013 | Migrador, desde el Excel |

---

## ⚙️ ¿Qué hace?

1. **Carga datos**

   * Lee el Excel indicado en `INPUT_FILE` (`app/config/settings.py`), todo como texto

2. **Estandariza estructura**

   * Limpia nombres de columnas y normaliza nulos
   * Convierte a `NULL` los códigos de "no aplica" autorizados (`CENTINELAS` en `settings.py`)

3. **Reconstruye lo que el archivo no trae**

   * Hogares: personas con las mismas 96 columnas de vivienda, hogar e IPM
   * Viviendas: quien declara un solo hogar tiene vivienda propia; si declara más, se empareja por firma y número de hogar
   * Orden de personas: se deduce de las referencias a cónyuge y padre o madre

4. **Valida**

   * Aparta el **hogar completo** si tiene algún error, y sigue con los demás
   * Deja el motivo en `output/corruptas_*.json` y `.csv`
   * Deja lo dudoso, sin excluirlo, en `output/avisos_*.csv`

5. **Carga en SQL Server**

   * Reemplaza los datos en **una sola transacción**: si algo falla, la base queda como estaba
   * Las dimensiones territoriales no se borran, para conservar sus códigos

---

## ▶️ Cómo se ejecuta

**Instalación** (requiere ODBC Driver 17 for SQL Server):

```bash
python3 -m venv venv
```

```bash
venv/bin/pip install -r requirements.txt
```

```bash
cp .env.template .env
```

Edita `.env` con los datos reales del servidor. Si la contraseña tiene caracteres especiales, hay que codificarlos para URL.

**Crear la base, solo la primera vez** (no borra nada; si las tablas existen, no hace nada):

```bash
sqlcmd -S servidor -U usuario -f 65001 -i sql/01_sisben_iv_schema_sqlserver.sql
```

```bash
sqlcmd -S servidor -U usuario -f 65001 -i sql/02_sisben_iv_catalogos_sqlserver.sql
```

**Ejecutar, siempre desde la raíz del proyecto:**

```bash
venv/bin/python main.py
```

Con `SOLO_VALIDAR=1` en `.env`, la app revisa y reporta sin tocar la base de datos. Es el valor por defecto de la plantilla. Para cargar, cambia a `SOLO_VALIDAR=0`.

La corrida completa tarda unos 5 minutos.

---

## 🔁 Cada corte nuevo

1. Cambia `INPUT_FILE` en `settings.py`.
2. Corre con `SOLO_VALIDAR=1` y revisa `output/`.
3. Corre con `SOLO_VALIDAR=0`. **El corte anterior se reemplaza.**

Si cuadra menos del 99 % de los hogares (`MINIMO_HOGARES_CUADRAN`), la carga se detiene: significa que el archivo cambió de forma.

---

## ⚠️ Limitaciones que hay que conocer

* **Viviendas, hogares y orden de personas son una reconstrucción**, no un dato de la fuente.
* **Las claves cambian en cada corte:** no se puede seguir a un hogar en el tiempo.
* **Los códigos de barrio, vereda y corregimiento son internos**, no los de SisbenApp.
* **`output/` no debe compartirse ni subirse a git:** el conjunto es confidencial (Ley 1581 de 2012).

Las decisiones y sus motivos están en `docs/03-plan-migrador.md`.
