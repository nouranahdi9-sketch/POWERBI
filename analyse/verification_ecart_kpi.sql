-- =====================================================================================
-- Vérification de l'écart entre les deux KPI "recommandations"
--
--   Rapport "Dashboard monitoring des recommandations" / page "Success & Failure Details"
--       carte "Success"              = 1643 (66%)   filtrée par "Interval End Date"
--   Rapport "Suivi des recommandations" / page "overview"
--       carte "Total Available Reco." = 1662        filtrée par "Steeping schedule"
--
--   Fenêtre observée : 18/07/2026 -> 28/08/2026
--
-- A exécuter sur le SQL Warehouse Databricks (adb-6120597545375074 / 02983fe27612f7ca).
-- Toutes les requêtes sont en LECTURE SEULE.
--
-- Hypothèses à corriger si besoin :
--   - environnement = prd  -> ext_mal_psql_maite_vision_board_prd.public
--   - dim_site.id_plant    = batches.production_line = plants_production_lines.id_plant_production_line
-- =====================================================================================


-- =====================================================================================
-- Q0a - BASELINE MONITORING : doit redonner 1643
-- Reproduit : SUM(flg_succes) + slicer dim_calendar[date_simple] (= calculation_date)
--             + filtre rapport dim_site[plant] NOT IN (null,'BURTON1','STRASBOURG1')
-- =====================================================================================
SELECT
    SUM(f.flg_succes)                            AS success,
    SUM(f.flg_echec)                             AS echecs,
    SUM(f.flg_succes) + SUM(f.flg_echec)         AS denominateur,
    ROUND(100.0 * SUM(f.flg_succes) / NULLIF(SUM(f.flg_succes) + SUM(f.flg_echec), 0), 1) AS pct_success
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
       ON ppl.id_plant_production_line = f.id_production_line
WHERE CAST(f.calculation_date AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
  AND ppl.name IS NOT NULL
  AND ppl.name NOT IN ('BURTON1', 'STRASBOURG1');


-- =====================================================================================
-- Q0b - BASELINE SUIVI : doit redonner 1662
-- Reproduit : SUM(batches_reco[total]) + slicer DIM_PLANNED_DATE[Date] (= planned_date)
--             + filtre rapport dim_site[plant] IN (liste blanche de 8 lignes)
-- =====================================================================================
SELECT
    SUM(br.total)                                AS total_available_reco,
    SUM(br.nb_reco_opti)                         AS nb_reco_opti,
    SUM(br.evaluee)                              AS reco_evaluees,
    COUNT(*)                                     AS nb_batches,
    SUM(CASE WHEN br.total = 0 THEN 1 ELSE 0 END) AS batches_sans_reco,
    ROUND(100.0 * SUM(br.total) / NULLIF(SUM(br.nb_reco_opti), 0), 1) AS pct_disponibles
FROM mal_maite_bi_prd.recommendations.fact_batches_reco br
JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
     ON b.id_batch = br.id_batch
JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
     ON ppl.id_plant_production_line = b.production_line
WHERE CAST(br.planned_date AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
  AND ppl.name IN ('ROUEN1','POLISY1','NOGENT2','PROUVY1','STRASBOURG2','NOGENT1','BUZAU1','BOLELEMI1');

-- >>> Si Q0a et Q0b ne redonnent pas 1643 et 1662, STOP : les tables ont été
-- >>> rafraîchies depuis la capture d'écran. Dis-le-moi, j'adapte.


-- =====================================================================================
-- Q1 - REQUETE CENTRALE : décomposition de l'écart au grain commun (batch, localisation)
--
-- Reconstruit les deux univers au même grain et classe chaque paire dans un "bucket".
-- Contrôle attendu :  A + B + C = 1662   et   A + D + E = 1643
-- C'est cette requête qui chiffre la part de chaque cause.
-- =====================================================================================
WITH bornes AS (
    SELECT DATE'2026-07-18' AS d1, DATE'2026-08-28' AS d2
),

-- Univers SUIVI : réplique de import_recommendations.ipynb cellules 6 / 10 / 11 / 12
suivi AS (
    SELECT
        r.batch                        AS batch_id,
        r.target_localization          AS id_loc,
        CAST(b.planned_date AS DATE)   AS planned_date,
        ppl.name                       AS plant
    FROM ext_mal_psql_maite_vision_board_prd.public.recommendations r
    JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
         ON b.id_batch = r.batch
        AND b.deleted = false
    JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
         ON ppl.id_plant_production_line = b.production_line
    WHERE r.deleted = false
      -- exclusion ROUEN1 / Germination J5 présente uniquement côté Suivi
      AND NOT (b.production_line = 1 AND r.target_localization = 14)
      -- filtre rapport Suivi (liste blanche)
      AND ppl.name IN ('ROUEN1','POLISY1','NOGENT2','PROUVY1','STRASBOURG2','NOGENT1','BUZAU1','BOLELEMI1')
    GROUP BY 1, 2, 3, 4
),

-- Univers MONITORING : les paires effectivement comptées comme succès
moni AS (
    SELECT
        f.batch_id,
        f.id_parameter_localization        AS id_loc,
        CAST(f.calculation_date AS DATE)   AS calculation_date,
        ppl.name                           AS plant
    FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
           ON ppl.id_plant_production_line = f.id_production_line
    WHERE f.flg_succes = 1
      -- filtre rapport Monitoring (liste d'exclusion)
      AND ppl.name IS NOT NULL
      AND ppl.name NOT IN ('BURTON1', 'STRASBOURG1')
),

recon AS (
    SELECT
        COALESCE(s.batch_id, m.batch_id)        AS batch_id,
        COALESCE(s.id_loc,   m.id_loc)          AS id_loc,
        COALESCE(s.plant,    m.plant)           AS plant,
        s.planned_date,
        m.calculation_date,
        (s.batch_id IS NOT NULL)                                              AS in_suivi_univers,
        (m.batch_id IS NOT NULL)                                              AS in_moni_univers,
        COALESCE(s.planned_date      BETWEEN bo.d1 AND bo.d2, false)          AS in_suivi_window,
        COALESCE(m.calculation_date  BETWEEN bo.d1 AND bo.d2, false)          AS in_moni_window
    FROM suivi s
    FULL OUTER JOIN moni m
      ON  s.batch_id = m.batch_id
      AND s.id_loc   = m.id_loc
    CROSS JOIN bornes bo
)

SELECT
    CASE
        WHEN in_suivi_window AND in_moni_window
            THEN 'A. compté des deux côtés'
        WHEN in_suivi_window AND in_moni_univers AND NOT in_moni_window
            THEN 'B. SUIVI seul - reco calculée hors fenêtre (CAUSE 1 : axe de date)'
        WHEN in_suivi_window AND NOT in_moni_univers
            THEN 'C. SUIVI seul - paire absente du Monitoring (CAUSE 2 : planning/is_target_localization)'
        WHEN in_moni_window AND in_suivi_univers AND NOT in_suivi_window
            THEN 'D. MONITORING seul - batch planifié hors fenêtre (CAUSE 1 inverse)'
        WHEN in_moni_window AND NOT in_suivi_univers
            THEN 'E. MONITORING seul - hors périmètre Suivi (CAUSE 3 : deleted / ROUEN1 / plant)'
        ELSE 'Z. hors fenêtre des deux côtés'
    END AS bucket,
    COUNT(*) AS nb_paires
FROM recon
GROUP BY 1
ORDER BY 1;


-- =====================================================================================
-- Q2 - CAUSE 2 détaillée : pourquoi ces paires sont-elles invisibles au Monitoring ?
-- Reprend le bucket C de Q1 et cherche la ligne de planning correspondante.
-- =====================================================================================
WITH bornes AS (SELECT DATE'2026-07-18' AS d1, DATE'2026-08-28' AS d2),

suivi AS (
    SELECT r.batch AS batch_id, r.target_localization AS id_loc,
           CAST(b.planned_date AS DATE) AS planned_date, ppl.name AS plant
    FROM ext_mal_psql_maite_vision_board_prd.public.recommendations r
    JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
         ON b.id_batch = r.batch AND b.deleted = false
    JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
         ON ppl.id_plant_production_line = b.production_line
    WHERE r.deleted = false
      AND NOT (b.production_line = 1 AND r.target_localization = 14)
      AND ppl.name IN ('ROUEN1','POLISY1','NOGENT2','PROUVY1','STRASBOURG2','NOGENT1','BUZAU1','BOLELEMI1')
    GROUP BY 1,2,3,4
),

-- toutes les paires présentes dans la table de faits Monitoring, quel que soit le flag
moni_all AS (
    SELECT DISTINCT batch_id, id_parameter_localization AS id_loc
    FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries
),

-- lignes de planning PG ramenées au grain (batch, id_parameter_localization)
planning AS (
    SELECT
        bpp.batch                       AS batch_id,
        pl.id_parameter_localization    AS id_loc,
        pa.code                         AS activity_code,
        bpp.calculation_interval_after,
        bpp.deleted                     AS planning_deleted
    FROM ext_mal_psql_maite_vision_board_prd.public.batches_production_planning bpp
    JOIN ext_mal_psql_maite_vision_board_prd.public.processes_activities pa
         ON pa.id_process_activity = bpp.activity
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_localizations pl
         ON pl.code = pa.code
),

-- union des tables de référence par site (transform_data.ipynb cellules 5 et 23)
ppa AS (
    SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.strasbourg2.parameters_process_activities
    UNION ALL SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.nogent1.parameters_process_activities
    UNION ALL SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.nogent2.parameters_process_activities
    UNION ALL SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.rouen1.parameters_process_activities
    UNION ALL SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.prouvy1.parameters_process_activities
    UNION ALL SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.polisy1.parameters_process_activities
    UNION ALL SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.buzau1.parameters_process_activities
    UNION ALL SELECT activity_code, production_line, is_target_localization FROM mal_maite_prd.bolelemi1.parameters_process_activities
)

SELECT
    CASE
        WHEN p.batch_id IS NULL
            THEN '1. aucune ligne dans batches_production_planning'
        WHEN p.planning_deleted = true
            THEN '2. ligne de planning supprimée (deleted = true)'
        WHEN p.calculation_interval_after < TIMESTAMP'2024-09-23 00:00:00'
            THEN '3. exclue par le filtre >= 2024-09-23 (transform_data cellule 20)'
        WHEN a.activity_code IS NULL
            THEN '4. activité absente de parameters_process_activities du site'
        WHEN a.is_target_localization = false
            THEN '5. is_target_localization = false (jointure INNER cellule 23)'
        ELSE '6. inexpliqué - à investiguer'
    END AS motif,
    COUNT(*) AS nb_paires
FROM suivi s
CROSS JOIN bornes bo
LEFT JOIN moni_all m ON m.batch_id = s.batch_id AND m.id_loc = s.id_loc
LEFT JOIN planning  p ON p.batch_id = s.batch_id AND p.id_loc = s.id_loc
LEFT JOIN ppa       a ON a.activity_code = p.activity_code AND a.production_line = s.plant
WHERE s.planned_date BETWEEN bo.d1 AND bo.d2
  AND m.batch_id IS NULL          -- absente du Monitoring
GROUP BY 1
ORDER BY 1;


-- =====================================================================================
-- Q3 - CAUSE 3a : impact de l'absence de filtre "deleted" côté Monitoring
-- Le dénominateur du Monitoring (66%) inclut-il des batches / plannings supprimés ?
-- =====================================================================================
SELECT
    COALESCE(b.deleted, true) AS batch_supprime_ou_absent,
    SUM(f.flg_succes)         AS success,
    SUM(f.flg_echec)          AS echecs,
    COUNT(*)                  AS lignes_fait
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
       ON b.id_batch = f.batch_id
WHERE CAST(f.calculation_date AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
  AND (f.flg_succes = 1 OR f.flg_echec = 1)
GROUP BY 1;

-- lignes de planning supprimées comptées comme "recos attendues" par le Monitoring
SELECT
    bpp.deleted AS planning_supprime,
    COUNT(*)    AS nb_lignes_planning
FROM ext_mal_psql_maite_vision_board_prd.public.batches_production_planning bpp
JOIN ext_mal_psql_maite_vision_board_prd.public.batches b
     ON b.id_batch = bpp.batch
WHERE CAST(bpp.calculation_interval_after AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
GROUP BY 1;


-- =====================================================================================
-- Q4 - CAUSE 3b : ROUEN1 / Germination J5 (localisation 14), exclue côté Suivi seulement
-- =====================================================================================
SELECT
    SUM(f.flg_succes) AS success_rouen1_loc14,
    SUM(f.flg_echec)  AS echecs_rouen1_loc14
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
WHERE CAST(f.calculation_date AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
  AND f.id_production_line = 1
  AND f.id_parameter_localization = 14;


-- =====================================================================================
-- Q5 - CAUSE 4 : périmètre des lignes de production (filtres rapport divergents)
-- Toute ligne absente de la liste blanche du Suivi n'apparaît que dans le Monitoring.
-- =====================================================================================
SELECT
    ppl.name AS plant,
    CASE WHEN ppl.name IN ('ROUEN1','POLISY1','NOGENT2','PROUVY1','STRASBOURG2','NOGENT1','BUZAU1','BOLELEMI1')
         THEN 'dans les 2 rapports'
         WHEN ppl.name IN ('BURTON1','STRASBOURG1')
         THEN 'exclue des 2 rapports'
         ELSE '>>> MONITORING UNIQUEMENT <<<'
    END AS perimetre,
    SUM(f.flg_succes) AS success
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines ppl
       ON ppl.id_plant_production_line = f.id_production_line
WHERE CAST(f.calculation_date AS DATE) BETWEEN DATE'2026-07-18' AND DATE'2026-08-28'
GROUP BY 1, 2
ORDER BY 2 DESC, 3 DESC;


-- =====================================================================================
-- Q6 - BUG SUSPECTE : flg_succes figé à 0
-- Lignes dont l'intervalle est terminé depuis longtemps, qui ont bien un id_recommendation,
-- mais qui ne sont comptées ni en succès ni en échec.
-- Si le compte est > 0, le flag n'a pas été recalculé depuis l'ingestion initiale.
-- =====================================================================================
SELECT
    COUNT(*)                                     AS lignes_ni_succes_ni_echec,
    COUNT(DISTINCT f.batch_id)                   AS batches_concernes,
    MIN(f.calculation_interval_after_datetime)   AS plus_ancien,
    MAX(f.calculation_interval_after_datetime)   AS plus_recent
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries f
WHERE f.calculation_interval_after_datetime <= CURRENT_TIMESTAMP()
  AND f.flg_succes = 0
  AND f.flg_echec  = 0
  AND f.id_recommendation IS NOT NULL;


-- =====================================================================================
-- Q7 - CONTROLE MODELE : granularité de planned_date vs DIM_PLANNED_DATE
-- Si des planned_date portent une heure != 00:00:00, la relation vers la table de dates
-- ne matche pas et ces batches disparaissent silencieusement du slicer "Steeping schedule".
-- =====================================================================================
SELECT
    CASE WHEN CAST(br.planned_date AS DATE) = br.planned_date
         THEN 'minuit (relation OK)'
         ELSE 'heure non nulle (>>> lignes perdues par le slicer <<<)'
    END AS granularite,
    COUNT(*)      AS nb_batches,
    SUM(br.total) AS total_reco
FROM mal_maite_bi_prd.recommendations.fact_batches_reco br
GROUP BY 1;
