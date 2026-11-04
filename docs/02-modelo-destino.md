# 02 — Modelo destino e insumos

Todo lo que aparece aquí se midió contra los archivos reales. Las cifras salen de reconstruir las tablas con las 104.292 filas del Excel y evaluar cada restricción. El DDL se ejecutó en un MySQL 8.4.9 real, en un contenedor temporal local que ya fue eliminado. **Los archivos de `insumos/` no se modificaron.**

## Resumen

**Decisiones tomadas:**

- **El destino es SQL Server.** El DDL entregado está escrito para MySQL, así que hay que traducirlo (sección 3).
- **No existe una versión del archivo con claves o códigos reales.** El archivo anonimizado es la única fuente, y todas las claves deben generarse a partir de él.

Las decisiones sobre cada opción de este documento y los resultados de la carga están al inicio de `03-plan-migrador.md`. Este documento conserva el análisis que las sustenta.

El modelo está bien pensado y gran parte de los datos lo respalda, pero **no se puede cargar tal como está**. Hay tres bloqueos:

1. **El DDL no sirve para el destino.** Está escrito para MySQL, y ni siquiera allí se ejecuta: en MySQL 8.4.9 falla y solo crea 3 de las 16 tablas.
2. **`ide_hogar` no es una clave.** Solo tiene 6 valores distintos (del 1 al 6). Es el número del hogar dentro de la vivienda. La columna en que se apoya casi todo el modelo no identifica hogares.
3. **Los códigos territoriales vienen 100 % vacíos** (`Cod_barrio`, `Cod_vereda`, `Cod_corregimiento`), y los nombres están parcialmente enmascarados.

Las cifras de violaciones de este documento siguen vigentes con SQL Server. Salen de los datos y de las expresiones de cada CHECK, no de un motor concreto, y la lógica de nulos en un CHECK es la misma en ambos.

También hay buenas noticias. Los hogares se pueden reconstruir con mucha fiabilidad: **41.003 de 41.016 grupos cuadran perfectamente**. Y 10 de las 24 reglas no tienen ninguna violación. La regla del IPM coincide en el 100 % de los hogares.

---

## 1. Verificación de los insumos

| Afirmación | Resultado | Detalle |
|---|---|---|
| 16 tablas | ✅ | Se crean las 16 tras la corrección de la sección 3. Son 94 CHECK y 18 llaves foráneas. |
| 35 dominios y 280 valores | ✅ | Confirmado cargando el catálogo en MySQL. El comentario del DDL dice "31 dominios": está desactualizado. |
| 151 variables | ✅ | Excel, `Diccionario.xlsx` y hoja "Ficha" coinciden en nombres y orden. |
| Reparto 21 · 32 · 16 · 12 · 15 · 20 · 6 · 8 · 21 | ✅ | Suma 151. |
| 24 reglas de consistencia | ✅ | La hoja también trae 9 notas técnicas. |
| Las 24 reglas están implementadas como CHECK | ❌ | **9 completas, 10 parciales y 5 sin CHECK** (sección 6). |
| `idhogar` es la única clave real del archivo | ❌ | Solo tiene 6 valores distintos. |
| `dimVereda` cuelga de un corregimiento | ❌ | Cada vereda aparece con 2 a 6 corregimientos. |
| Archivo `BD anonimizada Rionegro_planeacion_07022026.xlsx` | ⚠️ | El nombre real termina en `(1).xlsx`. |
| Archivo de datos | — | Una hoja ("Sisbén"), 104.292 filas, 151 columnas, un solo municipio (`05615`). |

## 2. Por qué el modelo es así

Cada fila del archivo es una persona, pero también repite los datos de su vivienda y su hogar. Cargar eso en una sola tabla duplica los datos de vivienda y hogar, e impide contar hogares sin error. El modelo los separa en tercera forma normal:

```
dimDepartamento → dimMunicipio → dimCorregimiento → dimVereda
                               → dimBarrio
                               → Vivienda → Hogar → HogarGasto · HogarEvento · HogarPrivacionIpm
                                                  → Persona → PersonaRelacion · PersonaDiscapacidad · PersonaIngreso
catDominio → catDominioValor      (etiquetas para Power BI; sin llave foránea hacia las tablas)
```

Las 78 columnas de grupos repetidos se convierten en filas. Cargando la grilla completa, serían **3.773.136 filas** en total:

| Tabla | Filas |
|---|---|
| Vivienda | ~39.648 (depende del criterio elegido) |
| Hogar | ~41.016 |
| HogarGasto | 328.128 |
| HogarEvento | 246.096 |
| HogarPrivacionIpm | 615.240 |
| Persona | 104.292 |
| PersonaRelacion | 312.876 |
| PersonaDiscapacidad | 834.336 |
| PersonaIngreso | 1.251.504 |

## 3. Bloqueo: el DDL no sirve para el destino

### 3.1 Lo que falló en MySQL

Esta prueba se hizo antes de definir el motor. Con SQL Server este error en particular no aplica, pero queda registrado porque el encabezado del DDL afirma que corre en MySQL 8.0.16+.

MySQL prohíbe usar en un CHECK una columna que participe en una acción referencial (`ON UPDATE CASCADE`, `ON DELETE CASCADE`). Error real:

```
ERROR 3823 (HY000) at line 109: Column 'cddpto' cannot be used in a check constraint
'ck_dimmunicipio_prefijo': needed in a foreign key constraint 'fk_dimmunicipio_dpto' referential action.
```

El efecto es en cadena: sin `dimMunicipio` no se crea casi nada más. Quedan solo `catDominio`, `catDominioValor` y `dimDepartamento`. Son **6 llaves foráneas** las que chocan:

| Llave foránea | Columna | CHECK con el que choca |
|---|---|---|
| `fk_dimmunicipio_dpto` | `cddpto` | `ck_dimmunicipio_prefijo` |
| `fk_vivienda_barrio` | `cdbarrio` | `ck_vivienda_territorio_urbano` |
| `fk_vivienda_vereda` | `cdvereda` | `ck_vivienda_territorio_rural` |
| `fk_vivienda_corregimiento` | `cdcorregimiento` | `ck_vivienda_territorio_rural` |
| `fk_personarelacion_persona` | `idpersona` | `ck_personarelacion_noautoreferencia` |
| `fk_personarelacion_relacionada` | `idpersonarelacionada` | `ck_personarelacion_referencia` |

En una copia de trabajo se cambiaron esas 6 a `ON UPDATE RESTRICT ON DELETE RESTRICT`. Así se crearon las 16 tablas, los 94 CHECK y las 18 llaves, y el catálogo cargó completo. Esa copia solo sirvió para medir.

### 3.2 Traducción necesaria para SQL Server

**Traducción hecha y probada** en `sql/`, sobre SQL Server 2022 Developer local y temporal. Falta ejecutarla en el servidor de la Alcaldía. Se probó el resultado, no cada caso de esta tabla por separado: por ejemplo, no se ensayó el DDL con `ON UPDATE CASCADE` para confirmar el rechazo por rutas de cascada.

| Elemento MySQL | Usos | En SQL Server |
|---|---|---|
| `REGEXP` en CHECK | 3 | No existe. `cddpto` y `cdmunicipio` pasan a `LIKE '[0-9][0-9]'` y equivalente. `cdclasificacionsisben` pasa a una lista `IN` con los 51 valores. |
| `TINYINT UNSIGNED` | 70 | `TINYINT`, sin cambio de rango (0 a 255). |
| `SMALLINT UNSIGNED` | 10 | `INT`, para no perder rango. |
| `INT UNSIGNED` | 8 | `INT`; los CHECK limitan los valores a 999.999. |
| `BIGINT UNSIGNED` | 7 | `BIGINT`. |
| `AUTO_INCREMENT` | 2 | `IDENTITY`, o `BIGINT` asignado por Python (pregunta 6). |
| `ON UPDATE CASCADE` | 18 | Ver abajo. |
| `ON DELETE RESTRICT` | 10 | `NO ACTION`. |
| `COMMENT` | 135 líneas | Propiedades extendidas o comentarios SQL. |
| `ENGINE=InnoDB` | 16 | Se elimina. |
| `CREATE DATABASE ... CHARACTER SET`, `SET FOREIGN_KEY_CHECKS` | Encabezado | Sintaxis propia; la intercalación de la base debe conservar tildes y ñ. |

**Rutas de cascada.** SQL Server rechaza una llave foránea si hay más de un camino de cascada entre dos tablas. Con las 18 `ON UPDATE CASCADE` actuales, eso debería ocurrir en dos lugares:

- **`Vivienda`:** `dimMunicipio` le llega directo, por `dimBarrio`, por `dimCorregimiento` y por `dimVereda`.
- **`PersonaRelacion`:** tiene dos llaves hacia `Persona`.

**No cambia:** el resto de expresiones de los CHECK (`BETWEEN`, `IN`, `LEFT`, `IS NULL`), `DECIMAL(15,2)` ni `VARCHAR`. La restricción que falló en MySQL (error 3823) no existe en SQL Server, así que los 94 CHECK pueden conservarse.

`sql/02_sisben_iv_catalogos_sqlserver.sql` solo agrega el prefijo `N` a los textos y el valor 9 de `energiacocina`, y deja 281 valores.

### 3.3 Entorno de conexión

Comprobado en este equipo, en el `venv` de `mvp_etl_upload_to_bd`: SQLAlchemy 2.0.46, pyodbc 5.3.0 y **ODBC Driver 17 for SQL Server**, el mismo de su `.env.template`. La conexión se probó contra el servidor local temporal, no contra el de la Alcaldía.

---

## 4. Bloqueo: hogares y personas no tienen clave

Las opciones se conservan con sus medidas. La elección final está en `03-plan-migrador.md`.

### 4.1 `ide_hogar`: lo que realmente es

| `ide_hogar` | Personas |
|---|---|
| 1 | 101.103 |
| 2 | 2.642 |
| 3 | 458 |
| 4 | 81 |
| 5 | 5 |
| 6 | 3 |

Coincide con la pregunta 23 de la encuesta: número del hogar **dentro de la vivienda**. Como `Hogar.idhogar` es llave primaria, una carga literal solo admitiría 6 hogares.

### 4.2 Reconstrucción de hogares

Todas las personas de un hogar comparten sus 96 columnas de vivienda, hogar, IPM y clasificación. Agrupar por esa firma exacta da **41.016 grupos, frente a 41.012 jefes de hogar**.

| Comprobación | Resultado |
|---|---|
| Grupos con tamaño igual a `num_personas_hogar` y exactamente un jefe | **41.003 de 41.016** |
| `H_5` coincide con las 15 privaciones (ponderación estándar del DANE, umbral 33,3 %) | **41.016 de 41.016** |
| `mngastototal` igual a la suma de los 8 rubros | **41.016 de 41.016** |

Dos advertencias:

- La ponderación del IPM no está en los insumos. Se usó la metodología estándar del DANE que la regla 23 menciona. Su coincidencia total respalda tanto la regla como la reconstrucción.
- No sirve confiar en filas contiguas: 1.173 hogares tienen a sus personas intercaladas con otras y el jefe no siempre va primero.

Los **13 grupos que no cuadran** suman 28 filas:

| Caso | Filas de Excel | Qué pasa |
|---|---|---|
| Hogar partido en 2 porque difieren I5, I7, I8, I9 o la clasificación | 26745-26747 · 50036-50038 · 87474-87475 · 87786-87787 | 4 hogares (8 grupos). Violan "iguales para todas las personas del hogar". |
| Más filas que `num_personas_hogar` | 8659-8661 · 92901-92906 · 104277-104280 | 3 grupos |
| Dos hogares unipersonales idénticos | 68876 y 100655 | 1 grupo con 2 jefes |
| Sin jefe | 87335-87337 | 1 grupo |

### 4.3 Formato de `idhogar`

El DDL define `VARCHAR(20)` y no tiene otra columna para el número del hogar dentro de la vivienda.

| Opción | Ejemplo | Ventaja | Riesgo |
|---|---|---|---|
| A. `idvivienda-ide_hogar` | `10234-2` | Conserva `ide_hogar` sin tocar el modelo | Depende del criterio de vivienda |
| B. Consecutivo | `H0041016` | Simple e independiente | Se pierde `ide_hogar` |
| C. Clave sustituta y columna nueva `qtnumerohogar` | | Modelo más limpio | Cambia el DDL |

### 4.4 Criterios para `idvivienda`

Cada hogar declara `num_hogares_vivienda`. Si es 1, vive solo en su vivienda por definición. De los 41.016 hogares, 38.433 declaran 1 y 2.583 declaran más de 1.

| | Criterio A: 1 hogar = 1 vivienda | Criterio B: firma exacta de las 21 columnas de vivienda | Criterio C: declaración + firma + `ide_hogar` |
|---|---|---|---|
| Regla | Cada hogar genera su vivienda | Misma firma, misma vivienda | Si declara 1: vivienda propia. Si declara más: misma firma, emparejando el 1.º `ide_hogar` 1 con el 1.º `ide_hogar` 2, en orden de archivo |
| Viviendas | 41.016 | 11.705 | 39.648 |
| Coherencia | Ignora lo que declaran 2.583 hogares | Une 30.731 hogares que declararon vivir solos | 1.092 de las 1.215 viviendas compartidas quedan completas |
| Riesgo principal | Sobrecuenta viviendas (~3,5 %); la relación vivienda-hogar nunca es 1:N | Contradice el dato declarado: las colisiones son masivas, porque dos viviendas pueden ser iguales en todo | Depende del orden del archivo |
| Sensible a reordenar el Excel | No | No | **Sí**, en los empates |

Detalle del criterio C:

- Quedan 123 viviendas incompletas: 174 hogares y 409 personas, porque falta algún hogar en el archivo.
- En las completas, la mediana de distancia entre hogares es de 2 filas. Pero 91 tienen más de 200 filas de distancia, y esas parejas son dudosas.
- 74 hogares tienen `ide_hogar` mayor que el total declarado. De ellos, 52 declaran vivir solos con `ide_hogar` mayor que 1.

### 4.5 `idpersona`

Es un consecutivo sin dificultad. Lo que importa es **quién lo genera**, porque `PersonaRelacion` necesita conocerlo.

| Opción | Ventaja | Riesgo |
|---|---|---|
| A. Python lo asigna antes de insertar | Simple; no hay que releer | Exige `SET IDENTITY_INSERT`, o definir la columna como `BIGINT` sin `IDENTITY` |
| B. Lo asigna el motor (`IDENTITY`) y se relee `(idhogar, qtordenpersona) → idpersona` | Más fiel al diseño del DDL | Una consulta y un cruce adicionales |

### 4.6 `qtordenpersona`

Este es el punto más delicado. `ide_conyuge` e `ide_padre` apuntan al número de orden de otra persona del hogar, pero **ese número no viene en el archivo, y el orden de las filas no es el orden original**.

La medida usada es la reciprocidad: si A dice que su cónyuge es el número 2, el número 2 debe decir que su cónyuge es A. Para padre o madre, que sea al menos 10 años mayor (umbral supuesto para este análisis).

| Opción | Regla | Cónyuge recíproco | Padre ≥ 10 años mayor | Complejidad |
|---|---|---|---|---|
| A | Orden del archivo | 56,7 % (y 32,9 % se apunta a sí mismo) | 53,5 % | Mínima |
| B | Por parentesco y luego por archivo | 90,2 % | 95,5 % | Mínima |
| C | Deducir el orden resolviendo las referencias, hogar por hogar | Ver abajo | Ver abajo | Alta |
| D | No resolver a persona: guardar el número declarado | No aplica | No aplica | Baja, pero cambia el DDL |

Resultado de la opción C:

| Situación | Hogares | Personas |
|---|---|---|
| Sin referencias que resolver | 12.469 | 14.964 |
| Solución única | 25.887 | 76.851 |
| Única si se asume que el jefe es el número 1 | 1.427 | 6.070 |
| Ambigua (normalmente no se distingue a cuál de los dos padres se refiere) | 1.223 | 6.361 |
| Imposible, datos contradictorios | 10 | 46 |

La opción C es la más fiel, pero es el código más difícil de explicar y heredar, lo que choca con tu requisito principal.

### 4.7 Las claves no son estables

El archivo está anonimizado y no existe una versión con identificadores reales. Por eso `idvivienda`, `idhogar` e `idpersona` valdrán cosas distintas en cada corte semestral, y **no se podrá seguir a un mismo hogar entre cortes**. Es una limitación permanente del modelo: los indicadores por corte sí son válidos, pero no el seguimiento de hogares a lo largo del tiempo. Conviene dejarlo claro ante la Alcaldía y en Power BI.

También es permanente que viviendas, hogares y números de orden son **una reconstrucción, no un dato de la fuente**. Por ejemplo, el número de viviendas será una estimación que depende del criterio elegido.

---

## 5. Bloqueo: territorio

### 5.1 `nmdepartamento` y `nmmunicipio`

El archivo solo trae `05` y `05615`.

| Opción | Ventaja | Riesgo |
|---|---|---|
| **1. Constantes en `settings.py` (recomendada)** | Mismo patrón de la app gemela. Si aparece otro código, la carga falla y avisa | Se mantiene a mano |
| 2. Script `03_dimensiones.sql` | Queda junto a los otros SQL | Otro archivo que correr en orden |
| 3. Cargar toda la DIVIPOLA | Catálogo completo | Requiere un archivo que no está en `insumos/`, y sobra para un municipio |

Se recomienda la opción 1: `{"05": "Antioquia"}` y `{"05615": "Rionegro"}`. `Antioquia` sale de `Diccionario.xlsx`. `Rionegro` sale del nombre del archivo y del contexto, **no de un catálogo incluido en los insumos**, así que hay que confirmarlo.

### 5.2 Códigos de barrio, vereda y corregimiento (hueco adicional)

Este es un problema más grande que el de 5.1. Las tres columnas de código están vacías, pero son llave primaria de sus dimensiones, y `ck_vivienda_territorio_urbano` exige barrio en toda vivienda de cabecera. Como no hay un archivo con códigos reales, habrá que generarlos a partir de los nombres, y serán códigos internos, no los de SisbenApp.

Además, los nombres vienen parcialmente enmascarados:

| Valor | Filas | Observación |
|---|---|---|
| `BARRIO_S4` | 39.779 | 3.059 en cabecera; el resto en zona rural |
| `NO USAR` | 9.700 | Todas en cabecera |
| `CORREGIMIENTO_S4` | 10.625 | Solo en zona rural |
| `SIN VEREDA` / `SIN CORREGIMIENTO` | 75.856 / 76.533 | Equivalen a nulo |

- Hay **12.759 personas de cabecera** sin barrio real.
- Hay **3.323 personas de zona rural** sin vereda ni corregimiento. Son 1.409 viviendas que violan `ck_vivienda_territorio_rural`.
- `EL PROGESO ` trae un espacio al final y parece tener un error de digitación.
- Hay nombres repetidos entre barrios y veredas: `SAN ANTONIO`, `SANTA ANA`, `BARRO BLANCO`.
- No se conoce el significado de `S4` ni de `NO USAR`. **No se asume nada.**

### 5.3 `dimVereda` no cuadra con los datos

El modelo supone que cada vereda pertenece a un corregimiento. En los datos, **cada una de las 36 veredas aparece con 2 a 6 corregimientos**. Por ejemplo, `ABREO` aparece en 5. Por tanto, `dimVereda.cdcorregimiento` no se puede deducir del archivo. Se podría dejar nulo, ya que el DDL lo permite.

---

## 6. Las 24 reglas frente a los datos reales

**Cobertura:** Total = CHECK cubre la regla. Parcial = cubre una parte. No = imposible en un CHECK, porque compara varias filas o tablas.

| # | Tema | CHECK | Violaciones reales |
|---|---|---|---|
| 1 | Departamento y municipio | Parcial: no fija `05` | **0** |
| 2 | Territorio según clase | Parcial | 1.409 viviendas |
| 3 | Estrato sin servicio | Total | 22 y 86 viviendas |
| 4 | Jerarquía de cuartos | Parcial | 7 hogares |
| 5 | Sanitario | Total | **0** |
| 6 | Días y horas de agua | Total | 4 hogares (tras convertir centinelas, sección 7) |
| 7 | Cocina | Parcial | **11.448 hogares** y 389 hogares |
| 8 | Gastos | Parcial: pide ≥ 0, la regla dice > 0 | **0** |
| 9 | Eventos | Total | **0** (tras convertir centinelas) |
| 10 | Un jefe; personas = conteo | No | 13 grupos |
| 11 | Referencias entre personas | Parcial: no exige mismo hogar | 263 personas |
| 12 | Pariente de servicio doméstico | No | **0** (no hay parentesco 16 ni 18) |
| 13 | Discapacidad "ninguna" | No | **0** |
| 14 | Flujo de salud | Total | 1 persona |
| 15 | Embarazo e hijos | Total | 37 personas |
| 16 | Edad 5 años | Total | **0** |
| 17 | Edad 14 y 8 años | Parcial | 5 y 4 personas; **9.797** con ingreso ≠ 99 siendo menores de 8 |
| 18 | Grado y nivel educativo | No | 2.264 personas (en los 3 ejemplos de la regla) |
| 19 | Semanas buscando trabajo | Total | **0** |
| 20 | Ingresos | Parcial: pide ≥ 0, la regla dice > 0 | **0** |
| 21 | Subsidios | No | **0** |
| 22 | Rangos | Total | 2 personas de 125 años |
| 23 | IPM | Parcial | 0 en el cálculo; 4 hogares con privaciones distintas entre personas |
| 24 | Clasificación | Parcial | 0 en el patrón; 4 hogares con diferencias entre personas |

**Las reglas sin CHECK tendrán que validarse en Python**, o nadie las hará cumplir.

### Otros choques entre CHECK y datos

| Restricción | Afectados | Causa |
|---|---|---|
| `ck_hogar_cocina_notiene` | **11.448 hogares (27,9 %)** | La regla no coincide con los datos: de 11.792 hogares sin cocina, solo 344 tienen uso = 9, y son justo los que "no preparan alimentos". Los demás declaran un uso real de cocina. |
| `ck_hogar_energiacocina` | 344 hogares | `tip_energia_cocina = 9` no está en el diccionario. Son exactamente los mismos 344 hogares. |
| `ck_personaingreso_valor` | 2.696 personas | Efecto del modelo: la fuente 9 (subsidio agregado) tiene indicador pero no valor. |
| `ck_personarelacion_flag` | 455 personas | `ind_conyuge_vive_hogar = 0` (18) e `ind_padre_vive_hogar = 0` (437) no están en el catálogo. |
| `ck_personarelacion_referencia` | 263 personas | Indicador "sí" con número de orden 0 o fuera de rango. |
| Una persona con varios indicadores en 0 | 1 persona | Viola 7 restricciones a la vez. |

Además, `ind_ingr_estado` es un solo indicador para tres valores (Familias en Acción, Colombia Mayor y otros). Las fuentes 10 a 12 no tienen indicador propio, y 192 personas tienen `9` como valor en algún subsidio, lo que parece un código, no 9 pesos.

### ¿Cuánto bloquea cada causa?

Si un hogar con cualquier violación no pudiera entrar (con centinelas ya convertidos):

| Escenario | Hogares afectados | Personas |
|---|---|---|
| Todas las restricciones tal como están | **15.053 (36,7 %)** | 34.043 |
| Sin la regla de cocina | 4.646 (11,3 %) | 11.845 |
| Y resolviendo la fuente 9 de ingresos | 2.481 (6,0 %) | 5.653 |
| Y aceptando `tip_energia_cocina = 9` | 2.155 (5,3 %) | 5.217 |
| Y resolviendo territorio rural | 772 (1,9 %) | 1.965 |
| Y resolviendo indicadores 0 y referencias | **171 (0,4 %)** | 569 |

Solo con una carga estricta, sin esas decisiones, no entraría más de un tercio de los hogares. La mayoría de esos casos no son errores de la encuesta, sino diferencias entre el modelo y el archivo real.

## 7. Centinelas: el archivo no usa nulos

Excepto las tres columnas de código territorial, ninguna celda viene vacía. Lo que debería ser nulo viene como código, y el DDL exige `NULL`.

| Columna | Valor en el archivo | El DDL exige | Violaciones literales | Tras convertir |
|---|---|---|---|---|
| `num_dias_llega` | 9 | `NULL` | 40.562 hogares | 4 |
| `num_horas_llega` | 99 | `NULL` | 40.797 hogares | 0 |
| `num_evento_*` | 0 | `NULL` | 242.065 filas | 0 |
| `ide_conyuge`, `ide_padre`, `ide_serv_domestico` | 99 o 0 | `NULL` | No se pueden insertar | — |

La ficha también dice "en otro caso nulo". Sin esta conversión no entra prácticamente ningún hogar.

**Decisión tomada: se convierten a `NULL`, con estas condiciones.**

- **Solo cuando el indicador dice que no aplica.** `num_dias_llega = 9` se convierte si `ind_agua_llega_7dias ≠ 2`; `num_horas_llega = 99`, si `ind_agua_llega_24horas ≠ 2`; y `num_evento_* = 0`, si el indicador del evento es 2.
- **Esa condición es necesaria.** Si se convirtiera todo sin mirar el indicador, los 4 hogares con `ind_agua_llega_7dias = 2` y `num_dias_llega = 9` quedarían con `NULL`. El CHECK lo aceptaría, porque una condición con `NULL` no se considera violada, y el error desaparecería en silencio. Con la condición, esos 4 hogares se siguen reportando.
- **`ide_conyuge`, `ide_padre` e `ide_serv_domestico`:** 99 y 0 pasan a `NULL` siempre, porque no pueden ser número de orden. Si el indicador dice "sí" y no queda referencia, la fila se reporta (`ck_personarelacion_referencia`).
- **Sin otras conversiones.** Los ceros de `vlr_*` se conservan, porque el CHECK los admite.
- **Queda constancia.** La lista de reglas de conversión va en `settings.py`, y la cantidad de valores convertidos se imprime en el resumen `stats`.

## 8. Notas de calidad ya documentadas

La ficha ya registra correctamente estos errores del diccionario oficial:

- Descripciones desplazadas en cuatro variables de discapacidad.
- `vlr_ingr_pension` con la descripción de cosecha.
- `ind_tiene_acueducto` con pregunta 2 en lugar de 20.

Otros hechos del archivo:

- Todas las columnas llegan como texto.
- `cod_dpto` viene como `05`, aunque `Diccionario.xlsx` dice `5`.
- Los valores monetarios no traen decimales.
- `ind_pariente_domestico` e `ide_serv_domestico` son constantes (2 y 99).
- Hay 124 filas idénticas a otra en las 151 columnas. **No conviene borrarlas:** casi todos los hogares cuadran con ellas incluidas, de modo que pueden ser personas reales, como gemelos. No se revisaron una a una.

El conjunto es **confidencial** y contiene datos sensibles según la ficha (Ley 1581 de 2012): salud, discapacidad, embarazo e ingresos. Este documento solo trae cifras agregadas y números de fila.
