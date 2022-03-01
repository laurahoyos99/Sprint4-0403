CREATE TEMP FUNCTION RemoveAccentMarks (word STRING)
    RETURNS STRING
AS (
 REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(word, 'á', 'a'), 'é','e'), 'í', 'i'), 'ó', 'o'), 'ú','u') 
)
;
WITH
DISTRITOSIDS AS(
SELECT RemoveAccentMarks(Distrito) AS DistritoSinTildes
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-13_CR_IDS_DISTRITAL_2021_T` 
),
DISTRITOSCRM AS(
SELECT ACT_ACCT_CD, TRIM(ACT_RGN_CD) AS ACT_RGN_CD, MAX(FECHA_EXTRACCION) AS MaxFecha
FROM  `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D`
GROUP BY ACT_ACCT_CD, ACT_RGN_CD
),
DISTRITOSTOTALES AS (
SELECT DISTINCT DistritoSinTildes, ACT_RGN_CD, RIGHT(CONCAT('0000000000',ACT_ACCT_CD),10) AS ACT_ACCT_CD, MaxFecha
FROM DISTRITOSIDS i RIGHT JOIN DISTRITOSCRM c ON UPPER(i.DistritoSinTildes)=c.ACT_RGN_CD
GROUP BY DistritoSinTildes, ACT_RGN_CD, ACT_ACCT_CD, MaxFecha
),
CHURNERSSO AS
(SELECT DISTINCT RIGHT(CONCAT('0000000000',NOMBRE_CONTRATO) ,10) AS CONTRATOSO, Min(FECHA_APERTURA) AS FECHA_APERTURA,
 FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D`
 WHERE
  TIPO_ORDEN = "DESINSTALACION" 
  AND (ESTADO <> "CANCELADA" OR ESTADO <> "ANULADA")
 AND FECHA_APERTURA IS NOT NULL
 GROUP BY CONTRATOSO
 ),

CHURNERSSOCLASIF AS
(SELECT DISTINCT RIGHT(CONCAT('0000000000',NOMBRE_CONTRATO) ,10) AS CONTRATOSO, Min(t.FECHA_APERTURA) AS FECHA_APERTURA,
CASE WHEN SUBMOTIVO = "MOROSIDAD" THEN RIGHT(CONCAT('0000000000',NOMBRE_CONTRATO) ,10) END AS INVOLUNTARIO,
CASE WHEN SUBMOTIVO <> "MOROSIDAD" THEN RIGHT(CONCAT('0000000000',NOMBRE_CONTRATO) ,10) END AS VOLUNTARIO
 FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D` t
 INNER JOIN CHURNERSSO s ON RIGHT(CONCAT('0000000000',t.NOMBRE_CONTRATO) ,10)= s.CONTRATOSO AND t.FECHA_APERTURA = s.FECHA_APERTURA
 WHERE
  TIPO_ORDEN = "DESINSTALACION" 
  AND (ESTADO <> "CANCELADA" OR ESTADO <> "ANULADA")
 AND t.FECHA_APERTURA IS NOT NULL
 GROUP BY CONTRATOSO, INVOLUNTARIO, VOLUNTARIO
 ),

CHURNERSCRM AS(
  SELECT DISTINCT RIGHT(CONCAT('0000000000',ACT_ACCT_CD) ,10) AS CONTRATOCRM, MAX(DATE(CST_CHRN_DT)) AS Maxfecha,Extract(Month from Max(CST_CHRN_DT)) AS MesChurnF
    FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D`
    GROUP BY ACT_ACCT_CD
    HAVING EXTRACT (MONTH FROM Maxfecha) = EXTRACT (MONTH FROM MAX(FECHA_EXTRACCION))
),
FIRSTCHURN AS(
 SELECT DISTINCT RIGHT(CONCAT('0000000000',ACT_ACCT_CD) ,10) AS CONTRATOPCHURN, Min(DATE(CST_CHRN_DT)) AS PrimerChurn, Extract(Month from Min(CST_CHRN_DT)) AS MesChurnP
    FROM  `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D`
    GROUP BY ACT_ACCT_CD
    HAVING EXTRACT (YEAR FROM PrimerChurn) = 2021
),
REALCHURNERS AS(
 SELECT DISTINCT CONTRATOCRM AS CHURNER, MaxFecha, PrimerChurn, MesChurnF, MesChurnP
 FROM CHURNERSCRM c  INNER JOIN FIRSTCHURN f ON c.CONTRATOCRM = f.CONTRATOPCHURN AND f.PrimerChurn <= c.MaxFecha
   GROUP BY CHURNER, MaxFecha, PrimerChurn, MesChurnF, MesChurnP),

CRUCECHURNERS AS(
SELECT CONTRATOSO, CHURNER, VOLUNTARIO, INVOLUNTARIO, MaxFecha, PrimerChurn, MesChurnF, MesChurnP,
EXTRACT(MONTH FROM s.FECHA_APERTURA ) AS MesS
FROM REALCHURNERS c INNER JOIN CHURNERSSOCLASIF s ON CONTRATOSO = CHURNER
AND c.PrimerChurn >= s.FECHA_APERTURA AND date_diff(c.PrimerChurn, s.FECHA_APERTURA, MONTH) <= 3
GROUP BY contratoso, CHURNER, MesS, VOLUNTARIO, INVOLUNTARIO, MaxFecha, PrimerChurn, MesChurnF, MesChurnP
),

CONTEOREGISTROS AS(
SELECT DISTINCT --EXTRACT(MONTH FROM MaxFecha) AS Mes, 
DistritoSinTildes, ACT_RGN_CD, COUNT(ACT_ACCT_CD) AS RegTot
FROM DISTRITOSTOTALES 
GROUP BY --Mes,
DistritoSinTildes, ACT_RGN_CD
),

CONTEOCHURNERS AS(
SELECT DISTINCT --EXTRACT(MONTH FROM MaxFecha) AS Mes,
DistritoSinTildes, ACT_RGN_CD,COUNT(CONTRATOSO) AS RegChurners, 
FROM DISTRITOSTOTALES d INNER JOIN CRUCECHURNERS c ON d.ACT_ACCT_CD=c.CONTRATOSO AND d.MaxFecha=c.MaxFecha
GROUP BY --Mes,
DistritoSinTildes, ACT_RGN_CD
)

--/*
SELECT DISTINCT r.DistritoSinTildes, r.ACT_RGN_CD, RegTot,RegChurners, RegChurners/RegTot AS ChurnRate
FROM CONTEOREGISTROS r INNER JOIN CONTEOCHURNERS c ON r.DistritoSinTildes=c.DistritoSinTildes
GROUP BY DistritoSinTildes, ACT_RGN_CD, RegTot, RegChurners
ORDER BY ChurnRate desc,RegTot, RegChurners,DistritoSinTildes,ACT_RGN_CD
--*/

--SELECT * FROM CONTEOREGISTROS ORDER BY DistritoSinTildes
