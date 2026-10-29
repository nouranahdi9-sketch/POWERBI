-- =============================================================================
-- D3 – AI Recommendations (T0 Target)
-- Compartiment : Production Line Deployment (valeur à date)
--
-- Règle : nombre de lignes de production où la feature de recommandations IA
-- tourne en PROD.
-- Source : référentiel des activations fourni par l'équipe DS (cf. DS1),
-- module 'recommendations'. Remplace la liste de lignes écrite en dur.
-- Statut : en attente de la livraison de la table DS (nom provisoire).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par ligne de production (ce que produira le notebook)
-- -----------------------------------------------------------------------------
SELECT
    production_line_id,
    production_line_code,
    site,
    is_active,
    valid_from,
    valid_to
FROM mal_maite_common_prd.gold.ref_production_line_deployment
WHERE module = 'recommendations'
ORDER BY valid_from;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle de la valeur du KPI à date du jour
-- -----------------------------------------------------------------------------
SELECT COUNT(DISTINCT production_line_id) AS kpi_ai_recommendations
FROM mal_maite_common_prd.gold.ref_production_line_deployment
WHERE module = 'recommendations'
  AND is_active = true;
