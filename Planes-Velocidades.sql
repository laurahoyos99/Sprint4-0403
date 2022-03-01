WITH
NOMBRESPLANES AS (
SELECT DISTINCT RIGHT(CONCAT('0000000000',ACT_ACCT_CD),10) AS ACT_ACCT_CD, PD_BB_PROD_NM,PD_BB_PROD_ID
FROM  `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D`
GROUP BY ACT_ACCT_CD, PD_BB_PROD_NM,PD_BB_PROD_ID
),
VELOCIDAD AS (
SELECT DISTINCT RIGHT(CONCAT('0000000000',Contrato),10) AS Contrato, Rango_Velocidad
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-13_CR_PARQUE_EMPAQUETADO_2021_T` 
GROUP BY Contrato, Rango_Velocidad
)
SELECT DISTINCT n.PD_BB_PROD_ID, n.PD_BB_PROD_NM, v.Rango_Velocidad, COUNT(DISTINCT ACT_ACCT_CD) AS REG
FROM NOMBRESPLANES n INNER JOIN VELOCIDAD v ON n.ACT_ACCT_CD=v.Contrato
GROUP BY n.PD_BB_PROD_ID, n.PD_BB_PROD_NM, v.Rango_Velocidad
ORDER BY n.PD_BB_PROD_ID, REG
