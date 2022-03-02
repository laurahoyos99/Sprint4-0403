CREATE TEMP FUNCTION RemoveAccentMarks (word STRING)
    RETURNS STRING
AS (
 REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(word, 'á', 'a'), 'é','e'), 'í', 'i'), 'ó', 'o'), 'ú','u') 
)
;
WITH
DISTRITOSIDS AS(
SELECT RemoveAccentMarks(Provincia) AS Provincia,RemoveAccentMarks(Canton) AS Canton,RemoveAccentMarks(Distrito) AS DistritoSinTildes, Economica
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-13_CR_IDS_DISTRITAL_2021_T` 
),
CONTRATOSACTIVOS AS(
    SELECT DISTINCT ACT_ACCT_CD, EXTRACT(MONTH FROM FECHA_EXTRACCION) AS MES, MAX(FECHA_EXTRACCION) AS FECHA_REPORTE
    FROM  `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D` 
    GROUP BY ACT_ACCT_CD, FECHA_EXTRACCION
),

DISTRITOSCRM AS(
SELECT DISTINCT a.ACT_ACCT_CD, TRIM(t.ACT_RGN_CD) AS ACT_RGN_CD, TRIM(t.ACT_CANTON_CD) AS ACT_CANTON_CD, 
 TRIM(t.ACT_PRVNC_CD) AS ACT_PRVNC_CD,a.Mes
FROM  `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D` t
INNER JOIN CONTRATOSACTIVOS a on a.ACT_ACCT_CD = t.ACT_ACCT_CD AND EXTRACT(MONTH FROM t.FECHA_EXTRACCION) = a.MES AND t.FECHA_EXTRACCION = a.FECHA_REPORTE
GROUP BY ACT_ACCT_CD, ACT_PRVNC_CD, ACT_RGN_CD, ACT_CANTON_CD, a.Mes
),
DISTRITOSTOTALES AS (
SELECT DISTINCT c.MES, i.DistritoSinTildes, Provincia,Canton,c.ACT_PRVNC_CD,c.ACT_CANTON_CD, c.ACT_RGN_CD, c.ACT_ACCT_CD, Economica
FROM DISTRITOSIDS i RIGHT JOIN DISTRITOSCRM c ON UPPER(i.DistritoSinTildes)=c.ACT_RGN_CD
 AND UPPER(i.Provincia)=c.ACT_PRVNC_CD AND UPPER(i.Canton)=c.ACT_CANTON_CD
GROUP BY c.Mes, i.DistritoSinTildes,Provincia,Canton,ACT_PRVNC_CD,c.ACT_CANTON_CD, c.ACT_RGN_CD, c.ACT_ACCT_CD, Economica)

SELECT DISTINCT MES, 
ACT_PRVNC_CD,Provincia,ACT_CANTON_CD,Canton,ACT_RGN_CD,distritosintildes, --COUNT(DISTINCT ACT_ACCT_CD),
Economica,COUNT(DISTINCT ACT_ACCT_CD)
FROM DISTRITOSTOTALES 
WHERE Economica IS NOT NULL
GROUP BY Mes, 
ACT_PRVNC_CD, Provincia,ACT_CANTON_CD, Canton,DistritoSinTildes, ACT_RGN_CD, Economica
ORDER BY MES, 
ACT_PRVNC_CD, ACT_CANTON_CD, ACT_RGN_CD
