-- =============================================================================
-- D2 – Metamodels
-- Compartiment : Production Line Deployment (valeur à date)
--
-- Règle : nombre de lignes de production dont le metamodel est en RUN.
-- Source : référentiel des activations fourni par l'équipe DS (cf. DS1),
-- module 'metamodel'. Aucune autre source n'est utilisée.
-- Statut : en attente de la livraison de la table DS (nom provisoire).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par ligne de production (ce que produira le notebook)
-- On garde aussi les lignes désactivées : leurs dates permettent de savoir
-- combien de metamodels étaient en RUN à une date donnée (comparaison N / N-1).
-- -----------------------------------------------------------------------------
SELECT
    production_line_id,
    production_line_code,
    site,
    is_active,
    valid_from,
    valid_to
FROM mal_maite_common_prd.gold.ref_production_line_deployment
WHERE module = 'metamodel'
ORDER BY valid_from;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle de la valeur du KPI à date du jour
-- -----------------------------------------------------------------------------
SELECT COUNT(DISTINCT production_line_id) AS kpi_metamodels
FROM mal_maite_common_prd.gold.ref_production_line_deployment
WHERE module = 'metamodel'
  AND is_active = true;
