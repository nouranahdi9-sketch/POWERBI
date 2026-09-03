-- =====================================================================
-- Copie PROD -> PREPROD des référentiels partagés du schéma common
--
-- Tables concernées : dim_calendar, dim_language, translation
-- dim_site est exclue : elle est déjà alimentée en preprd par le job
-- des nomenclatures.
--
-- DEEP CLONE copie les données ET la structure, en une seule commande.
-- L'opération est rejouable : relancer le bloc 2 rafraîchit la copie.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Première création (ne fait rien si la table existe déjà)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mal_maite_bi_preprd.common.dim_calendar
DEEP CLONE mal_maite_bi_prd.common.dim_calendar;

CREATE TABLE IF NOT EXISTS mal_maite_bi_preprd.common.dim_language
DEEP CLONE mal_maite_bi_prd.common.dim_language;

CREATE TABLE IF NOT EXISTS mal_maite_bi_preprd.common.translation
DEEP CLONE mal_maite_bi_prd.common.translation;


-- ---------------------------------------------------------------------
-- 2. Rafraîchissement (à relancer quand la PROD a évolué)
--    ATTENTION : remplace intégralement la table de preprd.
-- ---------------------------------------------------------------------

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.common.dim_calendar
-- DEEP CLONE mal_maite_bi_prd.common.dim_calendar;

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.common.dim_language
-- DEEP CLONE mal_maite_bi_prd.common.dim_language;

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.common.translation
-- DEEP CLONE mal_maite_bi_prd.common.translation;


-- ---------------------------------------------------------------------
-- 3. Contrôle : les volumes doivent correspondre
-- ---------------------------------------------------------------------

SELECT 'dim_calendar' AS table_name,
       (SELECT count(*) FROM mal_maite_bi_prd.common.dim_calendar)    AS prod,
       (SELECT count(*) FROM mal_maite_bi_preprd.common.dim_calendar) AS preprd
UNION ALL
SELECT 'dim_language',
       (SELECT count(*) FROM mal_maite_bi_prd.common.dim_language),
       (SELECT count(*) FROM mal_maite_bi_preprd.common.dim_language)
UNION ALL
SELECT 'translation',
       (SELECT count(*) FROM mal_maite_bi_prd.common.translation),
       (SELECT count(*) FROM mal_maite_bi_preprd.common.translation);


-- ---------------------------------------------------------------------
-- Solution de repli si DEEP CLONE est refusé
--
-- CLONE exige que les deux catalogues soient dans le même metastore et
-- que la source soit en Delta. Si la commande échoue, ce CTAS copie les
-- mêmes données — mais sans les propriétés de table ni l'historique.
-- ---------------------------------------------------------------------

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.common.dim_calendar
-- AS SELECT * FROM mal_maite_bi_prd.common.dim_calendar;

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.common.dim_language
-- AS SELECT * FROM mal_maite_bi_prd.common.dim_language;

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.common.translation
-- AS SELECT * FROM mal_maite_bi_prd.common.translation;
