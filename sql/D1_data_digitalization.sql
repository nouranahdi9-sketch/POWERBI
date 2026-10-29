-- =============================================================================
-- D1 – Data digitalization
-- Compartiment : Production Line Deployment (valeur à date)
--
-- Règle (spec) : nombre de lignes dont les données manuelles ont été intégrées
-- en masse, c'est-à-dire plus de 180 batchs.
-- Décision provisoire : tous les batchs non supprimés, quel que soit leur
-- statut (cf. PO1).
-- Date de digitalisation : date de création (created_at) du 181e batch de la
-- ligne, c'est-à-dire la date à laquelle le seuil est franchi.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par ligne de production (ce que produira le notebook)
-- Une ligne par ligne de production digitalisée, avec sa date de digitalisation.
-- -----------------------------------------------------------------------------
WITH batches_numerotes AS (
    SELECT
        pl.id_plant_production_line AS production_line_id,
        pl.common_code              AS production_line_code,
        pl.name                     AS production_line_name,
        b.id_batch,
        b.created_at,
        ROW_NUMBER() OVER (
            PARTITION BY pl.id_plant_production_line
            ORDER BY b.created_at, b.id_batch
        ) AS rang_batch
    FROM ext_mal_psql_maite_vision_board_prd.public.batches b
    INNER JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
        ON pl.id_plant_production_line = b.production_line
    WHERE b.deleted = false
)
SELECT
    production_line_id,
    production_line_code,
    production_line_name,
    to_date(created_at) AS digitalization_date
FROM batches_numerotes
WHERE rang_batch = 181
ORDER BY digitalization_date;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle de la valeur du KPI à date du jour
-- Doit donner le même résultat que la requête "Data digitalization" de
-- Calcul.ipynb (lignes ayant plus de 180 batchs non supprimés).
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS kpi_data_digitalization
FROM (
    SELECT pl.id_plant_production_line
    FROM ext_mal_psql_maite_vision_board_prd.public.batches b
    INNER JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
        ON pl.id_plant_production_line = b.production_line
    WHERE b.deleted = false
    GROUP BY pl.id_plant_production_line
    HAVING COUNT(b.id_batch) > 180
) lignes_digitalisees;


-- -----------------------------------------------------------------------------
-- Requête 3 : valeur du KPI à une date donnée (utile pour la comparaison N / N-1)
-- Remplacer la date par la fin de la période voulue.
-- -----------------------------------------------------------------------------
WITH batches_numerotes AS (
    SELECT
        pl.id_plant_production_line AS production_line_id,
        b.created_at,
        ROW_NUMBER() OVER (
            PARTITION BY pl.id_plant_production_line
            ORDER BY b.created_at, b.id_batch
        ) AS rang_batch
    FROM ext_mal_psql_maite_vision_board_prd.public.batches b
    INNER JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
        ON pl.id_plant_production_line = b.production_line
    WHERE b.deleted = false
)
SELECT COUNT(*) AS kpi_data_digitalization
FROM batches_numerotes
WHERE rang_batch = 181
  AND to_date(created_at) <= DATE'2026-09-30';
