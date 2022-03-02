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
),

/*Subconsulta que extrae los churners del CRM considerando la máxima fecha de churn*/
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
/*Subconsulta que define los meses de churn*/
MESESCHURN AS(
SELECT DISTINCT CHURNER, CONTRATOSO, MaxFecha, PrimerChurn, Voluntario, Involuntario,
  CASE WHEN EXTRACT(MONTH FROM PrimerChurn)=1 THEN "Enero"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=2 THEN "Febrero"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=3 THEN "Marzo"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=4 THEN "Abril"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=5 THEN "Mayo"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=6 THEN "Junio"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=7 THEN "Julio"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=8 THEN "Agosto"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=9 THEN "Septiembre"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=10 THEN "Octubre"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=11 THEN "Noviembre"
    WHEN EXTRACT(MONTH FROM PrimerChurn)=12 THEN "Diciembre" END AS Meses
FROM CRUCECHURNERS 
GROUP BY CHURNER, MAXFECHA, Involuntario,Voluntario, CONTRATOSO, MESES, PrimerChurn
)

/*Consulta final que extrae los churners de cada mes en base al mes de alta definido*/
SELECT 
Meses, MESALTA, Categor__a_Canal, COUNT(DISTINCT a.CONTRATOALTA) AS Churners , COUNT(DISTINCT VOLUNTARIO) AS Voluntarios, COUNT (DISTINCT INVOLUNTARIO) as Involuntarios
FROM AMBASALTAS a INNER JOIN MESESCHURN c ON c.CONTRATOSO = a.CONTRATOALTA AND Formato_Fecha < PrimerChurn
GROUP BY Meses,MESALTA, Categor__a_Canal
ORDER BY CASE                    WHEN Meses ="Enero" THEN 1
                                 WHEN Meses ="Febrero" THEN 2
                                 WHEN Meses ="Marzo" THEN 3
                                 WHEN Meses ="Abril" THEN 4
                                 WHEN Meses ="Mayo" THEN 5
                                 WHEN Meses ="Junio" THEN 6
                                 WHEN Meses ="Julio" THEN 7
                                 WHEN Meses ="Agosto" THEN 8
                                 WHEN Meses ="Septiembre"THEN 9
                                 WHEN Meses ="Octubre" THEN 10
                                 WHEN Meses ="Noviembre" THEN 11
                                 WHEN Meses ="Diciembre" THEN 12 END

