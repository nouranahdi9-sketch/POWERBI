-- =============================================================================
-- D2 – Metamodels
-- Compartiment : Production Line Deployment (valeur à date)
--
-- Règle (spec) : nombre de metamodels en RUN (source officielle à voir avec
-- les DE, cf. DE1). Exemple de la spec : ne pas compter Pithiviers.
-- Décision provisoire : lignes ayant au moins 1 batch non supprimé, hors PI6.
-- Date de mise en RUN : date de création (created_at) du 1er batch de la ligne.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par ligne de production (ce que produira le notebook)
-- Une ligne par ligne de production, avec la date de son 1er batch.
-- -----------------------------------------------------------------------------
SELECT
    pl.id_plant_production_line AS production_line_id,
    pl.common_code              AS production_line_code,
    pl.name                     AS production_line_name,
    to_date(MIN(b.created_at))  AS first_batch_date,
    COUNT(b.id_batch)           AS nb_batches
FROM ext_mal_psql_maite_vision_board_prd.public.batches b
INNER JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
    ON pl.id_plant_production_line = b.production_line
WHERE b.deleted = false
  AND pl.common_code <> 'PI6'
GROUP BY
    pl.id_plant_production_line,
    pl.common_code,
    pl.name
ORDER BY first_batch_date;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle de la valeur du KPI à date du jour
-- Doit donner le même résultat que la requête "Metamodels" de Calcul.ipynb.
-- -----------------------------------------------------------------------------
SELECT COUNT(DISTINCT pl.id_plant_production_line) AS kpi_metamodels
FROM ext_mal_psql_maite_vision_board_prd.public.batches b
INNER JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
    ON pl.id_plant_production_line = b.production_line
WHERE b.deleted = false
  AND pl.common_code <> 'PI6';
