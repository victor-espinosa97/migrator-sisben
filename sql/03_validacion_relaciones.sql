-- =====================================================================
-- SISBÉN IV — Validación de relaciones (solo lectura)
-- Muestra unas viviendas completas con todas sus tablas relacionadas
-- y al final un resumen de reglas que deben dar 0 en toda la base.
--
-- Uso en TablePlus: pegar todo y ejecutar todo (Cmd + Shift + Enter).
-- Cada consulta sale en su propia pestaña de resultados.
--
-- Tamaño de la muestra: cada bloque empieza con el mismo «muestra».
-- Toma las 3 viviendas con más hogares (así se ve la relación 1 a N).
-- Para cambiarlo, reemplazar «TOP 3» en TODOS los bloques.
--
-- Base: ejecutar conectado a la base donde están las tablas PLN
-- (hoy rawriodata en SV-SQL-RIODATA). No lleva USE para no depender
-- del nombre de la base.
--
-- Compatibilidad SQL Server: sin COUNT(DISTINCT ...) OVER (no se
-- permite) y textos con acentos con prefijo N.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CADENA PRINCIPAL: territorio → vivienda → hogar → persona
--    Una fila por persona.
-- ---------------------------------------------------------------------
WITH muestra AS (
  SELECT h.idhogar
  FROM PLN001009 h
  WHERE h.idvivienda IN (
    SELECT TOP 3 idvivienda FROM PLN001009
    GROUP BY idvivienda ORDER BY COUNT(*) DESC, idvivienda
  )
)
SELECT
  v.idvivienda,
  dep.nmdepartamento                           AS departamento,
  mun.nmmunicipio                              AS municipio,
  c_clase.dsvalor                              AS clase,
  cor.nmcorregimiento                          AS corregimiento,
  ver.nmvereda                                 AS vereda,
  bar.nmbarrio                                 AS barrio,
  c_tviv.dsvalor                               AS tipo_vivienda,
  v.qthogaresvivienda                          AS hogares_declarados,
  (SELECT COUNT(*) FROM PLN001009 hx
   WHERE hx.idvivienda = v.idvivienda)         AS hogares_cargados,
  h.idhogar,
  h.cdclasificacionsisben                      AS clasificacion,
  c_clas.cdagrupacion                          AS grupo_sisben,
  h.qtpersonashogar                            AS personas_declaradas,
  COUNT(*) OVER (PARTITION BY h.idhogar)       AS personas_cargadas,
  p.idpersona,
  p.qtordenpersona                             AS orden,
  CASE p.cdsexo WHEN 1 THEN N'Hombre' WHEN 2 THEN N'Mujer' END AS sexo,
  p.qtedad                                     AS edad,
  c_par.dsvalor                                AS parentesco,
  c_civ.dsvalor                                AS estado_civil,
  c_edu.dsvalor                                AS nivel_educativo,
  c_act.dsvalor                                AS actividad
FROM muestra m
JOIN PLN001009 h        ON h.idhogar = m.idhogar
JOIN PLN001008 v        ON v.idvivienda = h.idvivienda
JOIN PLN001004 mun      ON mun.cdmunicipio = v.cdmunicipio
JOIN PLN001003 dep      ON dep.cddpto = mun.cddpto
LEFT JOIN PLN001005 cor ON cor.cdcorregimiento = v.cdcorregimiento
LEFT JOIN PLN001006 ver ON ver.cdvereda = v.cdvereda
LEFT JOIN PLN001007 bar ON bar.cdbarrio = v.cdbarrio
LEFT JOIN PLN001013 p   ON p.idhogar = h.idhogar
LEFT JOIN PLN001002 c_clase ON c_clase.cddominio = 'clase'               AND c_clase.cdvalor = CAST(v.cdclase AS VARCHAR(3))
LEFT JOIN PLN001002 c_tviv  ON c_tviv.cddominio  = 'tipovivienda'        AND c_tviv.cdvalor  = CAST(v.cdtipovivienda AS VARCHAR(3))
LEFT JOIN PLN001002 c_clas  ON c_clas.cddominio  = 'clasificacionsisben' AND c_clas.cdvalor  = h.cdclasificacionsisben
LEFT JOIN PLN001002 c_par   ON c_par.cddominio   = 'parentesco'          AND c_par.cdvalor   = CAST(p.cdparentesco AS VARCHAR(3))
LEFT JOIN PLN001002 c_civ   ON c_civ.cddominio   = 'estadocivil'         AND c_civ.cdvalor   = CAST(p.cdestadocivil AS VARCHAR(3))
LEFT JOIN PLN001002 c_edu   ON c_edu.cddominio   = 'niveleducativo'      AND c_edu.cdvalor   = CAST(p.cdniveleducativo AS VARCHAR(3))
LEFT JOIN PLN001002 c_act   ON c_act.cddominio   = 'actividadprincipal'  AND c_act.cdvalor   = CAST(p.cdactividadprincipal AS VARCHAR(3))
ORDER BY v.idvivienda, h.idhogar, p.qtordenpersona;


-- ---------------------------------------------------------------------
-- 2. GASTOS DEL HOGAR (PLN001010 → PLN001009). Deben ser 8 por hogar.
--    suma_rubros debe coincidir con gasto_total del hogar.
-- ---------------------------------------------------------------------
WITH muestra AS (
  SELECT h.idhogar
  FROM PLN001009 h
  WHERE h.idvivienda IN (
    SELECT TOP 3 idvivienda FROM PLN001009
    GROUP BY idvivienda ORDER BY COUNT(*) DESC, idvivienda
  )
)
SELECT
  h.idhogar,
  g.cdrubrogasto,
  c_rub.dsvalor                                       AS rubro,
  c_fg.dsvalor                                        AS tiene_gasto,
  g.mngasto,
  COUNT(*) OVER (PARTITION BY h.idhogar)              AS rubros_cargados,
  SUM(ISNULL(g.mngasto, 0)) OVER (PARTITION BY h.idhogar) AS suma_rubros,
  h.mngastototal                                      AS gasto_total_hogar
FROM muestra m
JOIN PLN001009 h      ON h.idhogar = m.idhogar
LEFT JOIN PLN001010 g ON g.idhogar = h.idhogar
LEFT JOIN PLN001002 c_rub ON c_rub.cddominio = 'rubrogasto' AND c_rub.cdvalor = CAST(g.cdrubrogasto AS VARCHAR(3))
LEFT JOIN PLN001002 c_fg  ON c_fg.cddominio  = 'gasto'      AND c_fg.cdvalor  = CAST(g.fggasto AS VARCHAR(3))
ORDER BY h.idhogar, g.cdrubrogasto;


-- ---------------------------------------------------------------------
-- 3. EVENTOS DE RIESGO (PLN001011 → PLN001009). Deben ser 6 por hogar.
-- ---------------------------------------------------------------------
WITH muestra AS (
  SELECT h.idhogar
  FROM PLN001009 h
  WHERE h.idvivienda IN (
    SELECT TOP 3 idvivienda FROM PLN001009
    GROUP BY idvivienda ORDER BY COUNT(*) DESC, idvivienda
  )
)
SELECT
  h.idhogar,
  e.cdtipoevento,
  c_ev.dsvalor                              AS evento,
  c_fg.dsvalor                              AS ocurrio,
  e.qtevento                                AS veces,
  COUNT(*) OVER (PARTITION BY h.idhogar)    AS eventos_cargados
FROM muestra m
JOIN PLN001009 h      ON h.idhogar = m.idhogar
LEFT JOIN PLN001011 e ON e.idhogar = h.idhogar
LEFT JOIN PLN001002 c_ev ON c_ev.cddominio = 'tipoevento' AND c_ev.cdvalor = CAST(e.cdtipoevento AS VARCHAR(3))
LEFT JOIN PLN001002 c_fg ON c_fg.cddominio = 'sino'       AND c_fg.cdvalor = CAST(e.fgevento AS VARCHAR(3))
ORDER BY h.idhogar, e.cdtipoevento;


-- ---------------------------------------------------------------------
-- 4. PRIVACIONES IPM (PLN001012 → PLN001009). Deben ser 15 por hogar.
-- ---------------------------------------------------------------------
WITH muestra AS (
  SELECT h.idhogar
  FROM PLN001009 h
  WHERE h.idvivienda IN (
    SELECT TOP 3 idvivienda FROM PLN001009
    GROUP BY idvivienda ORDER BY COUNT(*) DESC, idvivienda
  )
)
SELECT
  h.idhogar,
  h.fgpobrezamultidimensional               AS pobre_ipm,
  i.cdprivacionipm,
  c_pr.dsvalor                              AS privacion,
  i.fgprivacion                             AS privado,
  COUNT(*) OVER (PARTITION BY h.idhogar)    AS privaciones_cargadas
FROM muestra m
JOIN PLN001009 h      ON h.idhogar = m.idhogar
LEFT JOIN PLN001012 i ON i.idhogar = h.idhogar
LEFT JOIN PLN001002 c_pr ON c_pr.cddominio = 'privacionipm' AND c_pr.cdvalor = CAST(i.cdprivacionipm AS VARCHAR(3))
ORDER BY h.idhogar, i.cdprivacionipm;


-- ---------------------------------------------------------------------
-- 5. RELACIONES ENTRE PERSONAS (PLN001014 → PLN001013, dos veces).
--    Deben ser 3 por persona. La persona referida debe ser del
--    mismo hogar.
-- ---------------------------------------------------------------------
WITH muestra AS (
  SELECT h.idhogar
  FROM PLN001009 h
  WHERE h.idvivienda IN (
    SELECT TOP 3 idvivienda FROM PLN001009
    GROUP BY idvivienda ORDER BY COUNT(*) DESC, idvivienda
  )
)
SELECT
  p.idhogar,
  p.idpersona,
  p.qtordenpersona                          AS orden,
  c_par.dsvalor                             AS parentesco,
  c_rel.dsvalor                             AS tipo_relacion,
  c_vive.dsvalor                            AS vive_en_hogar,
  r.idpersonarelacionada,
  rel.qtordenpersona                        AS orden_referido,
  c_par2.dsvalor                            AS parentesco_referido,
  CASE
    WHEN r.idpersonarelacionada IS NULL THEN N'—'
    WHEN rel.idhogar = p.idhogar        THEN N'OK'
    ELSE N'ERROR: otro hogar'
  END                                       AS validacion,
  COUNT(*) OVER (PARTITION BY p.idpersona)  AS relaciones_cargadas
FROM muestra m
JOIN PLN001013 p        ON p.idhogar = m.idhogar
LEFT JOIN PLN001014 r   ON r.idpersona = p.idpersona
LEFT JOIN PLN001013 rel ON rel.idpersona = r.idpersonarelacionada
LEFT JOIN PLN001002 c_par  ON c_par.cddominio  = 'parentesco'   AND c_par.cdvalor  = CAST(p.cdparentesco AS VARCHAR(3))
LEFT JOIN PLN001002 c_par2 ON c_par2.cddominio = 'parentesco'   AND c_par2.cdvalor = CAST(rel.cdparentesco AS VARCHAR(3))
LEFT JOIN PLN001002 c_rel  ON c_rel.cddominio  = 'tiporelacion' AND c_rel.cdvalor  = CAST(r.cdtiporelacion AS VARCHAR(3))
LEFT JOIN PLN001002 c_vive ON c_vive.cddominio = 'sino9'        AND c_vive.cdvalor = CAST(r.fgvivehogar AS VARCHAR(3))
ORDER BY p.idhogar, p.qtordenpersona, r.cdtiporelacion;


-- ---------------------------------------------------------------------
-- 6. DISCAPACIDAD (PLN001015 → PLN001013). Deben ser 8 por persona.
-- ---------------------------------------------------------------------
WITH muestra AS (
  SELECT h.idhogar
  FROM PLN001009 h
  WHERE h.idvivienda IN (
    SELECT TOP 3 idvivienda FROM PLN001009
    GROUP BY idvivienda ORDER BY COUNT(*) DESC, idvivienda
  )
)
SELECT
  p.idhogar,
  p.idpersona,
  p.qtordenpersona                          AS orden,
  d.cdtipodiscapacidad,
  c_dis.dsvalor                             AS limitacion,
  c_fg.dsvalor                              AS tiene,
  COUNT(*) OVER (PARTITION BY p.idpersona)  AS registros_cargados
FROM muestra m
JOIN PLN001013 p      ON p.idhogar = m.idhogar
LEFT JOIN PLN001015 d ON d.idpersona = p.idpersona
LEFT JOIN PLN001002 c_dis ON c_dis.cddominio = 'tipodiscapacidad' AND c_dis.cdvalor = CAST(d.cdtipodiscapacidad AS VARCHAR(3))
LEFT JOIN PLN001002 c_fg  ON c_fg.cddominio  = 'sino'             AND c_fg.cdvalor  = CAST(d.fgdiscapacidad AS VARCHAR(3))
ORDER BY p.idhogar, p.qtordenpersona, d.cdtipodiscapacidad;


-- ---------------------------------------------------------------------
-- 7. INGRESOS (PLN001016 → PLN001013). Deben ser 12 por persona.
-- ---------------------------------------------------------------------
WITH muestra AS (
  SELECT h.idhogar
  FROM PLN001009 h
  WHERE h.idvivienda IN (
    SELECT TOP 3 idvivienda FROM PLN001009
    GROUP BY idvivienda ORDER BY COUNT(*) DESC, idvivienda
  )
)
SELECT
  p.idhogar,
  p.idpersona,
  p.qtordenpersona                          AS orden,
  ing.cdfuenteingreso,
  c_fte.dsvalor                             AS fuente,
  c_fg.dsvalor                              AS recibe,
  ing.mningreso,
  ing.qtmesesingreso,
  COUNT(*) OVER (PARTITION BY p.idpersona)  AS fuentes_cargadas
FROM muestra m
JOIN PLN001013 p        ON p.idhogar = m.idhogar
LEFT JOIN PLN001016 ing ON ing.idpersona = p.idpersona
LEFT JOIN PLN001002 c_fte ON c_fte.cddominio = 'fuenteingreso' AND c_fte.cdvalor = CAST(ing.cdfuenteingreso AS VARCHAR(3))
LEFT JOIN PLN001002 c_fg  ON c_fg.cddominio  = 'ingreso'       AND c_fg.cdvalor  = CAST(ing.fgingreso AS VARCHAR(3))
ORDER BY p.idhogar, p.qtordenpersona, ing.cdfuenteingreso;


-- ---------------------------------------------------------------------
-- 8. RESUMEN DE TODA LA BASE
--    «Error»: debe dar 0. «Aviso»: puede no ser 0, pero hay que mirarlo.
-- ---------------------------------------------------------------------
SELECT N'Error' AS tipo, N'Viviendas sin ningún hogar' AS regla, COUNT(*) AS total
FROM PLN001008 v
WHERE NOT EXISTS (SELECT 1 FROM PLN001009 h WHERE h.idvivienda = v.idvivienda)

UNION ALL
SELECT N'Error', N'Hogares sin ninguna persona', COUNT(*)
FROM PLN001009 h
WHERE NOT EXISTS (SELECT 1 FROM PLN001013 p WHERE p.idhogar = h.idhogar)

UNION ALL
SELECT N'Error', N'Hogares sin exactamente 8 gastos', COUNT(*)
FROM PLN001009 h
WHERE (SELECT COUNT(*) FROM PLN001010 g WHERE g.idhogar = h.idhogar) <> 8

UNION ALL
SELECT N'Error', N'Hogares sin exactamente 6 eventos', COUNT(*)
FROM PLN001009 h
WHERE (SELECT COUNT(*) FROM PLN001011 e WHERE e.idhogar = h.idhogar) <> 6

UNION ALL
SELECT N'Error', N'Hogares sin exactamente 15 privaciones IPM', COUNT(*)
FROM PLN001009 h
WHERE (SELECT COUNT(*) FROM PLN001012 i WHERE i.idhogar = h.idhogar) <> 15

UNION ALL
SELECT N'Error', N'Personas sin exactamente 3 relaciones', COUNT(*)
FROM PLN001013 p
WHERE (SELECT COUNT(*) FROM PLN001014 r WHERE r.idpersona = p.idpersona) <> 3

UNION ALL
SELECT N'Error', N'Personas sin exactamente 8 registros de discapacidad', COUNT(*)
FROM PLN001013 p
WHERE (SELECT COUNT(*) FROM PLN001015 d WHERE d.idpersona = p.idpersona) <> 8

UNION ALL
SELECT N'Error', N'Personas sin exactamente 12 fuentes de ingreso', COUNT(*)
FROM PLN001013 p
WHERE (SELECT COUNT(*) FROM PLN001016 i WHERE i.idpersona = p.idpersona) <> 12

UNION ALL
SELECT N'Error', N'Relaciones que apuntan a una persona de otro hogar', COUNT(*)
FROM PLN001014 r
JOIN PLN001013 p   ON p.idpersona = r.idpersona
JOIN PLN001013 rel ON rel.idpersona = r.idpersonarelacionada
WHERE rel.idhogar <> p.idhogar

UNION ALL
SELECT N'Error', N'Barrios de otro municipio que el de la vivienda', COUNT(*)
FROM PLN001008 v
JOIN PLN001007 b ON b.cdbarrio = v.cdbarrio
WHERE b.cdmunicipio <> v.cdmunicipio

UNION ALL
SELECT N'Error', N'Valores de catálogo sin dominio', COUNT(*)
FROM PLN001002 cv
WHERE NOT EXISTS (SELECT 1 FROM PLN001001 d WHERE d.cddominio = cv.cddominio)

UNION ALL
SELECT N'Aviso', N'Hogares sin jefe (parentesco 1) o con más de uno', COUNT(*)
FROM PLN001009 h
WHERE (SELECT COUNT(*) FROM PLN001013 p WHERE p.idhogar = h.idhogar AND p.cdparentesco = 1) <> 1

UNION ALL
SELECT N'Aviso', N'Hogares cuyas personas cargadas no coinciden con las declaradas', COUNT(*)
FROM PLN001009 h
WHERE h.qtpersonashogar <> (SELECT COUNT(*) FROM PLN001013 p WHERE p.idhogar = h.idhogar)

UNION ALL
SELECT N'Aviso', N'Viviendas cuyos hogares cargados no coinciden con los declarados', COUNT(*)
FROM PLN001008 v
WHERE v.qthogaresvivienda <> (SELECT COUNT(*) FROM PLN001009 h WHERE h.idvivienda = v.idvivienda)

UNION ALL
SELECT N'Aviso', N'Hogares cuyo gasto total no es la suma de los rubros', COUNT(*)
FROM PLN001009 h
WHERE h.mngastototal <> (SELECT ISNULL(SUM(g.mngasto), 0) FROM PLN001010 g WHERE g.idhogar = h.idhogar)

UNION ALL
SELECT N'Aviso', N'Parentescos sin etiqueta en el catálogo', COUNT(*)
FROM PLN001013 p
WHERE NOT EXISTS (
  SELECT 1 FROM PLN001002 c
  WHERE c.cddominio = 'parentesco' AND c.cdvalor = CAST(p.cdparentesco AS VARCHAR(3))
)

UNION ALL
SELECT N'Aviso', N'Clasificaciones SISBÉN sin etiqueta en el catálogo', COUNT(*)
FROM PLN001009 h
WHERE NOT EXISTS (
  SELECT 1 FROM PLN001002 c
  WHERE c.cddominio = 'clasificacionsisben' AND c.cdvalor = h.cdclasificacionsisben
)

-- Si estos totales dan 0, la carga no se hizo y los 0 de arriba no validan nada
UNION ALL
SELECT N'Info', N'Total de viviendas cargadas (PLN001008)', COUNT(*) FROM PLN001008

UNION ALL
SELECT N'Info', N'Total de personas cargadas (PLN001013)', COUNT(*) FROM PLN001013

ORDER BY tipo DESC, regla;
