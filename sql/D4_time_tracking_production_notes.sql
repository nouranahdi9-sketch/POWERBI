-- =============================================================================
-- D4 – Time Tracking & Production Notes
-- Compartiment : Production Line Deployment (valeur à date)
--
-- Règle (spec) : il faut à la fois qu'une configuration note de production
-- ET une configuration TRS soient déployées sur la ligne.
-- Source : référentiel des activations fourni par l'équipe DS (cf. DS1),
-- modules 'process_time' (TRS) et 'production_notes'.
-- Une ligne compte à partir du moment où les DEUX modules sont actifs, et
-- jusqu'à ce que l'un des deux soit désactivé.
-- Statut : en attente de la livraison de la table DS (nom provisoire).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par ligne de production (ce que produira le notebook)
-- -----------------------------------------------------------------------------
SELECT
    pt.production_line_id,
    pt.production_line_code,
    pt.site,
    (pt.is_active AND pn.is_active)          AS is_active,
    GREATEST(pt.valid_from, pn.valid_from)   AS valid_from,   -- les deux modules actifs
    NULLIF(
        LEAST(
            COALESCE(pt.valid_to, DATE'9999-12-31'),
            COALESCE(pn.valid_to, DATE'9999-12-31')
        ),
        DATE'9999-12-31'
    )                                        AS valid_to      -- le premier désactivé
FROM mal_maite_common_prd.gold.ref_production_line_deployment pt
INNER JOIN mal_maite_common_prd.gold.ref_production_line_deployment pn
    ON  pn.production_line_id = pt.production_line_id
    AND pn.module = 'production_notes'
WHERE pt.module = 'process_time'
ORDER BY valid_from;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle de la valeur du KPI à date du jour
-- -----------------------------------------------------------------------------
SELECT COUNT(DISTINCT pt.production_line_id) AS kpi_time_tracking_production_notes
FROM mal_maite_common_prd.gold.ref_production_line_deployment pt
INNER JOIN mal_maite_common_prd.gold.ref_production_line_deployment pn
    ON  pn.production_line_id = pt.production_line_id
    AND pn.module = 'production_notes'
WHERE pt.module = 'process_time'
  AND pt.is_active = true
  AND pn.is_active = true;
