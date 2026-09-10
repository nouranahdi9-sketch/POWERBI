-- =====================================================================
-- Purge des neuf paramètres devenus colonnes de dim_batch (Self Service)
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
-- Ce script supprime ces lignes orphelines pour LES NEUF PARAMÈTRES devenus
-- colonnes de dim_batch. À exécuter UNE FOIS, après avoir exécuté le
-- notebook. Les exécutions suivantes n'en auront plus besoin : le filtre de
-- la cellule 28 empêche toute réinsertion.
--
-- Alternative : relancer le notebook avec le widget execution_mode = "full"
-- (delete + insert intégral). Plus radical, plus long, et cela réinitialise
-- created_at sur toutes les lignes. À noter : ce mode purgerait AUSSI les six
-- paramètres de la section 5 ci-dessous, sans qu'on ait à en décider.
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
        'Fabrication order',
        'Production line',
        'Production type',
        'Harvest',
        'Start of production',
        'End of production',
        'Specifications',
        'Species',
        'Variety'
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
        'Variety'
      );


-- ---------------------------------------------------------------------
-- 3. CONTRÔLE APRÈS — doit renvoyer 0 ligne
-- ---------------------------------------------------------------------

SELECT trim(parameter) AS parametre, count(*) AS nb_lignes
FROM mal_maite_bi_preprd.self_service.fact_batch_report
WHERE trim(parameter) IN (
        'Fabrication order', 'Production line', 'Production type', 'Harvest',
        'Start of production', 'End of production', 'Specifications',
        'Species', 'Variety'
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


-- ---------------------------------------------------------------------
-- 5. CONTRÔLE SEUL (aucune suppression) — les six paramètres retirés
--    antérieurement, hors périmètre traduction
-- ---------------------------------------------------------------------
--
-- Ces six paramètres figuraient déjà dans `to_drop` avant les travaux de
-- traduction (commentaire du notebook : "modif suite demande William
-- réorganisation des colonnes"). Ils ne sont donc plus alimentés.
--
-- Comme le mode "update" ne supprime rien, ils SONT PEUT-ÊTRE encore
-- présents dans la table — cela dépend de si leur retrait de `to_drop` est
-- antérieur ou postérieur à la première alimentation, ce que le dépôt ne
-- permet pas de trancher.
--
-- Cette requête ne fait que compter. La décision de les purger n'appartient
-- pas au chantier traduction : à vérifier d'abord qu'aucun autre onglet ne
-- les affiche encore.

SELECT
    trim(parameter)          AS parametre,
    count(*)                 AS nb_lignes,
    count(DISTINCT id_batch) AS nb_lots,
    max(created_at)          AS derniere_insertion,
    max(updated_at)          AS derniere_maj
FROM mal_maite_bi_preprd.self_service.fact_batch_report
WHERE trim(parameter) IN (
        'Mes number',
        'Moisture Malt',
        'Indice qualite',
        '#_volume',
        'Goods Calibration Date',
        'Goods Storage Duration'
      )
GROUP BY trim(parameter)
ORDER BY parametre;
