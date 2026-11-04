# 03 — Plan del migrador SISBÉN IV

Este plan se apoya en `01-patrones-detallado-alumnos.md` y `02-modelo-destino.md`.

**La app ya está construida y probada** contra un SQL Server 2022 local y temporal, con el Excel real. Aún no se ha ejecutado en el servidor de la Alcaldía.

## Decisiones finales

Las preguntas de la sección 6 quedan cerradas con esta tabla. Tú decidiste las primeras; el resto las tomé yo cuando pediste no preguntar más, y **puedes cambiarlas**. La última columna dice dónde.

| # | Tema | Decisión | Quién | Dónde se cambia |
|---|---|---|---|---|
| 1 | Motor | SQL Server | Tú | |
| 2 | Archivo | El anonimizado es la única fuente | Tú | |
| 3 | Patrón de BD | Tomado de `mvp_etl_upload_to_bd` | Tú | |
| 7 | Centinelas | A `NULL`, solo cuando el indicador dice que no aplica | Tú | `CENTINELAS` en `settings.py` |
| 8 | Errores | Apartar el hogar completo y seguir | Tú | `validators.py` |
| 4 | `idhogar` | `idvivienda-ide_hogar` | Yo | `construir_viviendas` |
| 5 | `idvivienda` | Criterio C: 1 hogar si declara 1; si no, firma e `ide_hogar` | Yo | `construir_viviendas` |
| 6 | `qtordenpersona` | Opción C: se deduce de las referencias. Opción B dejaba mal ~10 % de las parejas sin ningún aviso | Yo | `rules.py` |
| 6 | `idpersona` | Lo asigna Python; `BIGINT` sin `IDENTITY` | Yo | `run_tablas` |
| 8 | Reglas sin CHECK | Las estructurales excluyen; las reglas 17 y 18 solo avisan | Yo | `detectar_avisos` |
| 9 | Fuente 9 | Valor nulo, para no duplicar sumas | Yo | `GRUPOS_INGRESO` y el CHECK |
| 9 | Fuentes 10–12 | Heredan el indicador agregado. **Para saber quién recibió cada subsidio, mirar `mningreso > 0`** | Yo | `GRUPOS_INGRESO` |
| 10 | Filas | Grilla completa | Yo | `girar_grupo` |
| 11 | Recarga | Reemplazo total, sin histórico | Yo | `cargar_tablas` |
| 12 | Nombres enmascarados | Se cargan como valores. `BARRIO_S4` rural pasa a nulo | Yo | `asignar_territorio` |
| 13 | Rural sin vereda ni corregimiento | Se cargan con aviso; se retira `ck_vivienda_territorio_rural` | Yo | `sql/01_...` |
| 14 | `dimVereda.cdcorregimiento` | Nulo | Yo | `insertar_dimensiones` |
| 15 | DDL | Archivos nuevos en `sql/`; `insumos/` intacto. Sin `ON UPDATE CASCADE` | Yo | `sql/` |
| 16 | Regla de cocina | Se retira el CHECK; queda como aviso | Yo | `sql/01_...` |
| 17 | `tip_energia_cocina = 9` | Válido: se agrega al CHECK y al catálogo | Yo | `sql/`, `CATALOGOS` |
| 18 | Indicador 0 en cónyuge y padre | Fuera de catálogo: excluye el hogar | Yo | `CATALOGOS` |
| 19 | Reglas 17 y 18 | Solo avisos. Con la 17 se perderían 8.042 hogares, y el archivo no la sigue | Yo | `detectar_avisos` |
| 20 | Nombres | `05` Antioquia y `05615` Rionegro | Yo | `settings.py` |
| 21 | Tildes | Se conservan | Yo | |
| 22 | `EL PROGESO ` | Se quita el espacio; el nombre no se corrige | Yo | `limpiar_nombres` |
| 23 | 13 grupos y edad 125 | Excluidos | Yo | `validators.py` |
| 24 | Servidor | Base `sisbeniv`, esquema `dbo`, nombres del DDL | Yo | `sql/`, `.env` |
| 25 | Pruebas | Imagen Docker oficial de SQL Server 2022 | Yo | |

**Pendiente de la regla 23:** no se valida el cálculo ponderado de `H_5` porque los pesos no están en los insumos. Hoy coincide en todos los hogares con los pesos estándar del DANE.

## Resultado con el archivo real

| Medida | Valor |
|---|---|
| Hogares reconstruidos | 41.016 |
| Hogares cargados | **40.224 (98,1 %)** |
| Hogares apartados | **792 (1,9 %), 2.043 personas** |
| Viviendas cargadas | 38.917 |
| Personas cargadas | 102.249 |
| Filas insertadas, sin contar dimensiones | 3.699.613 |
| Tiempo total | 5 minutos |
| Avisos, sin excluir datos | 26.530 |

**Corrección de una cifra anterior:** antes te dije que se perderían unos 171 hogares. Esa cifra suponía resolver también los indicadores en 0 y las referencias incompletas, que aquí son incoherencias reales de los datos, y no contaba los 10 hogares con referencias imposibles. Con las decisiones de esta tabla son **792**.

| Prueba en SQL Server 2022 | Resultado |
|---|---|
| Esquema: 16 tablas, 92 CHECK, 18 llaves, 281 valores de catálogo | ✅ |
| El motor no rechazó ninguna fila | ✅ Python y los CHECK coinciden |
| Repetir la carga | ✅ Sin duplicados y con los mismos códigos |
| Error forzado en la fila 500.123 de `PersonaIngreso` | ✅ Fila señalada, reversión total, base intacta |
| Archivo con otra forma | ✅ Se detiene (25,69 % frente al mínimo de 99 %) |
| Valores basura o vacíos | ✅ Reportados con su fila y motivo |
| Suma de gastos e ingresos, y hogares IPM, frente al Excel | ✅ Coinciden exactamente |
| Un jefe por hogar, personas = conteo, relaciones dentro del hogar | ✅ 0 excepciones |
| Cónyuges recíprocos | ✅ 0 excepciones |

**Límites de estas pruebas:** el servidor fue un SQL Server 2022 Developer en emulación, no el de la Alcaldía. La base de prueba ocupó 5,3 GB tras tres cargas. Y en 1.158 hogares cargados, el orden de personas tiene más de una solución válida: la relación padre/madre elegida puede ser la otra. Esos hogares están en `avisos_*`.

---

## 1. Árbol de la app, en paralelo con detallado-alumnos

```
migrador-sisben/
├── main.py                              ← main.py
├── requirements.txt                     ← requirements.txt (+ SQLAlchemy y pyodbc)
├── README.md                            ← README.md (+ cómo ejecutarlo)
├── .gitignore                           ← .gitignore (+ .env y venv)
├── .env.template                        ✚ sin equivalente; viene de mvp_etl_upload_to_bd
├── sql/                                 ✚ DDL y catálogos para SQL Server
├── app/
│   ├── config/
│   │   └── settings.py                  ← settings.py (rutas, columnas por nivel, grupos repetidos)
│   ├── application/
│   │   └── etl_pipeline.py              ← etl_pipeline.py (run_migracion)
│   ├── domain/
│   │   ├── rules.py                     ← rules.py (construir hogares, viviendas, orden, girar columnas)
│   │   └── validators.py                ← validators.py (detectar_filas_corruptas y reglas)
│   ├── infrastructure/
│   │   ├── loaders.py                   ← loaders.py (idéntico)
│   │   ├── corrupt_exporter.py          ← corrupt_exporter.py (mismo formato de salida)
│   │   ├── database.py                  ✚ sin equivalente; viene de mvp_etl_upload_to_bd
│   │   └── repositories.py              ✚ sin equivalente; viene de mvp_etl_upload_to_bd
│   └── utils/
│       └── dataframe_utils.py           ← dataframe_utils.py (clean_columns, normalize_nulls)
├── output/                              ← output/ (corruptas_*, fuera de git)
├── insumos/                             Ya existe; contiene el Excel de entrada (hace de data/)
└── docs/                                Estos documentos
```

`exporters.py` no tiene correspondencia directa, porque el destino es la base de datos. Solo haría falta si quieres un Parquet de control con las tablas ya transformadas (observación 9).

Flujo de `main.py`, en el mismo estilo lineal:

| Paso | Función | Procedencia |
|---|---|---|
| Leyendo archivo... | `load_file` | detallado |
| Limpiando columnas... | `clean_columns` | detallado |
| Normalizando nulls... | `normalize_nulls` | detallado |
| Detectando filas corruptas... | `detectar_filas_corruptas` + `export_corruptas` | detallado, ampliada |
| Construyendo hogares y viviendas... | `run_migracion` → `rules.py` | nueva |
| Girando grupos repetidos... | `rules.py` | nueva |
| Insertando en la base de datos... | `repositories.py` | mvp, ajustada |
| ETL finalizado | `print` de `stats` | detallado |

## 2. Orden de carga

Las llaves foráneas exigen que la fila referenciada exista antes. El orden sale directamente del DDL:

| # | Tablas | Por qué en este orden |
|---|---|---|
| 1 | `catDominio`, `catDominioValor` | No dependen de nada. Las carga `02_sisben_iv_catalogos.sql`. |
| 2 | `dimDepartamento` | Raíz territorial. |
| 3 | `dimMunicipio` | Depende del departamento. |
| 4 | `dimCorregimiento` | Depende del municipio. |
| 5 | `dimVereda`, `dimBarrio` | Dependen de corregimiento y municipio. |
| 6 | `Vivienda` | Depende de las dimensiones. |
| 7 | `Hogar` | Depende de `Vivienda`. |
| 8 | `HogarGasto`, `HogarEvento`, `HogarPrivacionIpm` | Dependen de `Hogar`. |
| 9 | `Persona` | Depende de `Hogar`. |
| 10 | `PersonaDiscapacidad`, `PersonaIngreso` | Dependen de `Persona`. |
| 11 | `PersonaRelacion` | **Al final:** apunta a `Persona` dos veces, así que necesita a todas las personas cargadas. |

## 3. Grupos repetidos: de columnas a filas

Cada grupo se declara como lista en `settings.py`, al estilo de `COLUMNAS_POR_ESTUDIANTE`, y una sola función los gira todos. Agregar o corregir un rubro no requiere tocar la lógica.

| Tabla | Columnas | Filas por registro | Código | Particularidades |
|---|---|---|---|---|
| `HogarGasto` | 16 (8 pares `ind_gasto_*` / `vlr_gasto_*`) | 8 por hogar | `cdrubrogasto` 1–8 | Sin problemas: 0 violaciones. |
| `HogarEvento` | 12 (6 pares) | 6 por hogar | `cdtipoevento` 1–6 | `num_evento = 0` debe pasar a `NULL` (pregunta 7). Ojo: `Num_evento_vendaval` viene con mayúscula. |
| `HogarPrivacionIpm` | 15 (`I1`–`I15`) | 15 por hogar | `cdprivacionipm` 1–15 | Directo: el número sale del nombre de la columna. |
| `PersonaDiscapacidad` | 8 (`ind_discap_*`) | 8 por persona | `cdtipodiscapacidad` 1–8 | Directo. `ind_discap_bañarse` lleva ñ. |
| `PersonaRelacion` | 6 (3 pares) | 3 por persona | `cdtiporelacion` 1–3 | Depende de `qtordenpersona` (pregunta 6). Los pares vienen como indicador + número de orden, y hay que traducirlo a `idpersona`. |
| `PersonaIngreso` | 21 | 12 por persona | `cdfuenteingreso` 1–12 | Es el caso difícil; ver abajo. |

**`PersonaIngreso` no es un giro limpio:**

- Las fuentes 1, 2 y 4 a 8 son pares normales.
- La fuente 3 (cosecha) tiene tres columnas: indicador, meses y valor.
- La fuente 9 (subsidio agregado) tiene indicador, pero no valor. Con el CHECK actual, falla para 2.696 personas.
- Las fuentes 10 a 12 tienen valor, pero no indicador propio.

Ver pregunta 9.

**Grilla completa o solo positivos:** el diagrama ER marca `1:0..8` en gastos, pero `1:15` en privaciones. No es claro si un "No" debe generar fila (pregunta 10).

## 4. Qué pasa cuando una fila viola una restricción

`detallado-alumnos` **aparta la fila mala y sigue**. Tu instrucción para el migrador es que **la carga debe fallar y decirte cuál fila y por qué**. Se resolvió en dos etapas, con la opción B de esta sección:

**Etapa 1. Validar antes de tocar la base de datos.** `detectar_filas_corruptas` revisa las 104.292 filas con todas las reglas, incluidas las que no pueden ser CHECK, y reúne **todos** los errores de una vez. `export_corruptas` escribe `output/corruptas_{timestamp}.json` y `.csv`, y cada registro lleva:

| Campo | Ejemplo |
|---|---|
| Fila de Excel | `26745` |
| Hogar reconstruido | `10234-1` |
| Regla o restricción | `ck_hogar_diasagua` |
| Motivo legible | `fgaguasietedias = 2 y qtdiasllegaagua = 9` |

Los hogares con error se apartan y el proceso sigue (decisión 8).

La ventaja es grande: SQL Server se detiene en el primer error, mientras que Python puede informarlos todos de una vez.

**Etapa 2. Insertar en una sola transacción.** Si la validación pasa, se inserta todo por lotes dentro de una transacción. Las restricciones nunca se desactivan. Si el motor rechaza algo que Python no anticipó, se hace `ROLLBACK`, y se usa el aislamiento fila por fila de `mvp_etl_upload_to_bd` para informar cuál fila falló, con el mensaje del motor. La base queda como estaba.

**La unidad de rechazo es el hogar completo.** Si una persona se rechaza, `num_personas_hogar` deja de coincidir y las referencias entre personas se rompen.

Opciones para los casos en que sí haya errores (pregunta 8):

| Opción | Comportamiento | Coherencia |
|---|---|---|
| A. Todo o nada | Un solo error detiene la carga | Tu instrucción literal |
| B. Apartar y seguir | Se excluyen los hogares con error y se carga el resto | El patrón de detallado-alumnos |
| C. Umbral | Se aparta hasta cierto porcentaje; si se supera, se detiene | Intermedia, pero introduce una regla nueva |

**Consecuencia de la opción A:** aun resolviendo todas las diferencias entre el modelo y el archivo, quedan **171 hogares (569 personas)** con incoherencias propias de los datos. Esos datos no se pueden corregir: el archivo es la única fuente y la app no debe arreglarlos. Con la opción A, este archivo nunca terminaría de cargar.

**Con la opción B no se pierde el aviso:** cada hogar excluido queda en `corruptas_*` con su fila y su motivo, y `main.py` imprime el total. La carga no se detiene, pero sigue diciendo cuál fila y por qué.

## 5. Volver a correr la migración sin duplicar datos

**Por qué un "insertar si no existe" no sirve aquí:** el archivo no tiene claves reales. Un hogar del corte de enero y el mismo hogar del corte de julio no se pueden reconocer como el mismo. Por eso, una actualización fila a fila no es posible.

**Propuesta: reemplazo total dentro de una transacción.**

1. Abrir la transacción.
2. Borrar `PersonaRelacion` primero.
3. Borrar `Vivienda`; la cascada elimina hogares, personas y sus detalles.
4. Insertar de nuevo en el orden de la sección 2.
5. Confirmar. Si algo falla, `ROLLBACK` y los datos anteriores siguen intactos.

Requisitos y precauciones:

- **El paso 2 es obligatorio.** En la prueba con MySQL, `DELETE FROM Vivienda` falló con error 1451 porque `PersonaRelacion` bloquea el borrado de `Persona`. Esa prueba usó la copia corregida del DDL, pero el DDL original tiene el mismo tipo de bloqueo en `fk_personarelacion_relacionada` (`ON DELETE RESTRICT`).
- **En SQL Server se mantiene el mismo orden de borrado:** `fk_personarelacion_relacionada` quedará como `NO ACTION`, que bloquea igual.
- **El registro de transacciones crecerá.** Borrar e insertar 3,7 millones de filas en una sola transacción consume espacio en el servidor. No se ha medido; hay que comprobarlo en el servidor de pruebas (pregunta 25).
- **`01_sisben_iv_schema.sql` no debe volver a ejecutarse en producción:** empieza con `DROP TABLE` en todas las tablas y borra todo. La versión para SQL Server debe evitar eso.
- **Las dimensiones no se reemplazan.** Si se generan códigos de barrio o vereda, deben quedar iguales entre cargas. Se insertan solo los nombres nuevos.
- **`02_sisben_iv_catalogos.sql` es seguro de repetir**, porque hace `DELETE` y luego `INSERT`.
- **El reemplazo total borra el corte anterior.** Si necesitas histórico, hay que agregar una columna de corte al modelo (pregunta 11).
- **Criterio de vivienda:** si eliges el C, un Excel reordenado produce emparejamientos distintos.

---

## 6. Preguntas

✅ Todas cerradas: las respuestas están en "Decisiones finales", al inicio de este documento. Se conservan como registro.

### Bloqueantes: sin estas no se puede programar

**1. ¿El destino es SQL Server o MySQL?** ✅ Resuelta: **SQL Server**.

**2. ¿Existe una versión del archivo con claves y códigos reales?** ✅ Resuelta: **no existe**. Las preguntas 4, 5, 6 y 12 deben resolverse con lo que trae el archivo anonimizado.

**3. ¿Autorizas tomar `database.py`, `repositories.py` y `.env` de `mvp_etl_upload_to_bd` como patrón?** ✅ Resuelta: **sí**. Se agregan SQLAlchemy 2.0.46 y pyodbc 5.3.0, y quien ejecute la app necesitará ODBC Driver 17.

**4. ¿Qué formato tendrá `idhogar`?** A `idvivienda-ide_hogar`, B consecutivo, o C clave sustituta con columna nueva. Sección 4.3 del documento 02.

**5. ¿Qué criterio usamos para `idvivienda`?** A: 1 hogar = 1 vivienda (41.016). B: firma exacta (11.705). C: declaración + firma + `ide_hogar` (39.648). Sección 4.4 del documento 02. No elijo.

**6. ¿Qué hacemos con `qtordenpersona`?** A: orden del archivo. B: parentesco y archivo. C: deducción. D: guardar el número declarado sin resolver a persona. Sección 4.6 del documento 02. También falta definir quién genera `idpersona`: Python o el motor. Sección 4.5.

**7. ¿Autorizas convertir centinelas a `NULL`?** ✅ Resuelta: **sí**, solo cuando el indicador dice que no aplica, para que los casos contradictorios se sigan reportando. Reglas exactas en la sección 7 del documento 02.

**8. ¿Cuál es la política ante errores?** A todo o nada, B apartar y seguir, C umbral (sección 4). Recomiendo B: con A este archivo no terminaría de cargar nunca, por los 171 hogares con incoherencias propias. Falta definir también qué hacer con las reglas sin CHECK: ¿bloquean o solo avisan?

**9. ¿Cómo se modelan los subsidios en `PersonaIngreso`?** Para la fuente 9: ¿valor nulo (exige ajustar el CHECK), suma de las fuentes 10 a 12, o eliminar la fuente? Para las fuentes 10 a 12: ¿heredan el indicador de `ind_ingr_estado`? ¿Y el valor `9` en 192 personas es un código o son 9 pesos?

**10. ¿Se crea fila también cuando la respuesta es "No"?** Grilla completa (3,7 millones de filas, sin pérdida) o solo positivos (menos filas, pero mezcla "No" con "sin dato").

**11. ¿Cada carga reemplaza a la anterior o se conserva histórico?** La frecuencia declarada es de 6 meses. Conservar histórico exige una columna de corte en el modelo.

**24. ¿Cómo es el SQL Server de destino?** Hace falta saber la versión, si la base ya existe y cómo se llama, en qué esquema van las tablas (`dbo` u otro), quién las crea y qué intercalación usa, para conservar tildes y ñ. También, si las 16 tablas se quedan con los nombres del DDL: `mvp_etl_upload_to_bd` escribe en una tabla llamada `edc001001`, un formato muy distinto.

**25. ¿Dónde probamos el DDL traducido y las cargas?** Hay dos caminos: un servidor o una base de pruebas de la Alcaldía, o autorizar la descarga de la imagen Docker de SQL Server en este equipo. Sin una de las dos, nada de lo específico de SQL Server se puede verificar antes de producción.

### Sobre el DDL y las reglas

**12. ¿Cómo tratamos los nombres enmascarados?** Como no hay códigos reales, se generarán códigos internos a partir de los nombres, conservándolos entre cargas. Falta saber qué significan `BARRIO_S4`, `CORREGIMIENTO_S4` y `NO USAR`, y si se cargan como valores o como nulos. Si son nulos, 12.759 personas de cabecera violarían `ck_vivienda_territorio_urbano`.

**13. ¿Qué hacemos con las 1.409 viviendas rurales sin vereda ni corregimiento?** Fallan `ck_vivienda_territorio_rural`. ¿Se flexibiliza la restricción o se rechazan?

**14. ¿`dimVereda.cdcorregimiento` queda nulo?** Es lo único coherente con los datos, porque cada vereda aparece con varios corregimientos. ¿O hay una tabla oficial de veredas por corregimiento?

**15. ¿Autorizas crear una versión del DDL para SQL Server?** Sería un archivo nuevo, sin tocar `01_sisben_iv_schema.sql`, con la traducción de la sección 3.2 del documento 02. Recomiendo quitar los 18 `ON UPDATE CASCADE`: los códigos y las claves generadas no cambian, y evita las rutas múltiples de cascada. Los 8 `ON DELETE CASCADE` se conservarían, porque sirven para la recarga. Los nombres de tablas y columnas no cambian.

**16. ¿La regla de cocina está bien?** `fgcocina = 2 → cdusococina = 9` falla en 11.448 hogares. Los datos sugieren que el 9 se aplica cuando "no preparan alimentos". Conviene verificarlo contra el formulario de la encuesta. Afecta el 27,9 % de los hogares.

**17. ¿`tip_energia_cocina = 9` es válido?** No está en el diccionario, pero aparece en 344 hogares, justo los que no preparan alimentos. Si es válido, hay que ajustar el CHECK y agregarlo al catálogo.

**18. ¿Qué significa el indicador `0` en `ind_conyuge_vive_hogar` (18) e `ind_padre_vive_hogar` (437)?** No está en el catálogo.

**19. ¿Las reglas 17 y 18 se exigen literalmente?** 9.797 menores de 8 años tienen `fgingreso` distinto de 99, y 2.264 personas no cumplen los ejemplos de grado y nivel. La regla 18 dice "p. ej.", así que no está claro que sea estricta.

**20. ¿Confirmas que `05615` es Rionegro?** Recomiendo `{"05": "Antioquia"}` y `{"05615": "Rionegro"}` como constantes en `settings.py`.

### De detalle

**21. ¿Los nombres territoriales conservan las tildes?** `normalize_text` de detallado-alumnos las quita (`JOSÉ` → `JOSE`), pero el destino admite UTF-8.

**22. ¿Se limpia `EL PROGESO `?** Tiene un espacio final y parece un error de digitación. Quitar el espacio es inocuo; corregir el nombre sería arreglar datos.

**23. ¿Qué hacemos con los 13 grupos inconsistentes (28 filas) y las 2 personas de 125 años?** Sus filas están listadas en la sección 4.2 del documento 02.

---

## 7. Observaciones sobre el patrón de detallado-alumnos

No se cambió nada por cuenta propia. Cada punto queda a tu decisión.

| # | Patrón actual | Por qué es flojo aquí | Recomendación |
|---|---|---|---|
| 1 | `row["__errores__"]` dentro de `apply` | **Error confirmado:** el motivo se pierde. Hoy se sabe qué fila falló, pero no por qué. | ✅ Corregido en el migrador: los motivos van en un diccionario aparte. Sigue sin corregir en detallado-alumnos y `mvp_etl_upload_to_bd`. |
| 2 | `print` como único registro | Si una carga falla de madrugada, o la corre otra persona, no queda rastro. | Mantener `print` y agregar opcionalmente una copia en `output/`. Es lo más cercano al patrón sin cambiarlo. |
| 3 | Sin base de datos | La plantilla no cubre la pieza central del migrador. | ✅ Decidido: se toma de `mvp_etl_upload_to_bd`. |
| 4 | Commit por lote (en mvp) | Un fallo intermedio deja la carga a medias. | Una sola transacción. |
| 5 | Recorte y `except:` sin tipo (en mvp) | Cambia datos en silencio: `val[:1000]`, `str(v)[:1]`, valores a `None`. | **No copiar.** Contradice tu requisito. |
| 6 | Conexión al importar (en mvp) | Si falla, solo imprime y sigue. | Conservar el `SELECT 1`, pero detener el proceso si falla. |
| 7 | `df.apply(axis=1)` | Podía ser lento en 104.292 filas. | ✅ Medido: toda la validación cabe en una corrida de 5 minutos. Se conserva el patrón. |
| 8 | Sin pruebas | La reconstrucción de claves es lógica nueva y delicada. Un error no daría fallo: daría cifras equivocadas. | Agregar unas pocas verificaciones en el mismo flujo: número de hogares, jefes, total de filas por tabla. Una librería de pruebas sería una dependencia adicional. |
| 9 | Lectura lenta en cada corrida | `read_excel` tarda 70 segundos. | Aceptable. Si se necesita iterar mucho, guardar una copia Parquet: pyarrow ya está en el proyecto. |
| 10 | `.gitignore` excluye `/env`, no `.env` | La contraseña de la base podría terminar en git. | Excluir `.env` y `venv/`, como en `mvp_etl_upload_to_bd`. |
| 11 | `corruptas_*` guarda la fila completa | Aquí incluiría salud, embarazo e ingresos, en archivos planos (Ley 1581 de 2012). | ✅ `corruptas_*` guarda solo fila de Excel, claves generadas y motivo. `output/` queda fuera de git. |
| 12 | `completar_por_grupo` | Rellena nulos deduciéndolos, lo contrario de lo que pides. | No traerlo a esta app. |
| 13 | `select_dtypes(include=["object"])` | En pandas 3.0 funciona, pero emite una advertencia de obsolescencia (`Pandas4Warning`); dejará de incluir textos. | Solo importa si se usa `normalize_text` (pregunta 21). |
| 14 | Rutas relativas | `python main.py` solo funciona desde la raíz. | Mantenerlo y documentarlo en el README. |
| 15 | Detalles menores | Imports sin usar, `import unicodedata` duplicado, comentario `# untils/...`. | No replicarlos. |
| 16 | Métricas solo informativas (`stats`) | La reconstrucción depende de la forma del archivo. Si un corte futuro llega distinto, por ejemplo con otra anonimización, podría generar hogares falsos sin ningún error. | Convertir la métrica en control: imprimir el porcentaje de hogares que cuadran (hoy 41.003 de 41.016) y detener la carga si cae por debajo de un mínimo que tú definas. |
