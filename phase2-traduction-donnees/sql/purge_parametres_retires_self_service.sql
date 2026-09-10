-- =====================================================================
-- Purge des paramètres retirés de fact_batch_report (Self Service)
-- =====================================================================
--
-- POURQUOI CE SCRIPT
--
-- import_self_service publie fact_batch_report via handle_table_update
-- avec mode = "update" (valeur par défaut de execution_mode, cellule 2).
-- Ce mode fait un MERGE limité à whenMatchedUpdate + whenNotMatchedInsert :
-- il ne comporte AUCUNE clause de suppression.
--
-- Retirer un paramètre de la liste `to_drop` (cellule 28) l'enlève donc du
-- DataFrame source, mais PAS de la table cible : les lignes écrites par les
-- exécutions précédentes y restent indéfiniment, et la matrice de l'onglet
-- BATCH continue de les afficher en colonnes.
--
-- Ce script supprime ces lignes orphelines. À exécuter UNE FOIS, après avoir
-- exécuté le notebook. Les exécutions suivantes n'en auront plus besoin :
-- le filtre de la cellule 28 empêche toute réinsertion.
--
-- Alternative : relancer le notebook avec le widget execution_mode = "full"
-- (delete + insert intégral). Plus radical, plus long, et cela réinitialise
-- created_at sur toutes les lignes.
--
-- Environnement : preprd. Adapter le catalogue pour prd.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CONTRÔLE AVANT — combien de lignes vont être supprimées, par paramètre
-- ---------------------------------------------------------------------

SELECT
    trim(parameter)              AS parametre,
    count(*)                     AS nb_lignes,
    count(DISTINCT id_batch)     AS nb_lots
FROM mal_maite_bi_preprd.self_service.fact_batch_report
WHERE trim(parameter) IN (
        -- Les neuf paramètres devenus colonnes de dim_batch
        'Fabrication order',
        'Production line',
        'Production type',
        'Harvest',
        'Start of production',
        'End of production',
        'Specifications',
        'Species',
        'Variety',
        -- Les six paramètres déjà retirés antérieurement (demande William)
        'Mes number',
        'Moisture Malt',
        'Indice qualite',
        '#_volume',
        'Goods Calibration Date',
        'Goods Storage Duration'
      )
GROUP BY trim(parameter)
ORDER BY parametre;


-- ---------------------------------------------------------------------
-- 2. SUPPRESSION
-- ---------------------------------------------------------------------

DELETE FROM mal_maite_bi_preprd.self_service.fact_batch_report
WHERE trim(parameter) IN (
        'Fabrication order',
        'Production line',
        'Production type',
        'Harvest',
        'Start of production',
        'End of production',
        'Specifications',
        'Species',
        'Variety',
        'Mes number',
        'Moisture Malt',
        'Indice qualite',
        '#_volume',
        'Goods Calibration Date',
        'Goods Storage Duration'
      );


-- ---------------------------------------------------------------------
-- 3. CONTRÔLE APRÈS — doit renvoyer 0 ligne
-- ---------------------------------------------------------------------

SELECT trim(parameter) AS parametre, count(*) AS nb_lignes
FROM mal_maite_bi_preprd.self_service.fact_batch_report
WHERE trim(parameter) IN (
        'Fabrication order', 'Production line', 'Production type', 'Harvest',
        'Start of production', 'End of production', 'Specifications',
        'Species', 'Variety', 'Mes number', 'Moisture Malt', 'Indice qualite',
        '#_volume', 'Goods Calibration Date', 'Goods Storage Duration'
      )
GROUP BY trim(parameter);


-- ---------------------------------------------------------------------
-- 4. INVENTAIRE — la liste réelle des paramètres restants
-- ---------------------------------------------------------------------
--
-- À comparer avec les rangs de `custom_order` (cellule 29). Tout paramètre
-- qui ressort ici avec custom_order = 99 n'a pas de rang attribué et se
-- retrouvera en fin de matrice.

SELECT
    trim(parameter)          AS parametre,
    count(*)                 AS nb_lignes,
    count(DISTINCT id_batch) AS nb_lots,
    min(custom_order)        AS custom_order
FROM mal_maite_bi_preprd.self_service.fact_batch_report
GROUP BY trim(parameter)
ORDER BY min(custom_order), parametre;
