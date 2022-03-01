SELECT DISTINCT --Subcanal__Venta
Categor__a_Canal, count(distinct Contrato) as Reg
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-20_CR_ALTAS_V3_2021-01_A_2021-12_T` 
GROUP BY Categor__a_Canal ORDER BY Reg desc
