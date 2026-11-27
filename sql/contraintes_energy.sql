-- =====================================================================
-- Cles etrangeres du schema energy (catalog mal_maite_bi_prd)
-- Source : relations du modele Power BI "ENERGY V2 Fige"
-- Les contraintes PK/FK Unity Catalog sont informatives (non verifiees).
-- Une fois creees : Catalog Explorer > table > "View relationships"
-- =====================================================================

USE CATALOG mal_maite_bi_prd;

-- ---------------------------------------------------------------------
-- ETAPE 0 : verifications avant de creer les cles
-- ---------------------------------------------------------------------

-- 0.a Types des colonnes a relier (une FK exige le meme type des deux cotes)
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema IN ('energy', 'common')
  AND column_name IN ('production_line', 'variety', 'requirement_specifications',
                      'max_end_date_kiln_unload', 'end_date',
                      'id_plant_production_line', 'id_good_variety',
                      'id_requirement_specification', 'day_date')
ORDER BY table_schema, table_name;

-- 0.b Les futures PK de common ne doivent avoir ni NULL ni doublon
--     (attendu : 0 partout)
SELECT 'dim_site' AS t,
       count(*) - count(DISTINCT id_plant_production_line) AS doublons,
       count_if(id_plant_production_line IS NULL)            AS nulls
FROM common.dim_site
UNION ALL
SELECT 'dim_variety',
       count(*) - count(DISTINCT id_good_variety),
       count_if(id_good_variety IS NULL)
FROM common.dim_variety
UNION ALL
SELECT 'dim_requirement_specification',
       count(*) - count(DISTINCT id_requirement_specification),
       count_if(id_requirement_specification IS NULL)
FROM common.dim_requirement_specification;

-- ---------------------------------------------------------------------
-- ETAPE 1 : cles primaires manquantes sur les dimensions de common
-- (dim_calendar a deja pk_dim_calendar)
-- ---------------------------------------------------------------------

ALTER TABLE common.dim_site ALTER COLUMN id_plant_production_line SET NOT NULL;
ALTER TABLE common.dim_site
  ADD CONSTRAINT pk_dim_site PRIMARY KEY (id_plant_production_line);

ALTER TABLE common.dim_variety ALTER COLUMN id_good_variety SET NOT NULL;
ALTER TABLE common.dim_variety
  ADD CONSTRAINT pk_dim_variety PRIMARY KEY (id_good_variety);

ALTER TABLE common.dim_requirement_specification ALTER COLUMN id_requirement_specification SET NOT NULL;
ALTER TABLE common.dim_requirement_specification
  ADD CONSTRAINT pk_dim_requirement_specification PRIMARY KEY (id_requirement_specification);

-- ---------------------------------------------------------------------
-- ETAPE 2 : cles etrangeres
-- ---------------------------------------------------------------------

-- fact_batch_measures -> dim_batch, dim_parameter
ALTER TABLE energy.fact_batch_measures
  ADD CONSTRAINT fk_fact_batch_measures_batch
  FOREIGN KEY (batch_id) REFERENCES energy.dim_batch (batch_id);

ALTER TABLE energy.fact_batch_measures
  ADD CONSTRAINT fk_fact_batch_measures_parameter
  FOREIGN KEY (parameter_id) REFERENCES energy.dim_parameter (parameter_id);

-- fact_batch_localization -> dim_batch, dim_calendar
ALTER TABLE energy.fact_batch_localization
  ADD CONSTRAINT fk_fact_batch_localization_batch
  FOREIGN KEY (batch_id) REFERENCES energy.dim_batch (batch_id);

ALTER TABLE energy.fact_batch_localization
  ADD CONSTRAINT fk_fact_batch_localization_calendar
  FOREIGN KEY (end_date) REFERENCES common.dim_calendar (day_date);

-- dim_report_parameter_mapping -> dim_parameter
ALTER TABLE energy.dim_report_parameter_mapping
  ADD CONSTRAINT fk_dim_report_parameter_mapping_parameter
  FOREIGN KEY (parameter_id) REFERENCES energy.dim_parameter (parameter_id);

-- dim_batch -> dimensions communes
ALTER TABLE energy.dim_batch
  ADD CONSTRAINT fk_dim_batch_site
  FOREIGN KEY (production_line) REFERENCES common.dim_site (id_plant_production_line);

ALTER TABLE energy.dim_batch
  ADD CONSTRAINT fk_dim_batch_variety
  FOREIGN KEY (variety) REFERENCES common.dim_variety (id_good_variety);

ALTER TABLE energy.dim_batch
  ADD CONSTRAINT fk_dim_batch_requirement_specification
  FOREIGN KEY (requirement_specifications) REFERENCES common.dim_requirement_specification (id_requirement_specification);

ALTER TABLE energy.dim_batch
  ADD CONSTRAINT fk_dim_batch_calendar
  FOREIGN KEY (max_end_date_kiln_unload) REFERENCES common.dim_calendar (day_date);

-- ---------------------------------------------------------------------
-- ETAPE 3 : controle (doit lister les 9 FK)
-- ---------------------------------------------------------------------
SELECT table_schema, table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY'
ORDER BY table_schema, table_name;
