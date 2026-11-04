# config/settings.py

import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

# 🔥 "1" = valida y reporta sin tocar la base de datos
SOLO_VALIDAR = os.getenv("SOLO_VALIDAR", "0") == "1"

INPUT_FILE = "insumos/BD anonimizada Rionegro_planeacion_07022026 (1).xlsx"

TAMANO_LOTE = 10000

# 🔥 Si cae por debajo, el archivo cambió de forma y la carga se detiene
MINIMO_HOGARES_CUADRAN = 0.99

DEPARTAMENTOS = {"05": "Antioquia"}
MUNICIPIOS = {"05615": "Rionegro"}

SIN_TERRITORIO = ["SIN CORREGIMIENTO", "SIN VEREDA"]
BARRIO_ENMASCARADO = "BARRIO_S4"

COLUMNAS_VIVIENDA = [
    "COD_DPTO",
    "COD_MPIO",
    "COD_CLASE",
    "COD_CORREGIMIENTO",
    "NOM_CORREGIMIENTO",
    "COD_VEREDA",
    "NOM_VEREDA",
    "COD_BARRIO",
    "NOM_BARRIO",
    "TIP_VIVIENDA",
    "TIP_MAT_PAREDES",
    "TIP_MAT_PISOS",
    "IND_TIENE_ENERGIA",
    "TIP_ESTRATO_ENERGIA",
    "IND_TIENE_ALCANTARILLADO",
    "IND_TIENE_GAS",
    "IND_TIENE_RECOLECCION",
    "IND_TIENE_ACUEDUCTO",
    "TIP_ESTRATO_ACUEDUCTO",
    "NUM_CUARTOS_VIVIENDA",
    "NUM_HOGARES_VIVIENDA"
]

COLUMNAS_HOGAR = [
    "IDE_HOGAR",
    "TIP_OCUPA_VIVIENDA",
    "NUM_CUARTOS_EXCLUSIVOS",
    "NUM_CUARTOS_DORMIR",
    "NUM_CUARTOS_UNICOS_DORMIR",
    "TIP_SANITARIO",
    "TIP_UBI_SANITARIO",
    "TIP_USO_SANITARIO",
    "TIP_ORIGEN_AGUA",
    "IND_AGUA_LLEGA_7DIAS",
    "NUM_DIAS_LLEGA",
    "IND_AGUA_LLEGA_24HORAS",
    "NUM_HORAS_LLEGA",
    "TIP_USO_AGUA_BEBER",
    "TIP_ELIMINA_BASURA",
    "IND_TIENE_COCINA",
    "TIP_PREPARA_ALIMENTOS",
    "TIP_USO_COCINA",
    "TIP_ENERGIA_COCINA",
    "IND_TIENE_NEVERA",
    "IND_TIENE_LAVADORA",
    "IND_TIENE_PC",
    "IND_TIENE_INTERNET",
    "IND_TIENE_MOTO",
    "IND_TIENE_TRACTOR",
    "IND_TIENE_CARRO",
    "IND_TIENE_BIEN_RAIZ",
    "IND_GASTO_ALIMENTO",
    "VLR_GASTO_ALIMENTO",
    "IND_GASTO_TRANSPORTE",
    "VLR_GASTO_TRANSPORTE",
    "IND_GASTO_EDUCACION",
    "VLR_GASTO_EDUCACION",
    "IND_GASTO_SALUD",
    "VLR_GASTO_SALUD",
    "IND_GASTO_SERV_PUBLICOS",
    "VLR_GASTO_SERV_PUBLICOS",
    "IND_GASTO_CELULAR",
    "VLR_GASTO_CELULAR",
    "IND_GASTO_ARRIENDO",
    "VLR_GASTO_ARRIENDO",
    "IND_GASTO_OTROS",
    "VLR_GASTO_OTROS",
    "VLR_TOTAL_GASTOS",
    "NUM_HABITA_VIVIENDA",
    "IND_EVENTO_INUNDACION",
    "NUM_EVENTO_INUNDACION",
    "IND_EVENTO_AVALANCHA",
    "NUM_EVENTO_AVALANCHA",
    "IND_EVENTO_TERREMOTO",
    "NUM_EVENTO_TERREMOTO",
    "IND_EVENTO_INCENDIO",
    "NUM_EVENTO_INCENDIO",
    "IND_EVENTO_VENDAVAL",
    "NUM_EVENTO_VENDAVAL",
    "IND_EVENTO_HUNDIMIENTO",
    "NUM_EVENTO_HUNDIMIENTO",
    "NUM_PERSONAS_HOGAR"
]

COLUMNAS_IPM = [
    "H_5",
    "I1",
    "I2",
    "I3",
    "I4",
    "I5",
    "I6",
    "I7",
    "I8",
    "I9",
    "I10",
    "I11",
    "I12",
    "I13",
    "I14",
    "I15",
    "CLASIFICACION"
]

# 🔥 Todas las personas de un hogar comparten estas 96 columnas
COLUMNAS_FIRMA_HOGAR = COLUMNAS_VIVIENDA + COLUMNAS_HOGAR + COLUMNAS_IPM

COLUMNAS_TEXTO = [
    "COD_DPTO",
    "COD_MPIO",
    "COD_CORREGIMIENTO",
    "NOM_CORREGIMIENTO",
    "COD_VEREDA",
    "NOM_VEREDA",
    "COD_BARRIO",
    "NOM_BARRIO",
    "CLASIFICACION"
]

COLUMNAS_SIN_DATO = [
    "COD_CORREGIMIENTO",
    "COD_VEREDA",
    "COD_BARRIO"
]

# 🔥 Grupos repetidos: (código, indicador, valor)
GRUPOS_GASTO = [
    (1, "IND_GASTO_ALIMENTO", "VLR_GASTO_ALIMENTO"),
    (2, "IND_GASTO_TRANSPORTE", "VLR_GASTO_TRANSPORTE"),
    (3, "IND_GASTO_EDUCACION", "VLR_GASTO_EDUCACION"),
    (4, "IND_GASTO_SALUD", "VLR_GASTO_SALUD"),
    (5, "IND_GASTO_SERV_PUBLICOS", "VLR_GASTO_SERV_PUBLICOS"),
    (6, "IND_GASTO_CELULAR", "VLR_GASTO_CELULAR"),
    (7, "IND_GASTO_ARRIENDO", "VLR_GASTO_ARRIENDO"),
    (8, "IND_GASTO_OTROS", "VLR_GASTO_OTROS")
]

GRUPOS_EVENTO = [
    (1, "IND_EVENTO_INUNDACION", "NUM_EVENTO_INUNDACION"),
    (2, "IND_EVENTO_AVALANCHA", "NUM_EVENTO_AVALANCHA"),
    (3, "IND_EVENTO_TERREMOTO", "NUM_EVENTO_TERREMOTO"),
    (4, "IND_EVENTO_INCENDIO", "NUM_EVENTO_INCENDIO"),
    (5, "IND_EVENTO_VENDAVAL", "NUM_EVENTO_VENDAVAL"),
    (6, "IND_EVENTO_HUNDIMIENTO", "NUM_EVENTO_HUNDIMIENTO")
]

GRUPOS_PRIVACION = [
    (1, "I1"),
    (2, "I2"),
    (3, "I3"),
    (4, "I4"),
    (5, "I5"),
    (6, "I6"),
    (7, "I7"),
    (8, "I8"),
    (9, "I9"),
    (10, "I10"),
    (11, "I11"),
    (12, "I12"),
    (13, "I13"),
    (14, "I14"),
    (15, "I15")
]

GRUPOS_DISCAPACIDAD = [
    (1, "IND_DISCAP_VER"),
    (2, "IND_DISCAP_OIR"),
    (3, "IND_DISCAP_HABLAR"),
    (4, "IND_DISCAP_MOVERSE"),
    (5, "IND_DISCAP_BAÑARSE"),
    (6, "IND_DISCAP_SALIR"),
    (7, "IND_DISCAP_ENTENDER"),
    (8, "IND_DISCAP_NINGUNA")
]

# 🔥 La fuente 9 no trae valor; de la 10 a la 12 heredan el indicador agregado
GRUPOS_INGRESO = [
    (1, "IND_INGR_SALARIO", "VLR_INGR_SALARIO", None),
    (2, "IND_INGR_HONORARIOS", "VLR_INGR_HONORARIOS", None),
    (3, "IND_INGR_COSECHA", "VLR_INGR_COSECHA", "NUM_MES_INGR_COSECHA"),
    (4, "IND_INGR_PENSION", "VLR_INGR_PENSION", None),
    (5, "IND_INGR_REMESA_PAIS", "VLR_INGR_REMESA_PAIS", None),
    (6, "IND_INGR_REMESA_EXTERIOR", "VLR_INGR_REMESA_EXTERIOR", None),
    (7, "IND_INGR_ARRIENDOS", "VLR_INGR_ARRIENDOS", None),
    (8, "IND_OTROS_INGRESOS", "VLR_OTROS_INGRESOS", None),
    (9, "IND_INGR_ESTADO", None, None),
    (10, "IND_INGR_ESTADO", "VLR_INGR_FAM_ACCION", None),
    (11, "IND_INGR_ESTADO", "VLR_INGR_COL_MAYOR", None),
    (12, "IND_INGR_ESTADO", "VLR_INGR_OTRO_SUBSIDIO", None)
]

# 🔥 (código, indicador, número de orden de la persona referida)
GRUPOS_RELACION = [
    (1, "IND_CONYUGE_VIVE_HOGAR", "IDE_CONYUGE"),
    (2, "IND_PADRE_VIVE_HOGAR", "IDE_PADRE"),
    (3, "IND_PARIENTE_DOMESTICO", "IDE_SERV_DOMESTICO")
]

# 🔥 Autorizado: (columna, centinela, indicador, valor del indicador que sí aplica)
# Solo se convierte a nulo si el indicador dice que no aplica.
CENTINELAS = [
    ("NUM_DIAS_LLEGA", 9, "IND_AGUA_LLEGA_7DIAS", 2),
    ("NUM_HORAS_LLEGA", 99, "IND_AGUA_LLEGA_24HORAS", 2),
    ("NUM_EVENTO_INUNDACION", 0, "IND_EVENTO_INUNDACION", 1),
    ("NUM_EVENTO_AVALANCHA", 0, "IND_EVENTO_AVALANCHA", 1),
    ("NUM_EVENTO_TERREMOTO", 0, "IND_EVENTO_TERREMOTO", 1),
    ("NUM_EVENTO_INCENDIO", 0, "IND_EVENTO_INCENDIO", 1),
    ("NUM_EVENTO_VENDAVAL", 0, "IND_EVENTO_VENDAVAL", 1),
    ("NUM_EVENTO_HUNDIMIENTO", 0, "IND_EVENTO_HUNDIMIENTO", 1)
]

# 🔥 99 y 0 nunca son un número de orden
COLUMNAS_REFERENCIA = [
    "IDE_CONYUGE",
    "IDE_PADRE",
    "IDE_SERV_DOMESTICO"
]

CENTINELAS_REFERENCIA = [0, 99]

# 🔥 Pueden quedar nulas después de convertir centinelas
COLUMNAS_NULABLES = COLUMNAS_SIN_DATO + COLUMNAS_REFERENCIA + [
    "NUM_DIAS_LLEGA",
    "NUM_HORAS_LLEGA",
    "NUM_EVENTO_INUNDACION",
    "NUM_EVENTO_AVALANCHA",
    "NUM_EVENTO_TERREMOTO",
    "NUM_EVENTO_INCENDIO",
    "NUM_EVENTO_VENDAVAL",
    "NUM_EVENTO_HUNDIMIENTO"
]

# 🔥 Las agrega la app; no vienen en el Excel
COLUMNAS_CALCULADAS = [
    "FILA_EXCEL",
    "GRUPO_HOGAR",
    "IDVIVIENDA",
    "IDHOGAR",
    "QTORDENPERSONA",
    "ESTADO_ORDEN"
]

SI_NO = {1, 2}
SI_NO_NA = {1, 2, 9}
INDICADOR_GASTO = {1, 2, 9}
INDICADOR_INGRESO = {1, 2, 9, 99}
INDICADOR_IPM = {0, 1}
ESTRATOS = {0, 1, 2, 3, 4, 5, 6, 9, 99}

# 🔥 Mismos valores de los CHECK de sql/01_sisben_iv_schema_sqlserver.sql
CATALOGOS = {
    "COD_CLASE": {1, 2, 3},
    "TIP_VIVIENDA": set(range(1, 6)),
    "TIP_MAT_PAREDES": set(range(0, 8)),
    "TIP_MAT_PISOS": set(range(1, 7)),
    "IND_TIENE_ENERGIA": SI_NO,
    "TIP_ESTRATO_ENERGIA": ESTRATOS,
    "IND_TIENE_ALCANTARILLADO": SI_NO,
    "IND_TIENE_GAS": SI_NO,
    "IND_TIENE_RECOLECCION": SI_NO,
    "IND_TIENE_ACUEDUCTO": SI_NO,
    "TIP_ESTRATO_ACUEDUCTO": ESTRATOS,
    "TIP_OCUPA_VIVIENDA": set(range(1, 6)),
    "NUM_HABITA_VIVIENDA": set(range(1, 5)),
    "TIP_SANITARIO": set(range(1, 6)),
    "TIP_UBI_SANITARIO": {1, 2, 9},
    "TIP_USO_SANITARIO": {1, 2, 3, 9},
    "TIP_ORIGEN_AGUA": set(range(1, 10)),
    "IND_AGUA_LLEGA_7DIAS": SI_NO_NA,
    "IND_AGUA_LLEGA_24HORAS": SI_NO_NA,
    "TIP_USO_AGUA_BEBER": set(range(1, 7)),
    "TIP_ELIMINA_BASURA": set(range(1, 8)),
    "IND_TIENE_COCINA": SI_NO,
    "TIP_PREPARA_ALIMENTOS": set(range(1, 6)),
    "TIP_USO_COCINA": {1, 2, 3, 9},
    "TIP_ENERGIA_COCINA": {1, 2, 3, 4, 5, 6, 7, 9},
    "IND_TIENE_NEVERA": SI_NO,
    "IND_TIENE_LAVADORA": SI_NO,
    "IND_TIENE_PC": SI_NO,
    "IND_TIENE_INTERNET": SI_NO,
    "IND_TIENE_MOTO": SI_NO,
    "IND_TIENE_TRACTOR": SI_NO,
    "IND_TIENE_CARRO": SI_NO,
    "IND_TIENE_BIEN_RAIZ": SI_NO,
    "H_5": INDICADOR_IPM,
    "SEXO_PERSONA": SI_NO,
    "TIP_PARENTESCO": set(range(1, 20)),
    "TIP_ESTADO_CIVIL": set(range(1, 6)),
    "TIP_SEG_SOCIAL": {0, 1, 2, 3, 9},
    "IND_ENFERMO_30": SI_NO,
    "IND_ACUDIO_SALUD": SI_NO_NA,
    "IND_FUE_ATENDIDO_SALUD": SI_NO_NA,
    "IND_ESTA_EMBARAZADA": SI_NO_NA,
    "IND_TUVO_HIJOS": SI_NO_NA,
    "TIP_CUIDADO_NIÑOS": set(range(1, 10)),
    "IND_RECIBE_COMIDA": SI_NO_NA,
    "IND_LEER_ESCRIBIR": SI_NO_NA,
    "IND_ESTUDIA": SI_NO_NA,
    "NIV_EDUCATIVO": {0, 1, 2, 3, 4, 5, 6, 7, 9},
    "GRADO_ALCANZADO": set(range(0, 14)) | {99},
    "IND_FONDO_PENSIONES": {1, 2, 3, 9},
    "TIP_ACTIVIDAD_MES": set(range(0, 10)),
    "TIP_EMPLEADO": set(range(1, 11)) | {99}
}

for _, indicador, _ in GRUPOS_GASTO:
    CATALOGOS[indicador] = INDICADOR_GASTO

for _, indicador, _ in GRUPOS_EVENTO:
    CATALOGOS[indicador] = SI_NO

for _, indicador in GRUPOS_PRIVACION:
    CATALOGOS[indicador] = INDICADOR_IPM

for _, indicador in GRUPOS_DISCAPACIDAD:
    CATALOGOS[indicador] = SI_NO

for _, indicador, _, _ in GRUPOS_INGRESO:
    CATALOGOS[indicador] = INDICADOR_INGRESO

for _, indicador, _ in GRUPOS_RELACION:
    CATALOGOS[indicador] = SI_NO_NA

# 🔥 Mapeo Excel -> columnas Riodata
MAPA_VIVIENDA = {
    "IDVIVIENDA": "idvivienda",
    "COD_MPIO": "cdmunicipio",
    "COD_CLASE": "cdclase",
    "CDCORREGIMIENTO": "cdcorregimiento",
    "CDVEREDA": "cdvereda",
    "CDBARRIO": "cdbarrio",
    "TIP_VIVIENDA": "cdtipovivienda",
    "TIP_MAT_PAREDES": "cdmaterialpared",
    "TIP_MAT_PISOS": "cdmaterialpiso",
    "IND_TIENE_ENERGIA": "fgenergia",
    "TIP_ESTRATO_ENERGIA": "cdestratoenergia",
    "IND_TIENE_ALCANTARILLADO": "fgalcantarillado",
    "IND_TIENE_GAS": "fggas",
    "IND_TIENE_RECOLECCION": "fgrecoleccionbasura",
    "IND_TIENE_ACUEDUCTO": "fgacueducto",
    "TIP_ESTRATO_ACUEDUCTO": "cdestratoacueducto",
    "NUM_CUARTOS_VIVIENDA": "qtcuartosvivienda",
    "NUM_HOGARES_VIVIENDA": "qthogaresvivienda"
}

MAPA_HOGAR = {
    "IDHOGAR": "idhogar",
    "IDVIVIENDA": "idvivienda",
    "TIP_OCUPA_VIVIENDA": "cdocupacionvivienda",
    "NUM_HABITA_VIVIENDA": "cdtiempohabitavivienda",
    "NUM_CUARTOS_EXCLUSIVOS": "qtcuartosexclusivos",
    "NUM_CUARTOS_DORMIR": "qtcuartosdormir",
    "NUM_CUARTOS_UNICOS_DORMIR": "qtcuartosexclusivosdormir",
    "TIP_SANITARIO": "cdtiposanitario",
    "TIP_UBI_SANITARIO": "cdubicacionsanitario",
    "TIP_USO_SANITARIO": "cdusosanitario",
    "TIP_ORIGEN_AGUA": "cdorigenagua",
    "IND_AGUA_LLEGA_7DIAS": "fgaguasietedias",
    "NUM_DIAS_LLEGA": "qtdiasllegaagua",
    "IND_AGUA_LLEGA_24HORAS": "fgaguaveinticuatrohoras",
    "NUM_HORAS_LLEGA": "qthorasllegaagua",
    "TIP_USO_AGUA_BEBER": "cdtratamientoaguabeber",
    "TIP_ELIMINA_BASURA": "cdeliminacionbasura",
    "IND_TIENE_COCINA": "fgcocina",
    "TIP_PREPARA_ALIMENTOS": "cdlugarpreparaalimentos",
    "TIP_USO_COCINA": "cdusococina",
    "TIP_ENERGIA_COCINA": "cdenergiacocina",
    "IND_TIENE_NEVERA": "fgnevera",
    "IND_TIENE_LAVADORA": "fglavadora",
    "IND_TIENE_PC": "fgcomputador",
    "IND_TIENE_INTERNET": "fginternet",
    "IND_TIENE_MOTO": "fgmoto",
    "IND_TIENE_TRACTOR": "fgtractor",
    "IND_TIENE_CARRO": "fgcarro",
    "IND_TIENE_BIEN_RAIZ": "fgbienraiz",
    "NUM_PERSONAS_HOGAR": "qtpersonashogar",
    "VLR_TOTAL_GASTOS": "mngastototal",
    "H_5": "fgpobrezamultidimensional",
    "CLASIFICACION": "cdclasificacionsisben"
}

MAPA_PERSONA = {
    "IDPERSONA": "idpersona",
    "IDHOGAR": "idhogar",
    "QTORDENPERSONA": "qtordenpersona",
    "SEXO_PERSONA": "cdsexo",
    "EDAD_CALCULADA": "qtedad",
    "TIP_PARENTESCO": "cdparentesco",
    "TIP_ESTADO_CIVIL": "cdestadocivil",
    "TIP_SEG_SOCIAL": "cdseguridadsocial",
    "IND_ENFERMO_30": "fgenfermo30dias",
    "IND_ACUDIO_SALUD": "fgacudioserviciosalud",
    "IND_FUE_ATENDIDO_SALUD": "fgatendidosalud",
    "IND_ESTA_EMBARAZADA": "fgembarazo",
    "IND_TUVO_HIJOS": "fghijosnacidosvivos",
    "TIP_CUIDADO_NIÑOS": "cdcuidadoninos",
    "IND_RECIBE_COMIDA": "fgrecibealimentacion",
    "IND_LEER_ESCRIBIR": "fgleerescribir",
    "IND_ESTUDIA": "fgestudia",
    "NIV_EDUCATIVO": "cdniveleducativo",
    "GRADO_ALCANZADO": "cdgrado",
    "IND_FONDO_PENSIONES": "fgcotizapension",
    "TIP_ACTIVIDAD_MES": "cdactividadprincipal",
    "NUM_SEM_BUSCANDO": "qtsemanasbuscandotrabajo",
    "TIP_EMPLEADO": "cdtipoempleo"
}

# 🔥 Orden de borrado; las inserciones van al revés
TABLAS_CARGA = [
    "PersonaRelacion",
    "PersonaIngreso",
    "PersonaDiscapacidad",
    "Persona",
    "HogarPrivacionIpm",
    "HogarEvento",
    "HogarGasto",
    "Hogar",
    "Vivienda"
]
