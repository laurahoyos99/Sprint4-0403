CREATE TEMP FUNCTION RemoveAccentMarks (word STRING)
    RETURNS STRING
AS (
 REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(word, 'á', 'a'), 'é','e'), 'í', 'i'), 'ó', 'o'), 'ú','u') 
)
;
WITH
IDS AS(
SELECT RemoveAccentMarks(Distrito) AS DistritoSinTildes
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-13_CR_IDS_DISTRITAL_2021_T` 
),
CRM AS(
SELECT ACT_ACCT_CD, ACT_RGN_CD
FROM  `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D`
)

SELECT DISTINCT DistritoSinTildes, ACT_RGN_CD
FROM IDS i left JOIN CRM c ON UPPER(i.DistritoSinTildes)=c.ACT_RGN_CD
ORDER BY DistritoSinTildes,
ACT_RGN_CD
