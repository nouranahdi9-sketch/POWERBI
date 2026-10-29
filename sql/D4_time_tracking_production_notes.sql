-- =============================================================================
-- D4 – Time Tracking & Production Notes
-- Compartiment : Production Line Deployment (valeur à date)
--
-- Règle (spec) : il faut à la fois qu'une configuration note de production
-- ET une configuration TRS soient déployées sur la ligne.
-- Sources, basées sur leur contenu, sans exclusion de site :
--   - notes de production : PG batches_notes (toutes les notes existantes,
--     sur des batchs non supprimés) ;
--   - config TRS : mal_maite_common_prd.gold.trs_metadata (ne contient que
--     les sites concernés par le TRS).
-- Correspondance des lignes : upper(trs_metadata.prd_line) = upper(plants_production_lines.name)
-- (rouen1 = ROUEN1), à la place du CASE écrit en dur.
-- Date de déploiement : date de la 1re note de production de la ligne.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par ligne de production (ce que produira le notebook)
-- -----------------------------------------------------------------------------
WITH lignes_trs AS (
    SELECT DISTINCT upper(trim(prd_line)) AS line_name
    FROM mal_maite_common_prd.gold.trs_metadata
),
notes_par_ligne AS (
    SELECT
        b.production_line   AS production_line_id,
        MIN(bn.created_at)  AS first_note_at,
        COUNT(*)            AS nb_notes
    FROM ext_mal_psql_maite_vision_board_prd.public.batches b
    INNER JOIN ext_mal_psql_maite_vision_board_prd.public.batches_notes bn
        ON bn.batch = b.id_batch
    WHERE b.deleted = false
    GROUP BY b.production_line
)
SELECT
    pl.id_plant_production_line AS production_line_id,
    pl.common_code              AS production_line_code,
    pl.name                     AS production_line_name,
    to_date(n.first_note_at)    AS deployment_date,
    n.nb_notes
FROM ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
INNER JOIN notes_par_ligne n
    ON n.production_line_id = pl.id_plant_production_line
INNER JOIN lignes_trs t
    ON t.line_name = upper(trim(pl.name))
ORDER BY deployment_date;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle de la correspondance des noms
-- Liste les lignes de trs_metadata qui ne trouvent aucune ligne dans
-- plants_production_lines. Doit renvoyer 0 ligne.
-- -----------------------------------------------------------------------------
SELECT DISTINCT md.prd_line
FROM mal_maite_common_prd.gold.trs_metadata md
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines pl
    ON upper(trim(pl.name)) = upper(trim(md.prd_line))
WHERE pl.id_plant_production_line IS NULL;
