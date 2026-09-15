-- =====================================================================================
-- Second lot de requêtes - suite aux résultats du 15/09/2026
--
-- Rappel des résultats acquis :
--   Q1 : A=1500  B=162  C=0  D=143  E=0   -> 100% de l'écart vient de l'axe de date
--   Q3 : 56 lignes d'échec sur batches supprimés (dénominateur seulement)
--   Q4/Q5 : impact nul  |  Q7 : RAS
--
-- Q6 était invalide (grain missing_value vs grain paire) -> remplacée par Q8.
-- =====================================================================================


-- =====================================================================================
-- Q8 - REMPLACE Q6 : le flg_succes est-il réellement figé ?
--
-- Test au grain (batch_id, id_parameter_localization) : une paire dont l'intervalle
-- est terminé et qui possède un id_recommendation DOIT porter flg_succes=1 sur
-- exactement une de ses lignes. Si aucune ligne ne porte de flag, le calcul n'a pas
-- été rejoué depuis l'ingestion initiale.
--
-- Interprétation :
--   - anciennete_jours faible (< 1j) : normal, l'intervalle vient de se terminer
--   - anciennete_jours élevée        : anomalie, flag figé
-- =====================================================================================
WITH paires AS (
    SELECT
        f.batch_id,
        f.id_parameter_localization,
        MAX(f.flg_succes)                           AS a_un_succes,
        MAX(f.flg_echec)                            AS a_un_echec,
        MAX(CASE WHEN f.id_recommendation IS NOT NULL THEN 1 ELSE 0 END) AS a_une_reco,
        MAX(f.calculation_interval_after_datetime)  AS fin_intervalle,
        COUNT(*)                                    AS nb_lignes
    FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
    GROUP BY 1, 2
)
SELECT
    CASE
        WHEN DATEDIFF(CURRENT_DATE(), CAST(fin_intervalle AS DATE)) <= 1 THEN 'a. < 1 jour (normal)'
        WHEN DATEDIFF(CURRENT_DATE(), CAST(fin_intervalle AS DATE)) <= 7 THEN 'b. 1 a 7 jours'
        WHEN DATEDIFF(CURRENT_DATE(), CAST(fin_intervalle AS DATE)) <= 30 THEN 'c. 7 a 30 jours'
        ELSE                                                                  'd. > 30 jours (ANOMALIE)'
    END AS anciennete,
    COUNT(*)                   AS nb_paires_sans_flag,
    COUNT(DISTINCT batch_id)   AS nb_batches,
    MIN(fin_intervalle)        AS plus_ancien,
    MAX(fin_intervalle)        AS plus_recent
FROM paires
WHERE fin_intervalle <= CURRENT_TIMESTAMP()
  AND a_une_reco  = 1
  AND a_un_succes = 0
  AND a_un_echec  = 0
GROUP BY 1
ORDER BY 1;


-- =====================================================================================
-- Q9 - ELUCIDER 66% vs 76% sur la carte "Available Reco."
--
-- La capture montre 76%, ma Q0b donne 1662/2515 = 66,1%.
-- Hypothèse : DIM_BATCH (qui porte le filtre dim_site[plant] dans le modèle Suivi)
-- ne contient pas tous les batches de fact_batches_reco. Les batches présents dans
-- batches_reco mais absents de DIM_BATCH sortent du contexte de filtre en PBI,
-- alors que ma requête les garde via la jointure sur PG.
--
-- Si nb_reco_opti chute vers ~2187 en ne gardant que les batches non supprimés,
-- l'hypothèse est confirmée.
-- =====================================================================================
SELECT
    COALESCE(b.deleted, true)  AS batch_supprime_ou_absent,
    COUNT(*)                   AS nb_batches,
    SUM(br.total)              AS total_reco,
    SUM(br.nb_reco_opti)       AS nb_reco_opti,
    ROUND(100.0 * SUM(br.total) / NULLIF(SUM(br.nb_reco_opti), 0), 1) AS pct
FROM mal_maite_bi_prd.recommendations.fact_batches_reco br
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
       ON b.id_batch = br.id_batch
WHERE CAST(br.planned_date AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
GROUP BY 1
ORDER BY 1;

-- cumul en excluant les batches supprimés : doit-on retrouver ~76% ?
SELECT
    SUM(br.total)        AS total_reco,
    SUM(br.nb_reco_opti) AS nb_reco_opti,
    ROUND(100.0 * SUM(br.total) / NULLIF(SUM(br.nb_reco_opti), 0), 1) AS pct_disponibles
FROM mal_maite_bi_prd.recommendations.fact_batches_reco br
JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
     ON b.id_batch = br.id_batch AND b.deleted = false
JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
     ON ppl.id_plant_production_line = b.production_line
WHERE CAST(br.planned_date AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
  AND ppl.name IN ('ROUEN1','POLISY1','NOGENT2','PROUVY1','STRASBOURG2','NOGENT1','BUZAU1','BOLELEMI1');


-- =====================================================================================
-- Q10 - PREPARER LA CORRECTION : quel axe de date commun choisir ?
--
-- Le modèle Suivi possède déjà un axe par date de calcul :
--   batches_calculation_date_reco.calculation_date -> DIM_CALCULATION_DATE.Date
-- (alimenté par recommendations.calculation_date côté PG)
--
-- Le Monitoring utilise calculation_interval_after_datetime (fin d'intervalle).
--
-- Si ces deux dates coïncident au jour près, on peut aligner les deux rapports SANS
-- remodéliser : il suffit de basculer la carte du Suivi sur DIM_CALCULATION_DATE.
-- Sinon, il faudra ajouter un axe planned_date au Monitoring (dim_batches possède
-- déjà planned_datetime).
-- =====================================================================================
WITH moni AS (
    SELECT
        batch_id,
        id_parameter_localization AS id_loc,
        MAX(CAST(calculation_interval_after_datetime AS DATE)) AS date_monitoring
    FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries
    WHERE flg_succes = 1
    GROUP BY 1, 2
),
pg AS (
    SELECT
        r.batch                        AS batch_id,
        r.target_localization          AS id_loc,
        MAX(CAST(r.calculation_date AS DATE)) AS date_pg
    FROM ext_mal_psql_maite_vision_board_prd.public.recommendations r
    WHERE r.deleted = false
    GROUP BY 1, 2
)
SELECT
    DATEDIFF(m.date_monitoring, p.date_pg) AS ecart_jours,
    COUNT(*)                               AS nb_paires
FROM moni m
JOIN pg p ON p.batch_id = m.batch_id AND p.id_loc = m.id_loc
WHERE m.date_monitoring BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
GROUP BY 1
ORDER BY ABS(ecart_jours), ecart_jours;


-- =====================================================================================
-- Q11 - MESURER LA FRAGILITE DE L'ECART SUR D'AUTRES FENETRES
--
-- L'écart net de 19 est une quasi-compensation entre 162 et 143. Cette requête rejoue
-- la décomposition mois par mois : l'écart net n'a rien de stable, alors que le volume
-- de paires en désaccord, lui, reste structurellement élevé.
--
-- Colonnes :
--   kpi_suivi           = paires dont le batch est planifié dans le mois
--   kpi_monitoring      = paires dont la reco est calculée dans le mois
--   ecart_net           = ce que montrerait la comparaison des deux cartes
--   paires_en_desaccord = paires comptées d'un seul côté (la vraie mesure du problème)
-- =====================================================================================
WITH suivi AS (
    SELECT r.batch AS batch_id, r.target_localization AS id_loc,
           CAST(b.planned_date AS DATE) AS planned_date
    FROM ext_mal_psql_maite_vision_board_prd.public.recommendations r
    JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
         ON b.id_batch = r.batch AND b.deleted = false
    JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
         ON ppl.id_plant_production_line = b.production_line
    WHERE r.deleted = false
      AND NOT (b.production_line = 1 AND r.target_localization = 14)
      AND ppl.name IN ('ROUEN1','POLISY1','NOGENT2','PROUVY1','STRASBOURG2','NOGENT1','BUZAU1','BOLELEMI1')
    GROUP BY 1, 2, 3
),
moni AS (
    SELECT f.batch_id, f.id_parameter_localization AS id_loc,
           CAST(f.calculation_date AS DATE) AS calculation_date
    FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
           ON ppl.id_plant_production_line = f.id_production_line
    WHERE f.flg_succes = 1
      AND ppl.name IS NOT NULL
      AND ppl.name NOT IN ('BURTON1', 'STRASBOURG1')
),
-- univers unifié : une ligne par paire (batch, localisation), avec ses deux dates
recon AS (
    SELECT
        COALESCE(s.batch_id, m.batch_id) AS batch_id,
        COALESCE(s.id_loc,   m.id_loc)   AS id_loc,
        s.planned_date,
        m.calculation_date
    FROM suivi s
    FULL OUTER JOIN moni m
      ON  s.batch_id = m.batch_id
      AND s.id_loc   = m.id_loc
),
bornes AS (
    SELECT debut, LAST_DAY(debut) AS fin
    FROM (SELECT explode(sequence(DATE'2026-01-01', DATE'2026-09-01', INTERVAL 1 MONTH)) AS debut)
),
croise AS (
    SELECT
        bo.debut,
        COALESCE(r.planned_date     BETWEEN bo.debut AND bo.fin, false) AS in_suivi,
        COALESCE(r.calculation_date BETWEEN bo.debut AND bo.fin, false) AS in_moni
    FROM bornes bo
    CROSS JOIN recon r
)
SELECT
    DATE_FORMAT(debut, 'yyyy-MM')                        AS mois,
    SUM(IF(in_suivi, 1, 0))                              AS kpi_suivi,
    SUM(IF(in_moni,  1, 0))                              AS kpi_monitoring,
    SUM(IF(in_suivi, 1, 0)) - SUM(IF(in_moni, 1, 0))     AS ecart_net,
    SUM(IF(in_suivi <> in_moni, 1, 0))                   AS paires_en_desaccord
FROM croise
WHERE in_suivi OR in_moni
GROUP BY 1
ORDER BY 1;
