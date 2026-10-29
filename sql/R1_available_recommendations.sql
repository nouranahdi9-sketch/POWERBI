-- =============================================================================
-- R1 – % Available recommendations
-- Compartiment : AI Recommendation (30 derniers jours + tendance)
--
-- Décision (2026-10-29) : définition du Dashboard monitoring des recommandations
--   R1 = recos générées à temps (flg_succes) ÷ recos attendues (flg_succes + flg_echec)
-- Pourquoi : même source que Q1 / Q2 (« Recommendations blocked by »), les
-- chiffres se complètent jusqu'à 100 % ; couvre aussi les batchs en cours.
-- Alternative (Dashboard suivi, page overview) : recos reçues ÷ recos prévues
-- au planning, batchs terminés : 76 % contre 73 % sur 30 jours (cf. PO5).
--
-- Source : mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries
-- Date de référence : calculation_interval_after_datetime (date à laquelle la
-- reco était attendue).
-- Requête retenue : la même que Q1 / Q2 (sql/Q1_Q2_reco_monitoring.sql), une
-- seule table alimente R1, Q1 et Q2.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par reco attendue (identique à Q1 / Q2)
-- -----------------------------------------------------------------------------
SELECT
    m.batch_id,
    m.id_parameter_localization,
    m.id_recommendation,
    m.id_production_line                          AS production_line_id,
    pl.common_code                                AS production_line_code,
    to_date(m.calculation_interval_after_datetime) AS expected_reco_date,
    m.flg_succes,
    m.flg_echec,
    m.has_auto_value,
    m.has_manual_value,
    m.id_alerting,
    m.type_echec
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries m
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
    ON pl.id_plant_production_line = m.id_production_line
WHERE m.flg_succes = 1
   OR m.flg_echec = 1;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle sur les 30 derniers jours (hors aujourd'hui)
-- A comparer avec la page « Overview » du Dashboard monitoring, bloc
-- « Last 30 days » : Successful recommendation ÷ Expected recommendations.
-- -----------------------------------------------------------------------------
SELECT
    SUM(COALESCE(flg_succes, 0))                                              AS recos_reussies,
    SUM(COALESCE(flg_succes, 0) + COALESCE(flg_echec, 0))                     AS recos_attendues,
    ROUND(100 * SUM(COALESCE(flg_succes, 0))
              / SUM(COALESCE(flg_succes, 0) + COALESCE(flg_echec, 0)), 1)     AS r1_pct_available_recommendations
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries
WHERE to_date(calculation_interval_after_datetime) >= date_sub(current_date(), 30)
  AND to_date(calculation_interval_after_datetime) <  current_date();
