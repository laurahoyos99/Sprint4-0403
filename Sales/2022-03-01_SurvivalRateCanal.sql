WITH 

/*Subconsulta que extrae los contratos que tuvieron fecha de alta en el CRM en 2021*/
ALTASCRM AS (
SELECT DISTINCT RIGHT(CONCAT('0000000000',ACT_ACCT_CD) ,10) AS CONTRATOALTACRM, ACT_ACCT_INST_DT
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-16_FINAL_HISTORIC_CRM_FILE_2021_D`
WHERE EXTRACT(YEAR FROM ACT_ACCT_INST_DT)=2021
GROUP BY ACT_ACCT_CD, ACT_ACCT_INST_DT),

/*Subconsulta que extrae las ventas nuevas de la base de altas*/
ALTAS AS (
SELECT DISTINCT RIGHT(CONCAT('0000000000',Contrato) ,10) AS CONTRATOALTA, Formato_Fecha, Categor__a_Canal
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-20_CR_ALTAS_V3_2021-01_A_2021-12_T`  
WHERE Tipo_Venta="Nueva"
AND (Tipo_Cliente = "PROGRAMA HOGARES CONECTADOS" OR Tipo_Cliente="RESIDENCIAL" OR Tipo_Cliente="EMPLEADO")
AND extract(year from Formato_Fecha) = 2021 
--AND Subcanal__Venta<>"OUTBOUND PYMES" AND Subcanal__Venta<>"INBOUND PYMES" AND Subcanal__Venta<>"HOTELERO" AND Subcanal__Venta<>"PYMES – NETCOM" 
AND Tipo_Movimiento= "Altas por venta"
AND (Motivo="VENTA NUEVA " OR Motivo="VENTA")
GROUP BY Contrato, Formato_Fecha, Categor__a_Canal
),

/*Subconsulta que cruza los contratos con instalaciones en el CRM y las ventas nuevas de la base de altas;
 Acá se debe definir el mes del alta a evaluar*/
AMBASALTAS AS (
SELECT x.CONTRATOALTA, Formato_Fecha,EXTRACT(MONTH FROM x.Formato_Fecha) AS MESALTA, Categor__a_Canal
FROM ALTASCRM y INNER JOIN ALTAS x ON y.CONTRATOALTACRM=x.CONTRATOALTA
WHERE DATE(ACT_ACCT_INST_DT)=Formato_Fecha 
--AND EXTRACT(MONTH FROM x.Formato_Fecha)=10
)

SELECT DISTINCT --EXTRACT(MONTH FROM Formato_Fecha) as Mes, 
Categor__a_Canal, 
COUNT(CONTRATOALTA) as reg
FROM AMBASALTAS
GROUP BY --Mes,
Categor__a_Canal 
ORDER BY --Mes
--,Categor__a_Canal
reg
