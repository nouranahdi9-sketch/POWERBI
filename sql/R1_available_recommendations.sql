-- =============================================================================
-- R1 – % Available recommendations
-- Compartiment : AI Recommendation (30 derniers jours + tendance)
--
-- Règle : identique à la page « overview » du Dashboard suivi des recommandations,
-- mesure %reco_disponibles = somme(total) ÷ somme(nb_reco_opti)
--   - total        : nb de recos reçues pour le batch (une par localisation)
--   - nb_reco_opti : nb de recos attendues d'après le planning de production
-- Filtres appliqués dans le dashboard :
--   - carte : uniquement les batchs au statut « Fini » ;
--   - rapport : uniquement les 8 lignes déployées sur les recommandations
--     (sera remplacé par le référentiel DS, module 'recommendations').
-- Date de référence : planned_date du batch (slicer DIM_PLANNED_DATE).
-- Source : mal_maite_bi_prd.recommendations (notebook import_recommendations).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par batch (ce que produira le notebook)
-- -----------------------------------------------------------------------------
SELECT
    r.id_batch,
    b.id_plant              AS production_line_id,
    s.plant                 AS production_line_name,
    to_date(r.planned_date) AS planned_date,
    b.batch_status,
    r.total                 AS nb_recos_recues,
    r.nb_reco_opti          AS nb_recos_attendues
FROM mal_maite_bi_prd.recommendations.fact_batches_reco r
INNER JOIN mal_maite_bi_prd.recommendations.dim_batch b
    ON b.id_batch = r.id_batch
LEFT JOIN mal_maite_bi_prd.recommendations.dim_site s
    ON s.id_plant = b.id_plant
WHERE b.batch_status = 'Fini';


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle sur la période du 29/09 au 28/10/2026
-- A comparer avec la carte %reco_disponibles de la page « overview », avec le
-- slicer de date planifiée réglé sur la même période.
-- -----------------------------------------------------------------------------
SELECT
    SUM(r.total)                                         AS recos_recues,
    SUM(r.nb_reco_opti)                                  AS recos_attendues,
    ROUND(100 * SUM(r.total) / SUM(r.nb_reco_opti), 1)   AS r1_pct_available_recommendations
FROM mal_maite_bi_prd.recommendations.fact_batches_reco r
INNER JOIN mal_maite_bi_prd.recommendations.dim_batch b
    ON b.id_batch = r.id_batch
LEFT JOIN mal_maite_bi_prd.recommendations.dim_site s
    ON s.id_plant = b.id_plant
WHERE b.batch_status = 'Fini'
  AND s.plant IN ('ROUEN1', 'POLISY1', 'NOGENT2', 'PROUVY1', 'STRASBOURG2', 'NOGENT1', 'BUZAU1', 'BOLELEMI1')
  AND to_date(r.planned_date) BETWEEN DATE'2026-09-29' AND DATE'2026-10-28';
