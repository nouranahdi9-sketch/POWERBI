-- =============================================================================
-- Q1 – Uncaptured Aveva data
-- Q2 – Missing manual entries
-- Compartiment : Data Quality & Completeness (30 derniers jours + tendance)
--
-- Q1 (spec) : recos non disponibles à cause de capteurs défaillants ou de
--             chutes de tags ÷ total des recos.
-- Q2 (spec) : recos non disponibles à cause des données manuelles
--             (manuelles seules + manuelles et auto) ÷ total des recos.
-- Source : mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries
--          (table du Dashboard monitoring des recommandations).
--
-- Points clés (notebook fact_monitoring_auto_manual_entries) :
--   - la table est au grain "valeur manquante" : flg_succes / flg_echec ne
--     valent 1 que sur une seule ligne par reco attendue, on peut donc les sommer ;
--   - date de référence = calculation_interval_after_datetime (date à laquelle
--     la reco était attendue), comme les colonnes Last30j du dashboard.
--     date_creation_reco est vide pour les recos en échec ;
--   - id_alerting = code de cause d'échec (dim_alerting) : 1 = chute de tags,
--     2 = mesures auto en retard, 11 = synchronisation, 9 / 10 = saisie manuelle...
-- Les deux KPI partagent la même requête retenue : les pourcentages sont
-- calculés dans Power BI, ce qui permet les filtres sites et date.
-- Question ouverte : règle à retenir pour Q1 (cf. PO4).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par reco attendue (ce que produira le notebook)
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
-- Requête 2 : contrôle des deux KPI sur les 30 derniers jours (hors aujourd'hui)
-- Q1 est calculé avec les deux règles candidates, pour trancher PO4 :
--   - règle dashboard ("Failures due to automatic data") : échecs avec données
--     automatiques manquantes seules (has_auto_value = 1, has_manual_value = 0)
--   - règle du notebook 04_calcul_kpis : échecs dus à une chute de tags
--     (id_alerting = 1)
-- Q2 doit être identique au dashboard monitoring :
--   "Failures caused by manual entries" + "Failures due to automatic and manual data".
-- -----------------------------------------------------------------------------
WITH periode AS (
    SELECT *
    FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries
    WHERE to_date(calculation_interval_after_datetime) >= date_sub(current_date(), 30)
      AND to_date(calculation_interval_after_datetime) <  current_date()
),
compteurs AS (
    SELECT
        SUM(COALESCE(flg_echec, 0) + COALESCE(flg_succes, 0))                                 AS recos_attendues,
        SUM(CASE WHEN has_auto_value = 1 AND has_manual_value = 0 THEN flg_echec ELSE 0 END)  AS echecs_auto_seuls,
        SUM(CASE WHEN id_alerting = 1 THEN flg_echec ELSE 0 END)                              AS echecs_chute_tags,
        SUM(CASE WHEN has_manual_value = 1 THEN flg_echec ELSE 0 END)                         AS echecs_manuels
    FROM periode
)
SELECT
    recos_attendues,
    echecs_auto_seuls,
    ROUND(100 * echecs_auto_seuls  / recos_attendues, 1) AS q1_pct_regle_dashboard,
    echecs_chute_tags,
    ROUND(100 * echecs_chute_tags  / recos_attendues, 1) AS q1_pct_regle_notebook,
    echecs_manuels,
    ROUND(100 * echecs_manuels     / recos_attendues, 1) AS q2_pct_missing_manual_entries
FROM compteurs;
