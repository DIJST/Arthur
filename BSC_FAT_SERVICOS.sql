 -- CREATE OR REPLACE VIEW BSC_FAT_SERVICOS AS 
WITH 
ID_ATND AS (
SELECT TO_NUMBER(CD_RE_ATND) CD_RE_ATND , NO_ATND, CD_CRDN as CD_CRDN_ATND , TO_CHAR(b.dt_vgnc_fnal, 'DD/MM/YYYY') AS dt_vgnc_fnal
FROM VPV_PRD_DM.TVIC_DIM_ATND a
LEFT JOIN VPV_PRD_DM.tvic_rlco_atnd_pnto_vnda b on a.id_atnd =  b.id_atnd 
left join VPV_PRD_DM.tvic_dim_pnto_vnda c on c.id_pnto_vnda_dw = b.id_pnto_vnda
WHERE  TO_CHAR(b.dt_vgnc_fnal, 'DD/MM/YYYY') = '31/12/2100' AND CD_RE_ATND <> '-2'
AND c.id_cnl_nvl_1 = 1 
) 
, DATAS AS (
SELECT * FROM (
SELECT  
     TO_CHAR(trunc(DT_RFRN),'DD/MM/YYYY') AS DT_RFRN , REPLACE(SEGMENTO,'_',' ') DS_SGMT, REALIZADO
FROM VPV_RGNL_SP.TVIC_FAT_PTAL_DTA
UNPIVOT (REALIZADO FOR SEGMENTO IN (SEGUROS, NOVOS_NEGOCIOS, SERVICOS_DIGITAIS)))
WHERE REALIZADO = 'Real'
) --SELECT * FROM DATAS;
, CORTE AS (
SELECT REPLACE(SEGMENTO,'_',' ') DS_SGMT, TO_CHAR(MAX(DT_RFRN),'YYYYMMDD') AS ID_DIA FROM 
(SELECT 
 DT_RFRN, SEGMENTO, REALIZADO
FROM VPV_RGNL_SP.TVIC_FAT_PTAL_DTA
UNPIVOT (REALIZADO FOR SEGMENTO IN (SEGUROS, NOVOS_NEGOCIOS, SERVICOS_DIGITAIS)) )
WHERE REALIZADO = 'Real'
GROUP BY SEGMENTO
)
,
DU AS (
SELECT 
  T0.NU_ANO_MES_RFRN
, T0.DS_CNL_NVL_1
, CORTE.DS_SGMT
, SUM(CASE WHEN  T0.DT_RFRN <= TO_DATE(CORTE.ID_DIA,'YYYYMMDD')
  THEN T0.NU_PESO_DU ELSE 0 END) AS NU_PESO_DU
, SUM(T0.NU_PESO_DU) AS NU_TOTAL_DU
  , CORTE.ID_DIA
FROM VPV_SDBX_PLNJ.TVIC_ODS_MRCD_CSMD_DU T0, CORTE
WHERE T0.DS_INDC_CMRC = 'NAO SE APLICA'
AND T0.DS_NTZA_PRDT = 'MÓVEL'
GROUP BY 
T0.NU_ANO_MES_RFRN
, T0.DS_CNL_NVL_1
, CORTE.DS_SGMT
, CORTE.ID_DIA
)
, 
BASE_DIA_ATIVACAO AS (
SELECT
    TO_CHAR(t.nu_ano_mes_rfrn)  AS NU_ANO_MES_RFRN,                         -- 1
    TO_CHAR(t.nu_ano_mes_rfrn || '01') AS ID_DIA,                           -- 2
    TO_CHAR(trunc(t.dt_vncl),'DD/MM/YYYY') AS DT_RFRN,                             -- 3
    'ATIVACAO' AS DS_CNRO,                                                  -- 4
    TO_CHAR(ds_tipo_mvmt) AS DS_INDC_CMRC,                                  -- 5
    'B2C' AS DS_CRTR,                                                       -- 6
 CASE WHEN SG_RGNL_BSC in ('NÃO SE APLICA', 'NÃO INFORMADO') THEN SG_RGNL ELSE SG_RGNL_BSC END AS SG_RGNL,                                               -- 7
    TO_CHAR(ID_DDD_BSC) AS ID_DDD,                                          -- 8
    SG_UF AS SG_UF,                                                         -- 9

    TRANSLATE (UPPER (DS_TRRT_BSC),'ÁÇÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕËÜ','ACEIOUAEIOUAEIOUAOEU') AS DS_BR_TRRT,                                            -- 10
    CD_CRDN AS CD_CRDN,                                                     -- 11
    CASE WHEN REGEXP_LIKE(REPLACE(NO_ATVO_LOGN,'A',''),'^\d+$')             -- 12
         THEN TO_NUMBER(REPLACE(NO_ATVO_LOGN,'A',''))
         ELSE NULL END AS NO_LOGN_ATND,
    DS_CNL_NVL_1 AS DS_CNL_NVL_1,                                           -- 13
    'SERVICOS DIGITAIS' AS DS_SGMT,                                         -- 14
    'SVA' AS DS_SGMT_PRDT,                                                  -- 15
    t.ds_srvc_dgtl AS DS_GRPO_SRVC,                                         -- 16
    NU_ROW_INDX AS QT_FSCO,                                                 -- 17
    VL_BRTO_PCTO_SVA AS VL_TRCO_BRTA,                                       -- 18
    VL_DSCN_PCTO_SVA AS VL_TRCO_DSCN,                                       -- 19
    CASE
        WHEN (DS_SRVC_DGTL IN ('AMAZON PRIME','APPLE MUSIC','SPOTIFY','YOUTUBE PREMIUM') AND (VL_BRTO_PCTO_SVA - VL_DSCN_PCTO_SVA) = 0)                                 THEN VL_BRTO_PCTO_SVA  --VL_BRTO_PCTO_SVA
        WHEN (DS_SRVC_DGTL IN ('AMAZON PRIME','APPLE MUSIC','SPOTIFY','YOUTUBE PREMIUM') AND (VL_BRTO_PCTO_SVA - VL_DSCN_PCTO_SVA) > 0)                                 THEN (VL_BRTO_PCTO_SVA - VL_DSCN_PCTO_SVA)  --VL_BRTO_PCTO_SVA
        WHEN DS_PRDT_EXTR IN ('Spotify Familia','Spotify P Gratis','Spotify Premium','TITULAR VIVO SELFIE SPOTIFY PREMIUM 30GB') THEN VL_BRTO_PCTO_SVA  --VL_BRTO_PCTO_SVA
        WHEN DS_SRVC_DGTL IN ('BTFIT','CLOUD GAMING','DISNEY PLUS','EXITLAG','GLOBOPLAY','MAX','MCAFEE','NBA','NETFLIX','PREMIERE','PROTECAO RUA','SURFIE','TELECINE','VIVO CLOUD',
                              'VIVO PLAY APP','VPN','POCOYO','GALINHA PINTADINHA') THEN (VL_BRTO_PCTO_SVA - VL_DSCN_PCTO_SVA) 
        ELSE 0 END AS VL_TRCO_FACE,                  -- 20
    NULL AS DATA_CORTE,                                                     -- 21 (Padroniza  o)
    'VPV_SDBX_PLNJ.VVIC_ODS_MVMT_SVA_SFRD' AS ORIGEM,                       -- 22
    t1.NO_ATND AS NO_ATND,
        DS_PRDT_EXTR AS DS_SRVC_PARC,                                                 -- 22
    t.ds_srvc_dgtl AS DS_SUB_GRPO_SRVC,                                           -- 23
    DS_AGRP AS DS_FMLA_SRVC,                                                      -- 24
    CASE WHEN in_prqe_sgtd = 1 THEN 'Serv. Dig. Avulso' 
         WHEN in_prqe_sgtd = 0 and DS_CLSF_SVA_RI = 'Serv. Dig. Avulso'  THEN 'Serv. Dig. Avulso' 
         ELSE 'Serv. Dig. Bundle' END AS DS_TIPO_SRVC ,
       DS_CLSF_SVA_RI AS DS_CLSF_SVA
FROM VPV_SDBX_PLNJ.VVIC_ODS_MVMT_SVA_SFRD t
LEFT JOIN ID_ATND t1 
   ON TO_CHAR(t1.CD_RE_ATND) = TO_CHAR(
        REPLACE(LTRIM(REGEXP_REPLACE(NO_ATVO_LOGN,'[A-Z]',''),0),'-','')
      )
LEFT JOIN CORTE ON  'SERVICOS DIGITAIS' = CORTE.DS_SGMT      
WHERE t.NU_ANO_MES_RFRN >= TO_NUMBER(TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE,'MONTH'),-3),'YYYYMM'))
and DS_TIPO_MVMT IN ('ALTAS LIQUIDAS')
),
BASE_DIA_ATIVACAO_2 as(
SELECT
    TO_CHAR(t.nu_ano_mes_rfrn)  AS NU_ANO_MES_RFRN,                         -- 1
    TO_CHAR(t.nu_ano_mes_rfrn || '01') AS ID_DIA,                           -- 2
    TO_CHAR(trunc(t.DT_MVMT),'DD/MM/YYYY') AS DT_RFRN,                             -- 3
    'ATIVACAO' AS DS_CNRO,                                                  -- 4
    TO_CHAR(ds_tipo_mvmt) AS DS_INDC_CMRC,                                  -- 5
    'B2C' AS DS_CRTR,                                                       -- 6
 CASE WHEN SG_RGNL_BSC in ('NÃO SE APLICA', 'NÃO INFORMADO') THEN SG_RGNL ELSE SG_RGNL_BSC END AS SG_RGNL,                                               -- 7
    TO_CHAR(ID_DDD_BSC) AS ID_DDD,                                          -- 8
    SG_UF AS SG_UF,                                                         -- 9
     
    TRANSLATE (UPPER (DS_TRRT_BSC),'ÁÇÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕËÜ','ACEIOUAEIOUAEIOUAOEU') AS DS_BR_TRRT,                                           -- 10
    CD_CRDN AS CD_CRDN,                                                     -- 11
    CASE WHEN REGEXP_LIKE(REPLACE(NO_LOGN_ATND,'A',''),'^\d+$')             -- 12
         THEN TO_NUMBER(REPLACE(NO_LOGN_ATND,'A',''))
         ELSE NULL END AS NO_LOGN_ATND,
    DS_CNL_NVL_1 AS DS_CNL_NVL_1,                                           -- 13
    'SERVICOS DIGITAIS' AS DS_SGMT,                                         -- 14
    'SVA' AS DS_SGMT_PRDT,                                                  -- 15
    t.no_srvc AS DS_GRPO_SRVC,                                         -- 16
    to_number(FL_MVMT_BRTO) AS QT_FSCO,                                                 -- 17
    VL_BRTO_PCTO AS VL_TRCO_BRTA,                                       -- 18
    VL_DSCN_PCTO AS VL_TRCO_DSCN,                                       -- 19
   VL_BRTO_PCTO - VL_DSCN_PCTO AS VL_TRCO_FACE,
    NULL AS DATA_CORTE,                                                     -- 21 (Padroniza  o)
    'VPV_SDBX_PLNJ.VVIC_ODS_MVMT_SVA_UNIF' AS ORIGEM,                       -- 22
    t1.NO_ATND AS NO_ATND,
        DS_SRVC AS DS_SRVC_PARC,                                                 -- 22
    t.no_srvc AS DS_SUB_GRPO_SRVC,                                           -- 23
    DS_GRPO_SRVC AS DS_FMLA_SRVC, 
    CASE WHEN DS_CLSF_SVA like '%Avulso%' 
         THEN 'Serv. Dig. Avulso' 
         ELSE 'Serv. Dig. Bundle' END AS DS_TIPO_SRVC,
  DS_CLSF_SVA
FROM VPV_SDBX_PLNJ.VVIC_ODS_MVMT_SVA_UNIF t
LEFT JOIN ID_ATND t1 
   ON TO_CHAR(t1.CD_RE_ATND) = TO_CHAR(
        REPLACE(LTRIM(REGEXP_REPLACE(NO_LOGN_ATND,'[A-Z]',''),0),'-','')
      )
LEFT JOIN CORTE ON  'SERVICOS DIGITAIS' = CORTE.DS_SGMT      
WHERE t.NU_ANO_MES_RFRN >= TO_NUMBER(TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE,'MONTH'),-3),'YYYYMM'))
AND NO_SRVC IN ('BTFIT','EXITLAG','NBA','VIVO CLOUD','VIVO PLAY')
AND DS_TIPO_MVMT IN ('ALTAS LIQUIDAS')
)
,

BASE AS (
SELECT
  TO_CHAR(A.NU_ANO_MES_RFRN)  AS NU_ANO_MES_RFRN
, TO_CHAR(A.ID_DIA) AS ID_DIA
, TO_CHAR(TO_DATE(A.ID_DIA, 'YYYYMMDD'), 'DD/MM/YYYY') AS DT_RFRN
, 'REALIZADO' DS_CNRO
, A.DS_INDC_CMRC
, A.DS_CRTR
, CASE WHEN SG_RGNL_BSC in ('NÃO SE APLICA', 'NÃO INFORMADO') THEN SG_RGNL ELSE SG_RGNL_BSC END AS SG_RGNL
, TO_CHAR(A.ID_DDD_BSC) AS ID_DDD
, A.SG_UF

,    TRANSLATE (UPPER (A.DS_TRRT_BSC),'ÁÇÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕËÜ','ACEIOUAEIOUAEIOUAOEU') AS DS_BR_TRRT
, A.CD_CRDN
, CASE WHEN REGEXP_LIKE(REPLACE(NO_LOGN_ATND, 'A', ''), '^\d+$')
then to_number(REPLACE(NO_LOGN_ATND, 'A', '')) 
else null end as NO_LOGN_ATND
, A.DS_CNL_NVL_1
, CASE WHEN A.IN_INDC_BSC LIKE 'SEGURO%' THEN 'SEGUROS' 
    WHEN DS_SGMT_PRDT = 'SEGURO' THEN 'SEGUROS'
ELSE A.IN_INDC_BSC END DS_SGMT
, A.DS_SGMT_PRDT
, CASE WHEN A.IN_INDC_BSC like 'SEGURO%' THEN A.DS_SUB_GRPO_SRVC 
    WHEN A.DS_GRPO_SRVC  = 'SEGURO' THEN 'SEGURO CELULAR'
    WHEN A.DS_GRPO_SRVC = 'HBO MAX' THEN 'MAX' 
    WHEN A.DS_GRPO_SRVC = 'MCAFEE SAFE CONNECT' THEN 'MCAFEE'
    ELSE A.DS_GRPO_SRVC  END DS_GRPO_SRVC
,  A.QT_FSCO
,  A.VL_TRCO_BRTA
,  A.VL_TRCO_DSCN
,  (A.VL_TRCO_BRTA - A.VL_TRCO_DSCN) VL_TRCO_FACE
, CORTE.ID_DIA DATA_CORTE
, 'VPV_SDBX_PLNJ.VVIC_FLT_FSCO_CNST_NGCO_SVA' ORIGEM
,T1.NO_ATND
,DS_SRVC_PARC
,DS_SUB_GRPO_SRVC
,DS_FMLA_SRVC
,CASE 
WHEN IN_INDC_BSC = 'SERVICOS DIGITAIS' THEN  'Serv. Dig. Avulso' 
WHEN IN_INDC_BSC LIKE 'SEGURO%' THEN 'Seguros'
ELSE DS_TIPO_SRVC END  AS DS_TIPO_SRVC
,'Serv. Dig. Avulso' AS DS_CLSF_SVA
FROM VPV_SDBX_PLNJ.VVIC_FLT_FSCO_CNST_NGCO_SVA A
LEFT JOIN CORTE ON  CASE WHEN A.IN_INDC_BSC LIKE 'SEGURO%' THEN 'SEGUROS' ELSE A.IN_INDC_BSC END = CORTE.DS_SGMT
LEFT JOIN ID_ATND T1 ON TO_CHAR(T1.CD_RE_ATND) = TO_CHAR(REPLACE(LTRIM(REGEXP_REPLACE (A.NO_LOGN_ATND,'[A-Z]',''),0),'-',''))
WHERE A.NU_ANO_MES_RFRN >= TO_NUMBER(TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE,'MONTH'),-3),'YYYYMM'))
AND A.ID_DIA <= CORTE.ID_DIA
AND A.IN_INDC_BSC <> 'Não se aplica'
AND A.DS_CNL_NVL_5 = 'PRESENCIAIS'
)
SELECT 
  A.NU_ANO_MES_RFRN
, A.ID_DIA
, A.DT_RFRN
, A.DS_CNRO
, A.DS_SGMT
, A.DS_SGMT_PRDT
, A.DS_GRPO_SRVC
, A.DS_INDC_CMRC
, A.DS_CRTR
, A.SG_RGNL
, A.SG_UF
, A.ID_DDD
, A.DS_BR_TRRT
, A.CD_CRDN
, A.NO_LOGN_ATND
, A.DS_CNL_NVL_1
,A.NO_ATND
,DS_SRVC_PARC
,DS_SUB_GRPO_SRVC
,DS_FMLA_SRVC
,DS_TIPO_SRVC
,DS_CLSF_SVA
, SUM(A.QT_FSCO) QT_FSCO
, SUM(A.VL_TRCO_BRTA) VL_TRCO_BRTA
, SUM(A.VL_TRCO_DSCN) VL_TRCO_DSCN
, SUM(A.VL_TRCO_FACE) VL_TRCO_FACE
, DU.NU_PESO_DU
, DU.NU_TOTAL_DU
, A.ORIGEM 
FROM 
(SELECT *  FROM BASE 
UNION ALL 
SELECT *  FROM BASE_DIA_ATIVACAO
UNION ALL 
SELECT *  FROM BASE_DIA_ATIVACAO_2
)A 
LEFT JOIN DU ON A.NU_ANO_MES_RFRN = DU.NU_ANO_MES_RFRN AND A.DS_CNL_NVL_1 = DU.DS_CNL_NVL_1 AND A.DS_SGMT = DU.DS_SGMT
LEFT JOIN DATAS ON DATAS.DT_RFRN = A.DT_RFRN AND DATAS.DS_SGMT = A.DS_SGMT
--WHERE DS_GRPO_SRVC LIKE 'SEGURO%'
WHERE DATAS.DT_RFRN IS NOT NULL
  AND (DS_GRPO_SRVC not in ('VALE SAUDE SEMPRE','VIVAE','COMBATE,','VIVO GURU')
   AND A.DS_SGMT = 'SERVICOS DIGITAIS')
  OR  A.DS_SGMT IN ('NOVOS NEGOCIOS', 'SEGUROS')
GROUP BY 
  A.NU_ANO_MES_RFRN
, A.ID_DIA
, A.DT_RFRN
, A.DS_CNRO
, A.DS_SGMT
, A.DS_SGMT_PRDT
, A.DS_GRPO_SRVC
, A.DS_INDC_CMRC
,A.NO_ATND
, A.DS_CRTR
, A.SG_RGNL
, A.SG_UF
, A.ID_DDD
, A.DS_BR_TRRT
, A.CD_CRDN
, A.NO_LOGN_ATND
, A.DS_CNL_NVL_1
, DU.NU_PESO_DU
, DU.NU_TOTAL_DU
, A.ORIGEM
,DS_SRVC_PARC
,DS_SUB_GRPO_SRVC
,DS_FMLA_SRVC
,DS_TIPO_SRVC
,DS_CLSF_SVA
 