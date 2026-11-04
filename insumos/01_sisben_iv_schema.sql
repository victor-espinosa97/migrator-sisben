-- =====================================================================
-- SISBÉN IV — Esquema relacional derivado del diccionario de datos
-- Fuente      : Diccionario.xlsx (151 variables)
-- Modelo      : Sisben_iv_modelo_ER.png (3FN)
-- Nomenclatura: estándar Riodata
-- Motor       : MySQL 8.0.16+ / MariaDB 10.5+ (InnoDB, utf8mb4)
-- Organización: Subsecretaría de Sistemas de Información Territorial
--               Observatorio Municipal de Rionegro
-- =====================================================================
--
-- MAPEO DE TIPOS (diccionario -> motor)
--   VARCHAR(n)     -> VARCHAR(n)
--   INT(1), INT(2) -> TINYINT UNSIGNED        (0–255)
--   INT(3)         -> SMALLINT UNSIGNED       (0–65535)
--   INT(4), INT(6) -> INT UNSIGNED
--   DOUBLE(15,2)   -> DECIMAL(15,2)
--
-- Nota sobre DECIMAL: el diccionario declara DOUBLE(15,2) para los campos
-- monetarios (prefijo mn). Se implementan como DECIMAL porque DOUBLE es
-- punto flotante binario y pierde exactitud al sumar pesos. DECIMAL(15,2)
-- conserva la misma longitud declarada y es exacto.
--
-- Nota sobre los catálogos: los códigos se validan con CHECK en cada
-- tabla, no con llave foránea a catDominioValor. Un CHECK es más estricto
-- (no depende de que el catálogo esté poblado) y evita 25 llaves foráneas
-- compuestas con literales, que MySQL no soporta sin columnas generadas.
-- catDominioValor es la capa de etiquetado para Power BI.
--
-- Nota sobre las claves sustitutas: idvivienda, idpersona y qtordenpersona
-- NO existen en el archivo fuente; se generan en la carga. idhogar es la
-- única clave real del archivo.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS sisbeniv
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE sisbeniv;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS PersonaIngreso;
DROP TABLE IF EXISTS PersonaDiscapacidad;
DROP TABLE IF EXISTS PersonaRelacion;
DROP TABLE IF EXISTS Persona;
DROP TABLE IF EXISTS HogarPrivacionIpm;
DROP TABLE IF EXISTS HogarEvento;
DROP TABLE IF EXISTS HogarGasto;
DROP TABLE IF EXISTS Hogar;
DROP TABLE IF EXISTS Vivienda;
DROP TABLE IF EXISTS dimBarrio;
DROP TABLE IF EXISTS dimVereda;
DROP TABLE IF EXISTS dimCorregimiento;
DROP TABLE IF EXISTS dimMunicipio;
DROP TABLE IF EXISTS dimDepartamento;
DROP TABLE IF EXISTS catDominioValor;
DROP TABLE IF EXISTS catDominio;

SET FOREIGN_KEY_CHECKS = 1;


-- =====================================================================
-- 1. CATÁLOGOS PARAMÉTRICOS
--    Reemplazan la columna «Valores» del diccionario. Un solo par de
--    tablas para los 31 dominios de codificación del conjunto.
-- =====================================================================

CREATE TABLE catDominio (
  cddominio    VARCHAR(30)  NOT NULL  COMMENT 'Código del dominio de codificación',
  nmdominio    VARCHAR(100) NOT NULL  COMMENT 'Nombre legible del dominio',
  dspregunta   VARCHAR(255) NULL      COMMENT 'Pregunta(s) de la encuesta que usan el dominio',
  CONSTRAINT pk_catdominio PRIMARY KEY (cddominio)
) ENGINE=InnoDB
  COMMENT='Dominios de codificación declarados en el diccionario SISBÉN IV';

CREATE TABLE catDominioValor (
  cddominio    VARCHAR(30)  NOT NULL  COMMENT 'Dominio al que pertenece el valor',
  cdvalor      VARCHAR(3)   NOT NULL  COMMENT 'Código del valor tal como viene en la base',
  dsvalor      VARCHAR(255) NOT NULL  COMMENT 'Descripción del valor',
  cdagrupacion VARCHAR(40)  NULL      COMMENT 'Agrupación superior del valor (solo clasificacionsisben)',
  fgnoaplica   TINYINT UNSIGNED NOT NULL DEFAULT 0
                                      COMMENT '1 = el valor significa «no aplica» o «no sabe»; 0 = valor sustantivo',
  CONSTRAINT pk_catdominiovalor PRIMARY KEY (cddominio, cdvalor),
  CONSTRAINT fk_catdominiovalor_dominio
    FOREIGN KEY (cddominio) REFERENCES catDominio (cddominio)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_catdominiovalor_noaplica CHECK (fgnoaplica IN (0, 1))
) ENGINE=InnoDB
  COMMENT='Valores válidos por dominio; capa de etiquetado para Power BI';

CREATE INDEX ix_catdominiovalor_agrupacion
  ON catDominioValor (cddominio, cdagrupacion);


-- =====================================================================
-- 2. DIMENSIONES TERRITORIALES
--    Normalizan los 9 campos territoriales del diccionario
--    (cod_* + NOM_*) en 5 catálogos jerárquicos.
-- =====================================================================

CREATE TABLE dimDepartamento (
  cddpto         VARCHAR(2)   NOT NULL  COMMENT 'Código DANE del departamento',
  nmdepartamento VARCHAR(100) NOT NULL  COMMENT 'Nombre del departamento',
  CONSTRAINT pk_dimdepartamento PRIMARY KEY (cddpto),
  CONSTRAINT ck_dimdepartamento_cddpto CHECK (cddpto REGEXP '^[0-9]{2}$')
) ENGINE=InnoDB
  COMMENT='Catálogo DANE de departamentos';

CREATE TABLE dimMunicipio (
  cdmunicipio  VARCHAR(5)   NOT NULL  COMMENT 'Código DANE del municipio (5 dígitos)',
  cddpto       VARCHAR(2)   NOT NULL  COMMENT 'Departamento al que pertenece',
  nmmunicipio  VARCHAR(100) NOT NULL  COMMENT 'Nombre del municipio',
  CONSTRAINT pk_dimmunicipio PRIMARY KEY (cdmunicipio),
  CONSTRAINT fk_dimmunicipio_dpto
    FOREIGN KEY (cddpto) REFERENCES dimDepartamento (cddpto)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_dimmunicipio_cdmunicipio CHECK (cdmunicipio REGEXP '^[0-9]{5}$'),
  -- Regla del diccionario: el código de municipio inicia con el de departamento
  CONSTRAINT ck_dimmunicipio_prefijo CHECK (LEFT(cdmunicipio, 2) = cddpto)
) ENGINE=InnoDB
  COMMENT='Catálogo DANE de municipios';

CREATE INDEX ix_dimmunicipio_dpto ON dimMunicipio (cddpto);

CREATE TABLE dimCorregimiento (
  cdcorregimiento INT UNSIGNED NOT NULL  COMMENT 'Código del corregimiento registrado en SisbenApp',
  cdmunicipio     VARCHAR(5)   NOT NULL  COMMENT 'Municipio al que pertenece',
  nmcorregimiento VARCHAR(100) NOT NULL  COMMENT 'Nombre del corregimiento',
  CONSTRAINT pk_dimcorregimiento PRIMARY KEY (cdcorregimiento),
  CONSTRAINT fk_dimcorregimiento_municipio
    FOREIGN KEY (cdmunicipio) REFERENCES dimMunicipio (cdmunicipio)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_dimcorregimiento_codigo CHECK (cdcorregimiento BETWEEN 1 AND 9999)
) ENGINE=InnoDB
  COMMENT='Corregimientos; codificación interna SisbenApp, no DANE';

CREATE INDEX ix_dimcorregimiento_municipio ON dimCorregimiento (cdmunicipio);

CREATE TABLE dimVereda (
  cdvereda        INT UNSIGNED NOT NULL  COMMENT 'Código de la vereda registrado en SisbenApp',
  cdcorregimiento INT UNSIGNED NULL      COMMENT 'Corregimiento al que pertenece; nulo si la vereda no está adscrita a uno',
  nmvereda        VARCHAR(100) NOT NULL  COMMENT 'Nombre de la vereda',
  CONSTRAINT pk_dimvereda PRIMARY KEY (cdvereda),
  CONSTRAINT fk_dimvereda_corregimiento
    FOREIGN KEY (cdcorregimiento) REFERENCES dimCorregimiento (cdcorregimiento)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_dimvereda_codigo CHECK (cdvereda BETWEEN 1 AND 999999)
) ENGINE=InnoDB
  COMMENT='Veredas; codificación interna SisbenApp, no DANE';

CREATE INDEX ix_dimvereda_corregimiento ON dimVereda (cdcorregimiento);

CREATE TABLE dimBarrio (
  cdbarrio    INT UNSIGNED NOT NULL  COMMENT 'Código del barrio registrado en SisbenApp',
  cdmunicipio VARCHAR(5)   NOT NULL  COMMENT 'Municipio al que pertenece',
  nmbarrio    VARCHAR(100) NOT NULL  COMMENT 'Nombre del barrio',
  CONSTRAINT pk_dimbarrio PRIMARY KEY (cdbarrio),
  CONSTRAINT fk_dimbarrio_municipio
    FOREIGN KEY (cdmunicipio) REFERENCES dimMunicipio (cdmunicipio)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_dimbarrio_codigo CHECK (cdbarrio BETWEEN 1 AND 999999)
) ENGINE=InnoDB
  COMMENT='Barrios; codificación interna SisbenApp, no DANE';

CREATE INDEX ix_dimbarrio_municipio ON dimBarrio (cdmunicipio);


-- =====================================================================
-- 3. VIVIENDA  (21 variables del diccionario)
--    9 territoriales -> 5 llaves foráneas + dimensiones
--    12 propias de la vivienda
-- =====================================================================

CREATE TABLE Vivienda (
  idvivienda            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT
                        COMMENT 'Clave sustituta; NO viene en el archivo fuente',
  cdmunicipio           VARCHAR(5)       NOT NULL
                        COMMENT 'cod_mpio — código DANE del municipio',
  cdclase               TINYINT UNSIGNED NOT NULL
                        COMMENT 'Cod_clase — 1 Cabecera, 2 Centro poblado, 3 Rural disperso',
  cdcorregimiento       INT UNSIGNED     NULL
                        COMMENT 'Cod_corregimiento — nulo en zona urbana',
  cdvereda              INT UNSIGNED     NULL
                        COMMENT 'Cod_vereda — nulo en zona urbana',
  cdbarrio              INT UNSIGNED     NULL
                        COMMENT 'Cod_barrio — nulo en zona rural',
  cdtipovivienda        TINYINT UNSIGNED NOT NULL
                        COMMENT 'tip_vivienda — pregunta 17',
  cdmaterialpared       TINYINT UNSIGNED NOT NULL
                        COMMENT 'tip_mat_paredes — pregunta 18',
  cdmaterialpiso        TINYINT UNSIGNED NOT NULL
                        COMMENT 'tip_mat_pisos — pregunta 19',
  fgenergia             TINYINT UNSIGNED NOT NULL
                        COMMENT 'ind_tiene_energia — 1 Sí, 2 No',
  cdestratoenergia      TINYINT UNSIGNED NOT NULL
                        COMMENT 'tip_estrato_energia — 0, 1–6, 9, 99',
  fgalcantarillado      TINYINT UNSIGNED NOT NULL
                        COMMENT 'ind_tiene_alcantarillado — 1 Sí, 2 No',
  fggas                 TINYINT UNSIGNED NOT NULL
                        COMMENT 'ind_tiene_gas — 1 Sí, 2 No',
  fgrecoleccionbasura   TINYINT UNSIGNED NOT NULL
                        COMMENT 'ind_tiene_recoleccion — 1 Sí, 2 No',
  fgacueducto           TINYINT UNSIGNED NOT NULL
                        COMMENT 'ind_tiene_acueducto — 1 Sí, 2 No',
  cdestratoacueducto    TINYINT UNSIGNED NOT NULL
                        COMMENT 'tip_estrato_acueducto — 0, 1–6, 9, 99',
  qtcuartosvivienda     SMALLINT UNSIGNED NOT NULL
                        COMMENT 'num_cuartos_vivienda — pregunta 21',
  qthogaresvivienda     SMALLINT UNSIGNED NOT NULL
                        COMMENT 'num_hogares_vivienda — pregunta 22',

  CONSTRAINT pk_vivienda PRIMARY KEY (idvivienda),

  CONSTRAINT fk_vivienda_municipio
    FOREIGN KEY (cdmunicipio) REFERENCES dimMunicipio (cdmunicipio)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_vivienda_corregimiento
    FOREIGN KEY (cdcorregimiento) REFERENCES dimCorregimiento (cdcorregimiento)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_vivienda_vereda
    FOREIGN KEY (cdvereda) REFERENCES dimVereda (cdvereda)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_vivienda_barrio
    FOREIGN KEY (cdbarrio) REFERENCES dimBarrio (cdbarrio)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  CONSTRAINT ck_vivienda_clase         CHECK (cdclase IN (1, 2, 3)),
  CONSTRAINT ck_vivienda_tipovivienda  CHECK (cdtipovivienda BETWEEN 1 AND 5),
  CONSTRAINT ck_vivienda_materialpared CHECK (cdmaterialpared BETWEEN 0 AND 7),
  CONSTRAINT ck_vivienda_materialpiso  CHECK (cdmaterialpiso BETWEEN 1 AND 6),
  CONSTRAINT ck_vivienda_energia       CHECK (fgenergia IN (1, 2)),
  CONSTRAINT ck_vivienda_alcantarillado CHECK (fgalcantarillado IN (1, 2)),
  CONSTRAINT ck_vivienda_gas           CHECK (fggas IN (1, 2)),
  CONSTRAINT ck_vivienda_recoleccion   CHECK (fgrecoleccionbasura IN (1, 2)),
  CONSTRAINT ck_vivienda_acueducto     CHECK (fgacueducto IN (1, 2)),
  CONSTRAINT ck_vivienda_estratoenergia
    CHECK (cdestratoenergia IN (0, 1, 2, 3, 4, 5, 6, 9, 99)),
  CONSTRAINT ck_vivienda_estratoacueducto
    CHECK (cdestratoacueducto IN (0, 1, 2, 3, 4, 5, 6, 9, 99)),
  CONSTRAINT ck_vivienda_cuartos       CHECK (qtcuartosvivienda >= 1),
  CONSTRAINT ck_vivienda_hogares       CHECK (qthogaresvivienda >= 1),

  -- Reglas de consistencia del diccionario
  CONSTRAINT ck_vivienda_estratoenergia_sinservicio
    CHECK (fgenergia <> 2 OR cdestratoenergia = 99),
  CONSTRAINT ck_vivienda_estratoacueducto_sinservicio
    CHECK (fgacueducto <> 2 OR cdestratoacueducto = 99),
  -- Clase 1 (cabecera) exige barrio; clases 2 y 3 exigen vereda o corregimiento
  CONSTRAINT ck_vivienda_territorio_urbano
    CHECK (cdclase <> 1 OR cdbarrio IS NOT NULL),
  CONSTRAINT ck_vivienda_territorio_rural
    CHECK (cdclase = 1 OR cdvereda IS NOT NULL OR cdcorregimiento IS NOT NULL)
) ENGINE=InnoDB
  COMMENT='Unidad de vivienda: ubicación, materiales y servicios públicos';

CREATE INDEX ix_vivienda_municipio ON Vivienda (cdmunicipio);
CREATE INDEX ix_vivienda_barrio    ON Vivienda (cdbarrio);
CREATE INDEX ix_vivienda_vereda    ON Vivienda (cdvereda);
CREATE INDEX ix_vivienda_clase     ON Vivienda (cdclase);


-- =====================================================================
-- 4. HOGAR  (32 variables del diccionario)
-- =====================================================================

CREATE TABLE Hogar (
  idhogar                    VARCHAR(20)      NOT NULL
                             COMMENT 'ide_hogar — única clave real del archivo fuente',
  idvivienda                 BIGINT UNSIGNED  NOT NULL
                             COMMENT 'Vivienda que ocupa el hogar',

  -- Ocupación y permanencia
  cdocupacionvivienda        TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_ocupa_vivienda — pregunta 24',
  cdtiempohabitavivienda     TINYINT UNSIGNED NOT NULL
                             COMMENT 'num_habita_vivienda — código de rango 1–4, pregunta 42',

  -- Cuartos
  qtcuartosexclusivos        SMALLINT UNSIGNED NOT NULL
                             COMMENT 'num_cuartos_exclusivos — pregunta 25',
  qtcuartosdormir            SMALLINT UNSIGNED NOT NULL
                             COMMENT 'num_cuartos_dormir — pregunta 26',
  qtcuartosexclusivosdormir  SMALLINT UNSIGNED NOT NULL
                             COMMENT 'num_cuartos_unicos_dormir — pregunta 27',

  -- Sanitario
  cdtiposanitario            TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_sanitario — pregunta 28',
  cdubicacionsanitario       TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_ubi_sanitario — pregunta 29',
  cdusosanitario             TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_uso_sanitario — pregunta 30',

  -- Agua
  cdorigenagua               TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_origen_agua — pregunta 31',
  fgaguasietedias            TINYINT UNSIGNED NOT NULL
                             COMMENT 'ind_agua_llega_7dias — pregunta 32',
  qtdiasllegaagua            TINYINT UNSIGNED NULL
                             COMMENT 'num_dias_llega — 0–6; nulo si fgaguasietedias <> 2',
  fgaguaveinticuatrohoras    TINYINT UNSIGNED NOT NULL
                             COMMENT 'ind_agua_llega_24horas — pregunta 33',
  qthorasllegaagua           TINYINT UNSIGNED NULL
                             COMMENT 'num_horas_llega — 0–23; nulo si fgaguaveinticuatrohoras <> 2',
  cdtratamientoaguabeber     TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_uso_agua_beber — pregunta 34',

  -- Basura y cocina
  cdeliminacionbasura        TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_elimina_basura — pregunta 35',
  fgcocina                   TINYINT UNSIGNED NOT NULL
                             COMMENT 'ind_tiene_cocina — pregunta 36',
  cdlugarpreparaalimentos    TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_prepara_alimentos — pregunta 37',
  cdusococina                TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_uso_cocina — pregunta 38',
  cdenergiacocina            TINYINT UNSIGNED NOT NULL
                             COMMENT 'tip_energia_cocina — pregunta 39',

  -- Bienes durables (pregunta 40A–40H)
  fgnevera                   TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_nevera',
  fglavadora                 TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_lavadora',
  fgcomputador               TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_pc',
  fginternet                 TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_internet',
  fgmoto                     TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_moto',
  fgtractor                  TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_tractor',
  fgcarro                    TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_carro',
  fgbienraiz                 TINYINT UNSIGNED NOT NULL COMMENT 'ind_tiene_bien_raiz',

  -- Agregados y resultados
  qtpersonashogar            SMALLINT UNSIGNED NOT NULL
                             COMMENT 'num_personas_hogar — pregunta 44B',
  mngastototal               DECIMAL(15,2)    NOT NULL DEFAULT 0.00
                             COMMENT 'vlr_total_gastos — suma de los 8 rubros',
  fgpobrezamultidimensional  TINYINT UNSIGNED NOT NULL
                             COMMENT 'H_5 — indicador IPM, 0 No / 1 Sí',
  cdclasificacionsisben      VARCHAR(3)       NOT NULL
                             COMMENT 'Clasificacion — A1–A5, B1–B7, C1–C18, D1–D21',

  CONSTRAINT pk_hogar PRIMARY KEY (idhogar),

  CONSTRAINT fk_hogar_vivienda
    FOREIGN KEY (idvivienda) REFERENCES Vivienda (idvivienda)
    ON UPDATE CASCADE ON DELETE CASCADE,

  CONSTRAINT ck_hogar_ocupacion    CHECK (cdocupacionvivienda BETWEEN 1 AND 5),
  CONSTRAINT ck_hogar_tiempohabita CHECK (cdtiempohabitavivienda BETWEEN 1 AND 4),
  CONSTRAINT ck_hogar_tiposanitario      CHECK (cdtiposanitario BETWEEN 1 AND 5),
  CONSTRAINT ck_hogar_ubicacionsanitario CHECK (cdubicacionsanitario IN (1, 2, 9)),
  CONSTRAINT ck_hogar_usosanitario       CHECK (cdusosanitario IN (1, 2, 3, 9)),
  CONSTRAINT ck_hogar_origenagua         CHECK (cdorigenagua BETWEEN 1 AND 9),
  CONSTRAINT ck_hogar_aguasietedias      CHECK (fgaguasietedias IN (1, 2, 9)),
  CONSTRAINT ck_hogar_aguaveinticuatro   CHECK (fgaguaveinticuatrohoras IN (1, 2, 9)),
  CONSTRAINT ck_hogar_tratamientoagua    CHECK (cdtratamientoaguabeber BETWEEN 1 AND 6),
  CONSTRAINT ck_hogar_eliminacionbasura  CHECK (cdeliminacionbasura BETWEEN 1 AND 7),
  CONSTRAINT ck_hogar_cocina             CHECK (fgcocina IN (1, 2)),
  CONSTRAINT ck_hogar_lugarpreparaalimentos CHECK (cdlugarpreparaalimentos BETWEEN 1 AND 5),
  CONSTRAINT ck_hogar_usococina          CHECK (cdusococina IN (1, 2, 3, 9)),
  CONSTRAINT ck_hogar_energiacocina      CHECK (cdenergiacocina BETWEEN 1 AND 7),
  CONSTRAINT ck_hogar_bienes CHECK (
        fgnevera     IN (1, 2) AND fglavadora IN (1, 2)
    AND fgcomputador IN (1, 2) AND fginternet IN (1, 2)
    AND fgmoto       IN (1, 2) AND fgtractor  IN (1, 2)
    AND fgcarro      IN (1, 2) AND fgbienraiz IN (1, 2)
  ),
  CONSTRAINT ck_hogar_personas  CHECK (qtpersonashogar >= 1),
  CONSTRAINT ck_hogar_gastototal CHECK (mngastototal >= 0),
  CONSTRAINT ck_hogar_ipm        CHECK (fgpobrezamultidimensional IN (0, 1)),
  CONSTRAINT ck_hogar_clasificacion CHECK (
    cdclasificacionsisben REGEXP '^(A[1-5]|B[1-7]|C([1-9]|1[0-8])|D([1-9]|1[0-9]|2[01]))$'
  ),

  -- Reglas de consistencia del diccionario
  CONSTRAINT ck_hogar_jerarquia_cuartos CHECK (
    qtcuartosexclusivosdormir <= qtcuartosdormir
    AND qtcuartosdormir <= qtcuartosexclusivos
  ),
  CONSTRAINT ck_hogar_sanitario_notiene CHECK (
    cdtiposanitario <> 5 OR (cdubicacionsanitario = 9 AND cdusosanitario = 9)
  ),
  CONSTRAINT ck_hogar_cocina_notiene CHECK (fgcocina <> 2 OR cdusococina = 9),
  CONSTRAINT ck_hogar_diasagua CHECK (
    (fgaguasietedias = 2 AND qtdiasllegaagua BETWEEN 0 AND 6)
    OR (fgaguasietedias <> 2 AND qtdiasllegaagua IS NULL)
  ),
  CONSTRAINT ck_hogar_horasagua CHECK (
    (fgaguaveinticuatrohoras = 2 AND qthorasllegaagua BETWEEN 0 AND 23)
    OR (fgaguaveinticuatrohoras <> 2 AND qthorasllegaagua IS NULL)
  )
) ENGINE=InnoDB
  COMMENT='Hogar: condiciones de habitabilidad, bienes, IPM y clasificación';

CREATE INDEX ix_hogar_vivienda       ON Hogar (idvivienda);
CREATE INDEX ix_hogar_clasificacion  ON Hogar (cdclasificacionsisben);
CREATE INDEX ix_hogar_ipm            ON Hogar (fgpobrezamultidimensional);


-- =====================================================================
-- 5. DETALLES DEL HOGAR
--    Normalizan 43 variables del archivo plano en 3 tablas.
-- =====================================================================

-- 16 variables: 8 pares fggasto* / mngasto*  (preguntas 41A–41H)
CREATE TABLE HogarGasto (
  idhogar      VARCHAR(20)      NOT NULL  COMMENT 'Hogar al que corresponde el gasto',
  cdrubrogasto TINYINT UNSIGNED NOT NULL  COMMENT 'Rubro de gasto; catálogo rubrogasto',
  fggasto      TINYINT UNSIGNED NOT NULL  COMMENT '1 Sí, 2 No, 9 Sí pero no sabe el valor',
  mngasto      DECIMAL(15,2)    NULL      COMMENT 'Valor mensual del gasto; nulo si fggasto <> 1',

  CONSTRAINT pk_hogargasto PRIMARY KEY (idhogar, cdrubrogasto),
  CONSTRAINT fk_hogargasto_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ck_hogargasto_rubro CHECK (cdrubrogasto BETWEEN 1 AND 8),
  CONSTRAINT ck_hogargasto_flag  CHECK (fggasto IN (1, 2, 9)),
  CONSTRAINT ck_hogargasto_valor CHECK (
    (fggasto = 1 AND mngasto IS NOT NULL AND mngasto >= 0)
    OR (fggasto <> 1 AND (mngasto IS NULL OR mngasto = 0))
  )
) ENGINE=InnoDB
  COMMENT='Gastos mensuales del hogar por rubro (normaliza 16 variables)';

CREATE INDEX ix_hogargasto_rubro ON HogarGasto (cdrubrogasto);

-- 12 variables: 6 pares fgevento* / qtevento*  (preguntas 43A–43F)
CREATE TABLE HogarEvento (
  idhogar      VARCHAR(20)       NOT NULL COMMENT 'Hogar afectado',
  cdtipoevento TINYINT UNSIGNED  NOT NULL COMMENT 'Tipo de evento; catálogo tipoevento',
  fgevento     TINYINT UNSIGNED  NOT NULL COMMENT '1 Sí, 2 No',
  qtevento     SMALLINT UNSIGNED NULL     COMMENT 'Número de veces; nulo si fgevento = 2',

  CONSTRAINT pk_hogarevento PRIMARY KEY (idhogar, cdtipoevento),
  CONSTRAINT fk_hogarevento_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ck_hogarevento_tipo CHECK (cdtipoevento BETWEEN 1 AND 6),
  CONSTRAINT ck_hogarevento_flag CHECK (fgevento IN (1, 2)),
  CONSTRAINT ck_hogarevento_conteo CHECK (
    (fgevento = 1 AND qtevento >= 1) OR (fgevento = 2 AND qtevento IS NULL)
  )
) ENGINE=InnoDB
  COMMENT='Eventos de riesgo que han afectado la vivienda (normaliza 12 variables)';

CREATE INDEX ix_hogarevento_tipo ON HogarEvento (cdtipoevento);

-- 15 variables: I1 a I15
CREATE TABLE HogarPrivacionIpm (
  idhogar        VARCHAR(20)      NOT NULL COMMENT 'Hogar evaluado',
  cdprivacionipm TINYINT UNSIGNED NOT NULL COMMENT 'Privación I1–I15; catálogo privacionipm',
  fgprivacion    TINYINT UNSIGNED NOT NULL COMMENT '0 No privado, 1 Privado',

  CONSTRAINT pk_hogarprivacionipm PRIMARY KEY (idhogar, cdprivacionipm),
  CONSTRAINT fk_hogarprivacionipm_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ck_hogarprivacionipm_codigo CHECK (cdprivacionipm BETWEEN 1 AND 15),
  CONSTRAINT ck_hogarprivacionipm_flag   CHECK (fgprivacion IN (0, 1))
) ENGINE=InnoDB
  COMMENT='Privaciones IPM del hogar, I1–I15 (normaliza 15 variables)';

CREATE INDEX ix_hogarprivacionipm_codigo ON HogarPrivacionIpm (cdprivacionipm);


-- =====================================================================
-- 6. PERSONA  (20 variables del diccionario)
-- =====================================================================

CREATE TABLE Persona (
  idpersona                BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT
                           COMMENT 'Clave sustituta; NO viene en el archivo fuente',
  idhogar                  VARCHAR(20)       NOT NULL
                           COMMENT 'Hogar al que pertenece la persona',
  qtordenpersona           TINYINT UNSIGNED  NOT NULL
                           COMMENT 'Número de orden dentro del hogar; se genera en la carga. Es el valor al que apuntan ide_conyuge, ide_padre e ide_serv_domestico',

  -- Demografía
  cdsexo                   TINYINT UNSIGNED  NOT NULL COMMENT 'sexo_persona — 1 Hombre, 2 Mujer',
  qtedad                   SMALLINT UNSIGNED NOT NULL COMMENT 'edad_calculada — variable derivada',
  cdparentesco             TINYINT UNSIGNED  NOT NULL COMMENT 'tip_parentesco — pregunta 54',
  cdestadocivil            TINYINT UNSIGNED  NOT NULL COMMENT 'tip_estado_civil — pregunta 55',

  -- Salud  (DATO SENSIBLE — Ley 1581 de 2012)
  cdseguridadsocial        TINYINT UNSIGNED  NOT NULL COMMENT 'tip_seg_social — pregunta 60',
  fgenfermo30dias          TINYINT UNSIGNED  NOT NULL COMMENT 'ind_enfermo_30 — pregunta 61',
  fgacudioserviciosalud    TINYINT UNSIGNED  NOT NULL COMMENT 'ind_acudio_salud — pregunta 62',
  fgatendidosalud          TINYINT UNSIGNED  NOT NULL COMMENT 'ind_fue_atendido_salud — pregunta 63',
  fgembarazo               TINYINT UNSIGNED  NOT NULL COMMENT 'ind_esta_embarazada — pregunta 64',
  fghijosnacidosvivos      TINYINT UNSIGNED  NOT NULL COMMENT 'ind_tuvo_hijos — pregunta 65',

  -- Primera infancia
  cdcuidadoninos           TINYINT UNSIGNED  NOT NULL COMMENT 'tip_cuidado_niños — pregunta 66',
  fgrecibealimentacion     TINYINT UNSIGNED  NOT NULL COMMENT 'ind_recibe_comida — pregunta 67',

  -- Educación
  fgleerescribir           TINYINT UNSIGNED  NOT NULL COMMENT 'ind_leer_escribir — pregunta 68',
  fgestudia                TINYINT UNSIGNED  NOT NULL COMMENT 'ind_estudia — pregunta 69',
  cdniveleducativo         TINYINT UNSIGNED  NOT NULL COMMENT 'niv_educativo — pregunta 70',
  cdgrado                  TINYINT UNSIGNED  NOT NULL COMMENT 'grado_alcanzado — 0–13, 99 No aplica',

  -- Actividad económica
  fgcotizapension          TINYINT UNSIGNED  NOT NULL COMMENT 'ind_fondo_pensiones — pregunta 71',
  cdactividadprincipal     TINYINT UNSIGNED  NOT NULL COMMENT 'tip_actividad_mes — pregunta 72',
  qtsemanasbuscandotrabajo SMALLINT UNSIGNED NOT NULL COMMENT 'num_sem_buscando — 999 No aplica',
  cdtipoempleo             TINYINT UNSIGNED  NOT NULL COMMENT 'tip_empleado — 99 No aplica',

  CONSTRAINT pk_persona PRIMARY KEY (idpersona),
  CONSTRAINT uq_persona_orden UNIQUE (idhogar, qtordenpersona),

  CONSTRAINT fk_persona_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON UPDATE CASCADE ON DELETE CASCADE,

  CONSTRAINT ck_persona_sexo        CHECK (cdsexo IN (1, 2)),
  CONSTRAINT ck_persona_edad        CHECK (qtedad BETWEEN 0 AND 120),
  CONSTRAINT ck_persona_parentesco  CHECK (cdparentesco BETWEEN 1 AND 19),
  CONSTRAINT ck_persona_estadocivil CHECK (cdestadocivil BETWEEN 1 AND 5),
  CONSTRAINT ck_persona_segsocial   CHECK (cdseguridadsocial IN (0, 1, 2, 3, 9)),
  CONSTRAINT ck_persona_enfermo     CHECK (fgenfermo30dias IN (1, 2)),
  CONSTRAINT ck_persona_acudio      CHECK (fgacudioserviciosalud IN (1, 2, 9)),
  CONSTRAINT ck_persona_atendido    CHECK (fgatendidosalud IN (1, 2, 9)),
  CONSTRAINT ck_persona_embarazo    CHECK (fgembarazo IN (1, 2, 9)),
  CONSTRAINT ck_persona_hijos       CHECK (fghijosnacidosvivos IN (1, 2, 9)),
  CONSTRAINT ck_persona_cuidado     CHECK (cdcuidadoninos BETWEEN 1 AND 9),
  CONSTRAINT ck_persona_alimentacion CHECK (fgrecibealimentacion IN (1, 2, 9)),
  CONSTRAINT ck_persona_leerescribir CHECK (fgleerescribir IN (1, 2, 9)),
  CONSTRAINT ck_persona_estudia      CHECK (fgestudia IN (1, 2, 9)),
  CONSTRAINT ck_persona_niveleducativo CHECK (cdniveleducativo IN (0,1,2,3,4,5,6,7,9)),
  CONSTRAINT ck_persona_grado        CHECK (cdgrado BETWEEN 0 AND 13 OR cdgrado = 99),
  CONSTRAINT ck_persona_pension      CHECK (fgcotizapension IN (1, 2, 3, 9)),
  CONSTRAINT ck_persona_actividad    CHECK (cdactividadprincipal BETWEEN 0 AND 9),
  CONSTRAINT ck_persona_semanas      CHECK (qtsemanasbuscandotrabajo <= 999),
  CONSTRAINT ck_persona_tipoempleo   CHECK (cdtipoempleo BETWEEN 1 AND 10 OR cdtipoempleo = 99),

  -- Reglas de consistencia del diccionario (flujos de «no aplica»)
  CONSTRAINT ck_persona_flujo_salud CHECK (
    (fgenfermo30dias = 2 AND fgacudioserviciosalud = 9)
    OR (fgenfermo30dias = 1)
  ),
  CONSTRAINT ck_persona_flujo_atendido CHECK (
    fgacudioserviciosalud = 1 OR fgatendidosalud = 9
  ),
  CONSTRAINT ck_persona_flujo_mujer CHECK (
    (cdsexo = 2 AND qtedad >= 8)
    OR (fgembarazo = 9 AND fghijosnacidosvivos = 9)
  ),
  CONSTRAINT ck_persona_flujo_primerainfancia CHECK (
    qtedad < 5 OR (cdcuidadoninos = 9 AND fgrecibealimentacion = 9)
  ),
  CONSTRAINT ck_persona_flujo_educacion CHECK (
    qtedad >= 5
    OR (fgleerescribir = 9 AND fgestudia = 9 AND cdniveleducativo = 9 AND cdgrado = 99)
  ),
  CONSTRAINT ck_persona_flujo_pension CHECK (qtedad >= 14 OR fgcotizapension = 9),
  CONSTRAINT ck_persona_flujo_trabajo CHECK (
    qtedad >= 8 OR (cdactividadprincipal = 9 AND cdtipoempleo = 99)
  ),
  CONSTRAINT ck_persona_flujo_busqueda CHECK (
    cdactividadprincipal = 2 OR qtsemanasbuscandotrabajo = 999
  )
) ENGINE=InnoDB
  COMMENT='Persona: demografía, salud, educación y actividad económica';

CREATE INDEX ix_persona_hogar        ON Persona (idhogar);
CREATE INDEX ix_persona_parentesco   ON Persona (cdparentesco);
CREATE INDEX ix_persona_sexo_edad    ON Persona (cdsexo, qtedad);
CREATE INDEX ix_persona_niveleducativo ON Persona (cdniveleducativo);


-- =====================================================================
-- 7. DETALLES DE LA PERSONA
--    Normalizan 35 variables del archivo plano en 3 tablas.
-- =====================================================================

-- 6 variables: ind_conyuge_vive_hogar / ide_conyuge,
--              ind_padre_vive_hogar / ide_padre,
--              ind_pariente_domestico / ide_serv_domestico
CREATE TABLE PersonaRelacion (
  idpersona             BIGINT UNSIGNED  NOT NULL COMMENT 'Persona declarante',
  cdtiporelacion        TINYINT UNSIGNED NOT NULL
                        COMMENT '1 Cónyuge, 2 Padre o madre, 3 Servicio doméstico o pensionista',
  fgvivehogar           TINYINT UNSIGNED NOT NULL
                        COMMENT '1 Sí, 2 No, 9 No aplica',
  idpersonarelacionada  BIGINT UNSIGNED  NULL
                        COMMENT 'Persona referida; nulo si fgvivehogar <> 1',

  CONSTRAINT pk_personarelacion PRIMARY KEY (idpersona, cdtiporelacion),
  CONSTRAINT fk_personarelacion_persona
    FOREIGN KEY (idpersona) REFERENCES Persona (idpersona)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_personarelacion_relacionada
    FOREIGN KEY (idpersonarelacionada) REFERENCES Persona (idpersona)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT ck_personarelacion_tipo CHECK (cdtiporelacion BETWEEN 1 AND 3),
  CONSTRAINT ck_personarelacion_flag CHECK (fgvivehogar IN (1, 2, 9)),
  CONSTRAINT ck_personarelacion_referencia CHECK (
    (fgvivehogar = 1 AND idpersonarelacionada IS NOT NULL)
    OR (fgvivehogar <> 1 AND idpersonarelacionada IS NULL)
  ),
  CONSTRAINT ck_personarelacion_noautoreferencia
    CHECK (idpersonarelacionada IS NULL OR idpersonarelacionada <> idpersona)
) ENGINE=InnoDB
  COMMENT='Relaciones entre personas del mismo hogar (normaliza 6 variables)';

CREATE INDEX ix_personarelacion_relacionada ON PersonaRelacion (idpersonarelacionada);

-- 8 variables: ind_discap_* (DATO SENSIBLE — Ley 1581 de 2012)
CREATE TABLE PersonaDiscapacidad (
  idpersona          BIGINT UNSIGNED  NOT NULL COMMENT 'Persona evaluada',
  cdtipodiscapacidad TINYINT UNSIGNED NOT NULL
                     COMMENT '1 Ver, 2 Oír, 3 Hablar, 4 Moverse, 5 Bañarse, 6 Salir, 7 Entender, 8 Ninguna',
  fgdiscapacidad     TINYINT UNSIGNED NOT NULL COMMENT '1 Sí, 2 No',

  CONSTRAINT pk_personadiscapacidad PRIMARY KEY (idpersona, cdtipodiscapacidad),
  CONSTRAINT fk_personadiscapacidad_persona
    FOREIGN KEY (idpersona) REFERENCES Persona (idpersona)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ck_personadiscapacidad_tipo CHECK (cdtipodiscapacidad BETWEEN 1 AND 8),
  CONSTRAINT ck_personadiscapacidad_flag CHECK (fgdiscapacidad IN (1, 2))
) ENGINE=InnoDB
  COMMENT='Limitaciones permanentes, pregunta 59. DATO SENSIBLE (normaliza 8 variables)';

CREATE INDEX ix_personadiscapacidad_tipo ON PersonaDiscapacidad (cdtipodiscapacidad);

-- 21 variables: 9 fuentes de ingreso + 3 subsidios del Estado
-- (DATO SENSIBLE — Ley 1581 de 2012)
CREATE TABLE PersonaIngreso (
  idpersona       BIGINT UNSIGNED  NOT NULL COMMENT 'Persona perceptora',
  cdfuenteingreso TINYINT UNSIGNED NOT NULL COMMENT 'Fuente de ingreso; catálogo fuenteingreso',
  fgingreso       TINYINT UNSIGNED NOT NULL
                  COMMENT '1 Sí, 2 No, 9 Sí pero no sabe el valor, 99 No aplica',
  mningreso       DECIMAL(15,2)    NULL
                  COMMENT 'Valor del ingreso del mes pasado; nulo si fgingreso <> 1',
  qtmesesingreso  TINYINT UNSIGNED NULL
                  COMMENT 'num_mes_ingr_cosecha — solo aplica a la fuente 3 (cosecha); 0–12 o 99',

  CONSTRAINT pk_personaingreso PRIMARY KEY (idpersona, cdfuenteingreso),
  CONSTRAINT fk_personaingreso_persona
    FOREIGN KEY (idpersona) REFERENCES Persona (idpersona)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ck_personaingreso_fuente CHECK (cdfuenteingreso BETWEEN 1 AND 12),
  CONSTRAINT ck_personaingreso_flag   CHECK (fgingreso IN (1, 2, 9, 99)),
  CONSTRAINT ck_personaingreso_valor CHECK (
    (fgingreso = 1 AND mningreso IS NOT NULL AND mningreso >= 0)
    OR (fgingreso <> 1 AND (mningreso IS NULL OR mningreso = 0))
  ),
  -- qtmesesingreso solo tiene sentido en la fuente 3 (ganancia de la cosecha)
  CONSTRAINT ck_personaingreso_meses CHECK (
    (cdfuenteingreso = 3 AND (qtmesesingreso BETWEEN 0 AND 12 OR qtmesesingreso = 99))
    OR (cdfuenteingreso <> 3 AND qtmesesingreso IS NULL)
  )
) ENGINE=InnoDB
  COMMENT='Ingresos de la persona por fuente. DATO SENSIBLE (normaliza 21 variables)';

CREATE INDEX ix_personaingreso_fuente ON PersonaIngreso (cdfuenteingreso);


-- =====================================================================
-- COBERTURA DE VARIABLES
--   Vivienda             21   Persona                20
--   Hogar                32   PersonaRelacion         6
--   HogarGasto           16   PersonaDiscapacidad     8
--   HogarEvento          12   PersonaIngreso         21
--   HogarPrivacionIpm    15   -----------------------------
--                             TOTAL                 151
-- =====================================================================
