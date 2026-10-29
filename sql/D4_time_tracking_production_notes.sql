-- =============================================================================
-- D4 – Time Tracking & Production Notes
-- Compartiment : Production Line Deployment (valeur à date)
--
-- Règle (spec) : il faut à la fois qu'une configuration note de production
-- ET une configuration TRS soient déployées sur la ligne.
-- Sources (logique de la requête initiale de Calcul.ipynb) :
--   - notes de production : PG batches_notes (au moins une note sur un batch
--     non supprimé de la ligne) ;
--   - config TRS : mal_maite_common_prd.gold.trs_metadata (la ligne y figure).
-- Date de déploiement : date de la 1re note de production de la ligne.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Requête 1 : détail par ligne de production (ce que produira le notebook)
-- -----------------------------------------------------------------------------
WITH lignes_trs AS (
    SELECT DISTINCT
        CASE
            WHEN prd_line = 'burton1'     THEN 'BT1'
            WHEN prd_line = 'rouen1'      THEN 'RO1'
            WHEN prd_line = 'polisy1'     THEN 'PO1'
            WHEN prd_line = 'bolelemi1'   THEN 'BO1'
            WHEN prd_line = 'strasbourg1' THEN 'ST1'
            WHEN prd_line = 'strasbourg2' THEN 'ST2'
            WHEN prd_line = 'nogent1'     THEN 'NG1'
            WHEN prd_line = 'nogent2'     THEN 'NG2'
            WHEN prd_line = 'NYMBURK1'    THEN 'NY1'
            WHEN prd_line = 'prouvy1'     THEN 'PR1'
            WHEN prd_line = 'buzau1'      THEN 'BU1'
            -- WHEN prd_line = 'pithiviers6' THEN 'PI6'
            WHEN prd_line = 'burton2'     THEN 'BT2'
            WHEN prd_line = 'HODONICE1'   THEN 'HO1'
            WHEN prd_line = 'KROMERIZ1'   THEN 'KR1'
            ELSE prd_line
        END AS common_code
    FROM mal_maite_common_prd.gold.trs_metadata
),
notes_par_ligne AS (
    SELECT
        b.production_line          AS production_line_id,
        MIN(bn.created_at)         AS first_note_at,
        COUNT(*)                   AS nb_notes
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
    ON t.common_code = pl.common_code
ORDER BY deployment_date;


-- -----------------------------------------------------------------------------
-- Requête 2 : contrôle (requête initiale de Calcul.ipynb)
-- -----------------------------------------------------------------------------
SELECT COUNT(DISTINCT PL.id_plant_production_line) AS NbreSites
FROM ext_mal_psql_maite_vision_board_prd.public.plants_production_lines PL
INNER JOIN ext_mal_psql_maite_vision_board_prd.public.batches B
    ON PL.id_plant_production_line = B.production_line
INNER JOIN ext_mal_psql_maite_vision_board_prd.public.batches_notes BN
    ON B.id_batch = BN.batch
INNER JOIN mal_maite_common_prd.gold.trs_metadata MD
    ON (
        CASE
            WHEN MD.prd_line = 'burton1'     THEN 'BT1'
            WHEN MD.prd_line = 'rouen1'      THEN 'RO1'
            WHEN MD.prd_line = 'polisy1'     THEN 'PO1'
            WHEN MD.prd_line = 'bolelemi1'   THEN 'BO1'
            WHEN MD.prd_line = 'strasbourg1' THEN 'ST1'
            WHEN MD.prd_line = 'strasbourg2' THEN 'ST2'
            WHEN MD.prd_line = 'nogent1'     THEN 'NG1'
            WHEN MD.prd_line = 'nogent2'     THEN 'NG2'
            WHEN MD.prd_line = 'NYMBURK1'    THEN 'NY1'
            WHEN MD.prd_line = 'prouvy1'     THEN 'PR1'
            WHEN MD.prd_line = 'buzau1'      THEN 'BU1'
            -- WHEN MD.prd_line = 'pithiviers6' THEN 'PI6'
            WHEN MD.prd_line = 'burton2'     THEN 'BT2'
            WHEN MD.prd_line = 'HODONICE1'   THEN 'HO1'
            WHEN MD.prd_line = 'KROMERIZ1'   THEN 'KR1'
            ELSE MD.prd_line
        END
    ) = PL.common_code
WHERE B.deleted = FALSE;
