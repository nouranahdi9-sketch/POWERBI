-- =====================================================================
-- Phase 2 : ajout des identifiants de traduction aux tables du modèle
--
-- Équivalent SQL du notebook phase2_migration_schema, pour l'exécuter
-- directement dans l'éditeur SQL.
--
-- ADD COLUMNS est une opération de MÉTADONNÉES sur Delta : les données ne
-- sont pas réécrites, et les lignes existantes prennent NULL sur les
-- nouvelles colonnes. Ces NULL seront remplis au prochain run du pipeline.
--
-- Environnement : preprd. Remplacer par _prd pour la production.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. dim_batches_specifications : les 4 identifiants
-- ---------------------------------------------------------------------

ALTER TABLE mal_maite_bi_preprd.process_time_analyses.dim_batches_specifications
ADD COLUMNS (
    id_good_specy                INT,
    id_good_variety              INT,
    id_parameter_production_type INT,
    id_requirement_specification INT
);


-- ---------------------------------------------------------------------
-- 2. fact_batch_note : les 4 clés préfixées
--
-- À N'EXÉCUTER QUE si les colonnes location / event / detail / impact de
-- batches_notes ne portent PAS déjà le préfixe. Vérifier d'abord :
--
--   SELECT location, event, detail, impact
--   FROM ext_mal_psql_maite_vision_board_test.public.batches_notes
--   WHERE deleted = false AND location IS NOT NULL
--   LIMIT 5;
--
-- Si les valeurs ressemblent à "location_transfert_trempe_germoir", le
-- préfixe est déjà là : ces colonnes sont inutiles, ne pas les créer et
-- relier directement sur location / event / detail / impact.
-- ---------------------------------------------------------------------

-- ALTER TABLE mal_maite_bi_preprd.process_time_analyses.fact_batch_note
-- ADD COLUMNS (
--     key_location STRING,
--     key_impact   STRING,
--     key_event    STRING,
--     key_detail   STRING
-- );


-- ---------------------------------------------------------------------
-- 3. Contrôle
-- ---------------------------------------------------------------------

DESCRIBE TABLE mal_maite_bi_preprd.process_time_analyses.dim_batches_specifications;
