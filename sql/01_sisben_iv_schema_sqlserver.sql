-- =====================================================================
-- SISBÉN IV — Esquema relacional para SQL Server
-- Traducción de insumos/01_sisben_iv_schema.sql (escrito para MySQL)
-- Nomenclatura: estándar Riodata. Tablas y columnas no cambian.
--
-- Ejecutar con sqlcmd (usa separadores GO):
--   sqlcmd -S servidor -U usuario -f 65001 -i sql/01_sisben_iv_schema_sqlserver.sql
--
-- CAMBIOS FRENTE AL ORIGINAL
--   Tipos
--     SMALLINT UNSIGNED -> INT, INT UNSIGNED -> INT, BIGINT UNSIGNED -> BIGINT.
--     TINYINT UNSIGNED -> TINYINT (en SQL Server ya va de 0 a 255).
--     idvivienda e idpersona -> BIGINT sin IDENTITY: los asigna el migrador.
--   Llaves foráneas
--     Se quitan los ON UPDATE CASCADE: los códigos y las claves no cambian,
--     y SQL Server no admite varias rutas de cascada hacia Vivienda ni
--     hacia PersonaRelacion. ON DELETE RESTRICT -> ON DELETE NO ACTION.
--   CHECK
--     REGEXP -> LIKE o lista IN.
--     ck_hogar_energiacocina admite 9: aparece en 344 hogares, los mismos
--       que no preparan alimentos.
--     ck_personaingreso_valor admite la fuente 9 sin valor: el archivo trae
--       indicador agregado pero no monto.
--     Se retiran ck_hogar_cocina_notiene (la regla no coincide con el
--       27,9 % de los hogares) y ck_vivienda_territorio_rural (el archivo
--       anonimizado no trae territorio en esos casos). Quedan como avisos
--       del migrador.
--   Otros
--     Sin ENGINE ni COMMENT: las descripciones pasan a comentarios SQL.
--     Sin DROP TABLE: este script nunca borra datos. Si las tablas ya
--     existen, no hace nada.
-- =====================================================================

IF DB_ID('sisbeniv') IS NULL
  CREATE DATABASE sisbeniv COLLATE Modern_Spanish_CI_AS;
GO

USE sisbeniv;
GO

IF OBJECT_ID('dbo.Persona', 'U') IS NOT NULL
BEGIN
  PRINT 'El esquema ya existe. No se ejecuta nada.';
  SET NOEXEC ON;
END
GO

-- =====================================================================
-- 1. CATÁLOGOS PARAMÉTRICOS
--    Reemplazan la columna «Valores» del diccionario. Un solo par de
--    tablas para los 35 dominios de codificación del conjunto.
-- =====================================================================

CREATE TABLE catDominio (
  cddominio    VARCHAR(30)  NOT NULL, -- Código del dominio de codificación
  nmdominio    VARCHAR(100) NOT NULL, -- Nombre legible del dominio
  dspregunta   VARCHAR(255) NULL, -- Pregunta(s) de la encuesta que usan el dominio
  CONSTRAINT pk_catdominio PRIMARY KEY (cddominio)
);
GO
-- Dominios de codificación declarados en el diccionario SISBÉN IV

CREATE TABLE catDominioValor (
  cddominio    VARCHAR(30)  NOT NULL, -- Dominio al que pertenece el valor
  cdvalor      VARCHAR(3)   NOT NULL, -- Código del valor tal como viene en la base
  dsvalor      VARCHAR(255) NOT NULL, -- Descripción del valor
  cdagrupacion VARCHAR(40)  NULL, -- Agrupación superior del valor (solo clasificacionsisben)
  fgnoaplica   TINYINT NOT NULL DEFAULT 0, -- 1 = el valor significa «no aplica» o «no sabe»; 0 = valor sustantivo
  CONSTRAINT pk_catdominiovalor PRIMARY KEY (cddominio, cdvalor),
  CONSTRAINT fk_catdominiovalor_dominio
    FOREIGN KEY (cddominio) REFERENCES catDominio (cddominio)
    ON DELETE NO ACTION,
  CONSTRAINT ck_catdominiovalor_noaplica CHECK (fgnoaplica IN (0, 1))
);
GO
-- Valores válidos por dominio; capa de etiquetado para Power BI

CREATE INDEX ix_catdominiovalor_agrupacion
  ON catDominioValor (cddominio, cdagrupacion);


-- =====================================================================
-- 2. DIMENSIONES TERRITORIALES
--    Normalizan los 9 campos territoriales del diccionario
--    (cod_* + NOM_*) en 5 catálogos jerárquicos.
-- =====================================================================

CREATE TABLE dimDepartamento (
  cddpto         VARCHAR(2)   NOT NULL, -- Código DANE del departamento
  nmdepartamento VARCHAR(100) NOT NULL, -- Nombre del departamento
  CONSTRAINT pk_dimdepartamento PRIMARY KEY (cddpto),
  CONSTRAINT ck_dimdepartamento_cddpto CHECK (cddpto LIKE '[0-9][0-9]')
);
GO
-- Catálogo DANE de departamentos

CREATE TABLE dimMunicipio (
  cdmunicipio  VARCHAR(5)   NOT NULL, -- Código DANE del municipio (5 dígitos)
  cddpto       VARCHAR(2)   NOT NULL, -- Departamento al que pertenece
  nmmunicipio  VARCHAR(100) NOT NULL, -- Nombre del municipio
  CONSTRAINT pk_dimmunicipio PRIMARY KEY (cdmunicipio),
  CONSTRAINT fk_dimmunicipio_dpto
    FOREIGN KEY (cddpto) REFERENCES dimDepartamento (cddpto)
    ON DELETE NO ACTION,
  CONSTRAINT ck_dimmunicipio_cdmunicipio CHECK (cdmunicipio LIKE '[0-9][0-9][0-9][0-9][0-9]'),
  -- Regla del diccionario: el código de municipio inicia con el de departamento
  CONSTRAINT ck_dimmunicipio_prefijo CHECK (LEFT(cdmunicipio, 2) = cddpto)
);
GO
-- Catálogo DANE de municipios

CREATE INDEX ix_dimmunicipio_dpto ON dimMunicipio (cddpto);
GO

CREATE TABLE dimCorregimiento (
  cdcorregimiento INT NOT NULL, -- Código del corregimiento registrado en SisbenApp
  cdmunicipio     VARCHAR(5)   NOT NULL, -- Municipio al que pertenece
  nmcorregimiento VARCHAR(100) NOT NULL, -- Nombre del corregimiento
  CONSTRAINT pk_dimcorregimiento PRIMARY KEY (cdcorregimiento),
  CONSTRAINT fk_dimcorregimiento_municipio
    FOREIGN KEY (cdmunicipio) REFERENCES dimMunicipio (cdmunicipio)
    ON DELETE NO ACTION,
  CONSTRAINT ck_dimcorregimiento_codigo CHECK (cdcorregimiento BETWEEN 1 AND 9999)
);
GO
-- Corregimientos; codificación interna SisbenApp, no DANE

CREATE INDEX ix_dimcorregimiento_municipio ON dimCorregimiento (cdmunicipio);
GO

CREATE TABLE dimVereda (
  cdvereda        INT NOT NULL, -- Código de la vereda registrado en SisbenApp
  cdcorregimiento INT NULL, -- Corregimiento al que pertenece; nulo si la vereda no está adscrita a uno
  nmvereda        VARCHAR(100) NOT NULL, -- Nombre de la vereda
  CONSTRAINT pk_dimvereda PRIMARY KEY (cdvereda),
  CONSTRAINT fk_dimvereda_corregimiento
    FOREIGN KEY (cdcorregimiento) REFERENCES dimCorregimiento (cdcorregimiento)
    ON DELETE NO ACTION,
  CONSTRAINT ck_dimvereda_codigo CHECK (cdvereda BETWEEN 1 AND 999999)
);
GO
-- Veredas; codificación interna SisbenApp, no DANE

CREATE INDEX ix_dimvereda_corregimiento ON dimVereda (cdcorregimiento);
GO

CREATE TABLE dimBarrio (
  cdbarrio    INT NOT NULL, -- Código del barrio registrado en SisbenApp
  cdmunicipio VARCHAR(5)   NOT NULL, -- Municipio al que pertenece
  nmbarrio    VARCHAR(100) NOT NULL, -- Nombre del barrio
  CONSTRAINT pk_dimbarrio PRIMARY KEY (cdbarrio),
  CONSTRAINT fk_dimbarrio_municipio
    FOREIGN KEY (cdmunicipio) REFERENCES dimMunicipio (cdmunicipio)
    ON DELETE NO ACTION,
  CONSTRAINT ck_dimbarrio_codigo CHECK (cdbarrio BETWEEN 1 AND 999999)
);
GO
-- Barrios; codificación interna SisbenApp, no DANE

CREATE INDEX ix_dimbarrio_municipio ON dimBarrio (cdmunicipio);
GO


-- =====================================================================
-- 3. VIVIENDA  (21 variables del diccionario)
--    9 territoriales -> 5 llaves foráneas + dimensiones
--    12 propias de la vivienda
-- =====================================================================

CREATE TABLE Vivienda (
  idvivienda            BIGINT  NOT NULL, -- Clave sustituta; NO viene en el archivo fuente
  cdmunicipio           VARCHAR(5)       NOT NULL, -- cod_mpio — código DANE del municipio
  cdclase               TINYINT NOT NULL, -- Cod_clase — 1 Cabecera, 2 Centro poblado, 3 Rural disperso
  cdcorregimiento       INT     NULL, -- Cod_corregimiento — nulo en zona urbana
  cdvereda              INT     NULL, -- Cod_vereda — nulo en zona urbana
  cdbarrio              INT     NULL, -- Cod_barrio — nulo en zona rural
  cdtipovivienda        TINYINT NOT NULL, -- tip_vivienda — pregunta 17
  cdmaterialpared       TINYINT NOT NULL, -- tip_mat_paredes — pregunta 18
  cdmaterialpiso        TINYINT NOT NULL, -- tip_mat_pisos — pregunta 19
  fgenergia             TINYINT NOT NULL, -- ind_tiene_energia — 1 Sí, 2 No
  cdestratoenergia      TINYINT NOT NULL, -- tip_estrato_energia — 0, 1–6, 9, 99
  fgalcantarillado      TINYINT NOT NULL, -- ind_tiene_alcantarillado — 1 Sí, 2 No
  fggas                 TINYINT NOT NULL, -- ind_tiene_gas — 1 Sí, 2 No
  fgrecoleccionbasura   TINYINT NOT NULL, -- ind_tiene_recoleccion — 1 Sí, 2 No
  fgacueducto           TINYINT NOT NULL, -- ind_tiene_acueducto — 1 Sí, 2 No
  cdestratoacueducto    TINYINT NOT NULL, -- tip_estrato_acueducto — 0, 1–6, 9, 99
  qtcuartosvivienda     INT NOT NULL, -- num_cuartos_vivienda — pregunta 21
  qthogaresvivienda     INT NOT NULL, -- num_hogares_vivienda — pregunta 22

  CONSTRAINT pk_vivienda PRIMARY KEY (idvivienda),

  CONSTRAINT fk_vivienda_municipio
    FOREIGN KEY (cdmunicipio) REFERENCES dimMunicipio (cdmunicipio)
    ON DELETE NO ACTION,
  CONSTRAINT fk_vivienda_corregimiento
    FOREIGN KEY (cdcorregimiento) REFERENCES dimCorregimiento (cdcorregimiento)
    ON DELETE NO ACTION,
  CONSTRAINT fk_vivienda_vereda
    FOREIGN KEY (cdvereda) REFERENCES dimVereda (cdvereda)
    ON DELETE NO ACTION,
  CONSTRAINT fk_vivienda_barrio
    FOREIGN KEY (cdbarrio) REFERENCES dimBarrio (cdbarrio)
    ON DELETE NO ACTION,

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
  -- Clase 1 (cabecera) exige barrio
  CONSTRAINT ck_vivienda_territorio_urbano
    CHECK (cdclase <> 1 OR cdbarrio IS NOT NULL)
);
GO
-- Unidad de vivienda: ubicación, materiales y servicios públicos

CREATE INDEX ix_vivienda_municipio ON Vivienda (cdmunicipio);
GO
CREATE INDEX ix_vivienda_barrio    ON Vivienda (cdbarrio);
GO
CREATE INDEX ix_vivienda_vereda    ON Vivienda (cdvereda);
GO
CREATE INDEX ix_vivienda_clase     ON Vivienda (cdclase);
GO


-- =====================================================================
-- 4. HOGAR  (32 variables del diccionario)
-- =====================================================================

CREATE TABLE Hogar (
  idhogar                    VARCHAR(20)      NOT NULL, -- ide_hogar — única clave real del archivo fuente
  idvivienda                 BIGINT  NOT NULL, -- Vivienda que ocupa el hogar

  -- Ocupación y permanencia
  cdocupacionvivienda        TINYINT NOT NULL, -- tip_ocupa_vivienda — pregunta 24
  cdtiempohabitavivienda     TINYINT NOT NULL, -- num_habita_vivienda — código de rango 1–4, pregunta 42

  -- Cuartos
  qtcuartosexclusivos        INT NOT NULL, -- num_cuartos_exclusivos — pregunta 25
  qtcuartosdormir            INT NOT NULL, -- num_cuartos_dormir — pregunta 26
  qtcuartosexclusivosdormir  INT NOT NULL, -- num_cuartos_unicos_dormir — pregunta 27

  -- Sanitario
  cdtiposanitario            TINYINT NOT NULL, -- tip_sanitario — pregunta 28
  cdubicacionsanitario       TINYINT NOT NULL, -- tip_ubi_sanitario — pregunta 29
  cdusosanitario             TINYINT NOT NULL, -- tip_uso_sanitario — pregunta 30

  -- Agua
  cdorigenagua               TINYINT NOT NULL, -- tip_origen_agua — pregunta 31
  fgaguasietedias            TINYINT NOT NULL, -- ind_agua_llega_7dias — pregunta 32
  qtdiasllegaagua            TINYINT NULL, -- num_dias_llega — 0–6; nulo si fgaguasietedias <> 2
  fgaguaveinticuatrohoras    TINYINT NOT NULL, -- ind_agua_llega_24horas — pregunta 33
  qthorasllegaagua           TINYINT NULL, -- num_horas_llega — 0–23; nulo si fgaguaveinticuatrohoras <> 2
  cdtratamientoaguabeber     TINYINT NOT NULL, -- tip_uso_agua_beber — pregunta 34

  -- Basura y cocina
  cdeliminacionbasura        TINYINT NOT NULL, -- tip_elimina_basura — pregunta 35
  fgcocina                   TINYINT NOT NULL, -- ind_tiene_cocina — pregunta 36
  cdlugarpreparaalimentos    TINYINT NOT NULL, -- tip_prepara_alimentos — pregunta 37
  cdusococina                TINYINT NOT NULL, -- tip_uso_cocina — pregunta 38
  cdenergiacocina            TINYINT NOT NULL, -- tip_energia_cocina — pregunta 39

  -- Bienes durables (pregunta 40A–40H)
  fgnevera                   TINYINT NOT NULL, -- ind_tiene_nevera
  fglavadora                 TINYINT NOT NULL, -- ind_tiene_lavadora
  fgcomputador               TINYINT NOT NULL, -- ind_tiene_pc
  fginternet                 TINYINT NOT NULL, -- ind_tiene_internet
  fgmoto                     TINYINT NOT NULL, -- ind_tiene_moto
  fgtractor                  TINYINT NOT NULL, -- ind_tiene_tractor
  fgcarro                    TINYINT NOT NULL, -- ind_tiene_carro
  fgbienraiz                 TINYINT NOT NULL, -- ind_tiene_bien_raiz

  -- Agregados y resultados
  qtpersonashogar            INT NOT NULL, -- num_personas_hogar — pregunta 44B
  mngastototal               DECIMAL(15,2)    NOT NULL DEFAULT 0.00, -- vlr_total_gastos — suma de los 8 rubros
  fgpobrezamultidimensional  TINYINT NOT NULL, -- H_5 — indicador IPM, 0 No / 1 Sí
  cdclasificacionsisben      VARCHAR(3)       NOT NULL, -- Clasificacion — A1–A5, B1–B7, C1–C18, D1–D21

  CONSTRAINT pk_hogar PRIMARY KEY (idhogar),

  CONSTRAINT fk_hogar_vivienda
    FOREIGN KEY (idvivienda) REFERENCES Vivienda (idvivienda)
    ON DELETE CASCADE,

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
  CONSTRAINT ck_hogar_energiacocina      CHECK (cdenergiacocina BETWEEN 1 AND 7 OR cdenergiacocina = 9),
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
    cdclasificacionsisben IN (
    'A1', 'A2', 'A3', 'A4', 'A5', 'B1', 'B2', 'B3', 'B4', 'B5',
    'B6', 'B7', 'C1', 'C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8',
    'C9', 'C10', 'C11', 'C12', 'C13', 'C14', 'C15', 'C16', 'C17', 'C18',
    'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8', 'D9', 'D10',
    'D11', 'D12', 'D13', 'D14', 'D15', 'D16', 'D17', 'D18', 'D19', 'D20',
    'D21'
    )
  ),

  -- Reglas de consistencia del diccionario
  CONSTRAINT ck_hogar_jerarquia_cuartos CHECK (
    qtcuartosexclusivosdormir <= qtcuartosdormir
    AND qtcuartosdormir <= qtcuartosexclusivos
  ),
  CONSTRAINT ck_hogar_sanitario_notiene CHECK (
    cdtiposanitario <> 5 OR (cdubicacionsanitario = 9 AND cdusosanitario = 9)
  ),
  CONSTRAINT ck_hogar_diasagua CHECK (
    (fgaguasietedias = 2 AND qtdiasllegaagua BETWEEN 0 AND 6)
    OR (fgaguasietedias <> 2 AND qtdiasllegaagua IS NULL)
  ),
  CONSTRAINT ck_hogar_horasagua CHECK (
    (fgaguaveinticuatrohoras = 2 AND qthorasllegaagua BETWEEN 0 AND 23)
    OR (fgaguaveinticuatrohoras <> 2 AND qthorasllegaagua IS NULL)
  )
);
GO
-- Hogar: condiciones de habitabilidad, bienes, IPM y clasificación

CREATE INDEX ix_hogar_vivienda       ON Hogar (idvivienda);
GO
CREATE INDEX ix_hogar_clasificacion  ON Hogar (cdclasificacionsisben);
GO
CREATE INDEX ix_hogar_ipm            ON Hogar (fgpobrezamultidimensional);
GO


-- =====================================================================
-- 5. DETALLES DEL HOGAR
--    Normalizan 43 variables del archivo plano en 3 tablas.
-- =====================================================================

-- 16 variables: 8 pares fggasto* / mngasto*  (preguntas 41A–41H)
CREATE TABLE HogarGasto (
  idhogar      VARCHAR(20)      NOT NULL, -- Hogar al que corresponde el gasto
  cdrubrogasto TINYINT NOT NULL, -- Rubro de gasto; catálogo rubrogasto
  fggasto      TINYINT NOT NULL, -- 1 Sí, 2 No, 9 Sí pero no sabe el valor
  mngasto      DECIMAL(15,2)    NULL, -- Valor mensual del gasto; nulo si fggasto <> 1

  CONSTRAINT pk_hogargasto PRIMARY KEY (idhogar, cdrubrogasto),
  CONSTRAINT fk_hogargasto_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON DELETE CASCADE,
  CONSTRAINT ck_hogargasto_rubro CHECK (cdrubrogasto BETWEEN 1 AND 8),
  CONSTRAINT ck_hogargasto_flag  CHECK (fggasto IN (1, 2, 9)),
  CONSTRAINT ck_hogargasto_valor CHECK (
    (fggasto = 1 AND mngasto IS NOT NULL AND mngasto >= 0)
    OR (fggasto <> 1 AND (mngasto IS NULL OR mngasto = 0))
  )
);
GO
-- Gastos mensuales del hogar por rubro (normaliza 16 variables)

CREATE INDEX ix_hogargasto_rubro ON HogarGasto (cdrubrogasto);
GO

-- 12 variables: 6 pares fgevento* / qtevento*  (preguntas 43A–43F)
CREATE TABLE HogarEvento (
  idhogar      VARCHAR(20)       NOT NULL, -- Hogar afectado
  cdtipoevento TINYINT  NOT NULL, -- Tipo de evento; catálogo tipoevento
  fgevento     TINYINT  NOT NULL, -- 1 Sí, 2 No
  qtevento     INT NULL, -- Número de veces; nulo si fgevento = 2

  CONSTRAINT pk_hogarevento PRIMARY KEY (idhogar, cdtipoevento),
  CONSTRAINT fk_hogarevento_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON DELETE CASCADE,
  CONSTRAINT ck_hogarevento_tipo CHECK (cdtipoevento BETWEEN 1 AND 6),
  CONSTRAINT ck_hogarevento_flag CHECK (fgevento IN (1, 2)),
  CONSTRAINT ck_hogarevento_conteo CHECK (
    (fgevento = 1 AND qtevento >= 1) OR (fgevento = 2 AND qtevento IS NULL)
  )
);
GO
-- Eventos de riesgo que han afectado la vivienda (normaliza 12 variables)

CREATE INDEX ix_hogarevento_tipo ON HogarEvento (cdtipoevento);
GO

-- 15 variables: I1 a I15
CREATE TABLE HogarPrivacionIpm (
  idhogar        VARCHAR(20)      NOT NULL, -- Hogar evaluado
  cdprivacionipm TINYINT NOT NULL, -- Privación I1–I15; catálogo privacionipm
  fgprivacion    TINYINT NOT NULL, -- 0 No privado, 1 Privado

  CONSTRAINT pk_hogarprivacionipm PRIMARY KEY (idhogar, cdprivacionipm),
  CONSTRAINT fk_hogarprivacionipm_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON DELETE CASCADE,
  CONSTRAINT ck_hogarprivacionipm_codigo CHECK (cdprivacionipm BETWEEN 1 AND 15),
  CONSTRAINT ck_hogarprivacionipm_flag   CHECK (fgprivacion IN (0, 1))
);
GO
-- Privaciones IPM del hogar, I1–I15 (normaliza 15 variables)

CREATE INDEX ix_hogarprivacionipm_codigo ON HogarPrivacionIpm (cdprivacionipm);
GO


-- =====================================================================
-- 6. PERSONA  (20 variables del diccionario)
-- =====================================================================

CREATE TABLE Persona (
  idpersona                BIGINT   NOT NULL, -- Clave sustituta; NO viene en el archivo fuente
  idhogar                  VARCHAR(20)       NOT NULL, -- Hogar al que pertenece la persona
  qtordenpersona           TINYINT  NOT NULL, -- Número de orden dentro del hogar; se genera en la carga. Es el valor al que apuntan ide_conyuge, ide_padre e ide_serv_domestico

  -- Demografía
  cdsexo                   TINYINT  NOT NULL, -- sexo_persona — 1 Hombre, 2 Mujer
  qtedad                   INT NOT NULL, -- edad_calculada — variable derivada
  cdparentesco             TINYINT  NOT NULL, -- tip_parentesco — pregunta 54
  cdestadocivil            TINYINT  NOT NULL, -- tip_estado_civil — pregunta 55

  -- Salud  (DATO SENSIBLE — Ley 1581 de 2012)
  cdseguridadsocial        TINYINT  NOT NULL, -- tip_seg_social — pregunta 60
  fgenfermo30dias          TINYINT  NOT NULL, -- ind_enfermo_30 — pregunta 61
  fgacudioserviciosalud    TINYINT  NOT NULL, -- ind_acudio_salud — pregunta 62
  fgatendidosalud          TINYINT  NOT NULL, -- ind_fue_atendido_salud — pregunta 63
  fgembarazo               TINYINT  NOT NULL, -- ind_esta_embarazada — pregunta 64
  fghijosnacidosvivos      TINYINT  NOT NULL, -- ind_tuvo_hijos — pregunta 65

  -- Primera infancia
  cdcuidadoninos           TINYINT  NOT NULL, -- tip_cuidado_niños — pregunta 66
  fgrecibealimentacion     TINYINT  NOT NULL, -- ind_recibe_comida — pregunta 67

  -- Educación
  fgleerescribir           TINYINT  NOT NULL, -- ind_leer_escribir — pregunta 68
  fgestudia                TINYINT  NOT NULL, -- ind_estudia — pregunta 69
  cdniveleducativo         TINYINT  NOT NULL, -- niv_educativo — pregunta 70
  cdgrado                  TINYINT  NOT NULL, -- grado_alcanzado — 0–13, 99 No aplica

  -- Actividad económica
  fgcotizapension          TINYINT  NOT NULL, -- ind_fondo_pensiones — pregunta 71
  cdactividadprincipal     TINYINT  NOT NULL, -- tip_actividad_mes — pregunta 72
  qtsemanasbuscandotrabajo INT NOT NULL, -- num_sem_buscando — 999 No aplica
  cdtipoempleo             TINYINT  NOT NULL, -- tip_empleado — 99 No aplica

  CONSTRAINT pk_persona PRIMARY KEY (idpersona),
  CONSTRAINT uq_persona_orden UNIQUE (idhogar, qtordenpersona),

  CONSTRAINT fk_persona_hogar
    FOREIGN KEY (idhogar) REFERENCES Hogar (idhogar)
    ON DELETE CASCADE,

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
);
GO
-- Persona: demografía, salud, educación y actividad económica

CREATE INDEX ix_persona_hogar        ON Persona (idhogar);
GO
CREATE INDEX ix_persona_parentesco   ON Persona (cdparentesco);
GO
CREATE INDEX ix_persona_sexo_edad    ON Persona (cdsexo, qtedad);
GO
CREATE INDEX ix_persona_niveleducativo ON Persona (cdniveleducativo);
GO


-- =====================================================================
-- 7. DETALLES DE LA PERSONA
--    Normalizan 35 variables del archivo plano en 3 tablas.
-- =====================================================================

-- 6 variables: ind_conyuge_vive_hogar / ide_conyuge,
--              ind_padre_vive_hogar / ide_padre,
--              ind_pariente_domestico / ide_serv_domestico
CREATE TABLE PersonaRelacion (
  idpersona             BIGINT  NOT NULL, -- Persona declarante
  cdtiporelacion        TINYINT NOT NULL, -- 1 Cónyuge, 2 Padre o madre, 3 Servicio doméstico o pensionista
  fgvivehogar           TINYINT NOT NULL, -- 1 Sí, 2 No, 9 No aplica
  idpersonarelacionada  BIGINT  NULL, -- Persona referida; nulo si fgvivehogar <> 1

  CONSTRAINT pk_personarelacion PRIMARY KEY (idpersona, cdtiporelacion),
  CONSTRAINT fk_personarelacion_persona
    FOREIGN KEY (idpersona) REFERENCES Persona (idpersona)
    ON DELETE CASCADE,
  CONSTRAINT fk_personarelacion_relacionada
    FOREIGN KEY (idpersonarelacionada) REFERENCES Persona (idpersona)
    ON DELETE NO ACTION,
  CONSTRAINT ck_personarelacion_tipo CHECK (cdtiporelacion BETWEEN 1 AND 3),
  CONSTRAINT ck_personarelacion_flag CHECK (fgvivehogar IN (1, 2, 9)),
  CONSTRAINT ck_personarelacion_referencia CHECK (
    (fgvivehogar = 1 AND idpersonarelacionada IS NOT NULL)
    OR (fgvivehogar <> 1 AND idpersonarelacionada IS NULL)
  ),
  CONSTRAINT ck_personarelacion_noautoreferencia
    CHECK (idpersonarelacionada IS NULL OR idpersonarelacionada <> idpersona)
);
GO
-- Relaciones entre personas del mismo hogar (normaliza 6 variables)

CREATE INDEX ix_personarelacion_relacionada ON PersonaRelacion (idpersonarelacionada);
GO

-- 8 variables: ind_discap_* (DATO SENSIBLE — Ley 1581 de 2012)
CREATE TABLE PersonaDiscapacidad (
  idpersona          BIGINT  NOT NULL, -- Persona evaluada
  cdtipodiscapacidad TINYINT NOT NULL, -- 1 Ver, 2 Oír, 3 Hablar, 4 Moverse, 5 Bañarse, 6 Salir, 7 Entender, 8 Ninguna
  fgdiscapacidad     TINYINT NOT NULL, -- 1 Sí, 2 No

  CONSTRAINT pk_personadiscapacidad PRIMARY KEY (idpersona, cdtipodiscapacidad),
  CONSTRAINT fk_personadiscapacidad_persona
    FOREIGN KEY (idpersona) REFERENCES Persona (idpersona)
    ON DELETE CASCADE,
  CONSTRAINT ck_personadiscapacidad_tipo CHECK (cdtipodiscapacidad BETWEEN 1 AND 8),
  CONSTRAINT ck_personadiscapacidad_flag CHECK (fgdiscapacidad IN (1, 2))
);
GO
-- Limitaciones permanentes, pregunta 59. DATO SENSIBLE (normaliza 8 variables)

CREATE INDEX ix_personadiscapacidad_tipo ON PersonaDiscapacidad (cdtipodiscapacidad);
GO

-- 21 variables: 9 fuentes de ingreso + 3 subsidios del Estado
-- (DATO SENSIBLE — Ley 1581 de 2012)
CREATE TABLE PersonaIngreso (
  idpersona       BIGINT  NOT NULL, -- Persona perceptora
  cdfuenteingreso TINYINT NOT NULL, -- Fuente de ingreso; catálogo fuenteingreso
  fgingreso       TINYINT NOT NULL, -- 1 Sí, 2 No, 9 Sí pero no sabe el valor, 99 No aplica
  mningreso       DECIMAL(15,2)    NULL, -- Valor del ingreso del mes pasado; nulo si fgingreso <> 1
  qtmesesingreso  TINYINT NULL, -- num_mes_ingr_cosecha — solo aplica a la fuente 3 (cosecha); 0–12 o 99

  CONSTRAINT pk_personaingreso PRIMARY KEY (idpersona, cdfuenteingreso),
  CONSTRAINT fk_personaingreso_persona
    FOREIGN KEY (idpersona) REFERENCES Persona (idpersona)
    ON DELETE CASCADE,
  CONSTRAINT ck_personaingreso_fuente CHECK (cdfuenteingreso BETWEEN 1 AND 12),
  CONSTRAINT ck_personaingreso_flag   CHECK (fgingreso IN (1, 2, 9, 99)),
  CONSTRAINT ck_personaingreso_valor CHECK (
    (fgingreso = 1 AND mningreso IS NOT NULL AND mningreso >= 0)
    OR (fgingreso <> 1 AND (mningreso IS NULL OR mningreso = 0))
    OR (cdfuenteingreso = 9 AND mningreso IS NULL)
  ),
  -- qtmesesingreso solo tiene sentido en la fuente 3 (ganancia de la cosecha)
  CONSTRAINT ck_personaingreso_meses CHECK (
    (cdfuenteingreso = 3 AND (qtmesesingreso BETWEEN 0 AND 12 OR qtmesesingreso = 99))
    OR (cdfuenteingreso <> 3 AND qtmesesingreso IS NULL)
  )
);
GO
-- Ingresos de la persona por fuente. DATO SENSIBLE (normaliza 21 variables)

CREATE INDEX ix_personaingreso_fuente ON PersonaIngreso (cdfuenteingreso);
GO


-- =====================================================================
-- COBERTURA DE VARIABLES
--   Vivienda             21   Persona                20
--   Hogar                32   PersonaRelacion         6
--   HogarGasto           16   PersonaDiscapacidad     8
--   HogarEvento          12   PersonaIngreso         21
--   HogarPrivacionIpm    15   -----------------------------
--                             TOTAL                 151
-- =====================================================================

SET NOEXEC OFF;
GO
