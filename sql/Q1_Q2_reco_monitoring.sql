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
-- Les deux KPI partagent la même requête retenue : les pourcentages sont
-- calculés dans Power BI, ce qui permet les filtres sites et date.
-- Question ouverte : règle à retenir pour Q1 (cf. PO4).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par recommandation (ce que produira le notebook)
-- -----------------------------------------------------------------------------
SELECT
    m.id_recommendation,
    m.batch_id,
    m.id_production_line                 AS production_line_id,
    pl.common_code                       AS production_line_code,
    to_date(m.date_creation_reco)        AS reco_date,
    COALESCE(m.flg_succes, 0)            AS flg_succes,
    COALESCE(m.flg_echec, 0)             AS flg_echec,
    m.has_auto_value,
    m.has_manual_value,
    m.flg_auto,
    m.id_alerting,
    m.succes_echec,
    m.type_echec,
    m.flg_lasted_reco
FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries m
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
    ON pl.id_plant_production_line = m.id_production_line;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle des deux KPI sur les 30 derniers jours (hors aujourd'hui)
-- Q1 est calculé avec les deux règles candidates, pour trancher PO4 :
--   - règle dashboard monitoring ("Failures due to automatic data") :
--     échecs avec données auto manquantes seules (has_auto_value = 1, has_manual_value = 0)
--   - règle du notebook 04_calcul_kpis :
--     succes_echec = 'ECHEC' et flg_auto = 1 et id_alerting = 1
-- Q2 doit être identique au dashboard monitoring :
--   "Failures caused by manual entries" + "Failures due to automatic and manual data".
-- -----------------------------------------------------------------------------
WITH periode AS (
    SELECT *
    FROM mal_maite_bi_prd.recommendations_monitoring.fact_monitoring_auto_manual_entries
    WHERE to_date(date_creation_reco) >= date_sub(current_date(), 30)
      AND to_date(date_creation_reco) <  current_date()
),
compteurs AS (
    SELECT
        SUM(COALESCE(flg_echec, 0) + COALESCE(flg_succes, 0))                                    AS recos_attendues,
        SUM(CASE WHEN has_auto_value = 1 AND has_manual_value = 0 THEN flg_echec ELSE 0 END)     AS echecs_auto_seuls,
        COUNT(CASE WHEN succes_echec = 'ECHEC' AND flg_auto = 1 AND id_alerting = 1 THEN 1 END)  AS echecs_regle_notebook,
        SUM(CASE WHEN has_manual_value = 1 THEN flg_echec ELSE 0 END)                            AS echecs_manuels
    FROM periode
)
SELECT
    recos_attendues,
    echecs_auto_seuls,
    ROUND(100 * echecs_auto_seuls     / recos_attendues, 1) AS q1_pct_regle_dashboard,
    echecs_regle_notebook,
    ROUND(100 * echecs_regle_notebook / recos_attendues, 1) AS q1_pct_regle_notebook,
    echecs_manuels,
    ROUND(100 * echecs_manuels        / recos_attendues, 1) AS q2_pct_missing_manual_entries
FROM compteurs;
