-- =====================================================================
-- Copie PROD -> PREPROD de self_service.fact_manual_entries
-- =====================================================================
--
-- POURQUOI
--
-- Le notebook import_self_service ne produit pas cette table : il publie
-- dim_batch, fact_batch_report, fact_energy, fact_measurement et
-- fact_weather, rien d'autre. fact_manual_entries est alimentee par un
-- traitement qui n'est pas dans ce depot, et qui ne tourne pas sur preprd.
--
-- Resultat : la requete Power Query `manual_entries`, une fois basculee
-- sur preprd, ne trouve rien et Power BI refuse de la charger
-- ("aucune colonne avec les types de donnees pris en charge").
--
-- Ce script copie la table depuis la prod pour debloquer l'onglet PROD
-- du rapport, qui l'utilise dans un tableau et un slicer.
--
-- ATTENTION : c'est une PHOTO, pas une synchronisation. La copie ne se
-- met pas a jour toute seule ; relancer le bloc 2 quand la prod a evolue.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Premiere creation (ne fait rien si la table existe deja)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mal_maite_bi_preprd.self_service.fact_manual_entries
DEEP CLONE mal_maite_bi_prd.self_service.fact_manual_entries;


-- ---------------------------------------------------------------------
-- 2. Rafraichissement (a relancer quand la PROD a evolue)
--    ATTENTION : remplace integralement la table de preprd.
-- ---------------------------------------------------------------------

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.self_service.fact_manual_entries
-- DEEP CLONE mal_maite_bi_prd.self_service.fact_manual_entries;


-- ---------------------------------------------------------------------
-- 3. Controle : les volumes doivent correspondre
-- ---------------------------------------------------------------------

SELECT 'fact_manual_entries' AS table_name,
       (SELECT count(*) FROM mal_maite_bi_prd.self_service.fact_manual_entries)    AS prod,
       (SELECT count(*) FROM mal_maite_bi_preprd.self_service.fact_manual_entries) AS preprd;


-- ---------------------------------------------------------------------
-- 4. Controle : les colonnes attendues par le rapport sont bien la
--
-- Le tableau et le slicer de l'onglet PROD lisent parameter_variable,
-- value, unit et id_batch. Les quatre doivent ressortir ici.
-- ---------------------------------------------------------------------

DESCRIBE TABLE mal_maite_bi_preprd.self_service.fact_manual_entries;


-- ---------------------------------------------------------------------
-- Solution de repli si DEEP CLONE est refuse
--
-- CLONE exige que les deux catalogues soient dans le meme metastore et
-- que la source soit en Delta. Si la commande echoue, ce CTAS copie les
-- memes donnees — mais sans les proprietes de table ni l'historique.
-- ---------------------------------------------------------------------

-- CREATE OR REPLACE TABLE mal_maite_bi_preprd.self_service.fact_manual_entries
-- AS SELECT * FROM mal_maite_bi_prd.self_service.fact_manual_entries;
