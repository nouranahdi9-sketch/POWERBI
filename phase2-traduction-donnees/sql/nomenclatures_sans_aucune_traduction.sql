-- Entrées de nomenclature n'ayant AUCUNE ligne de traduction
--
-- Couvre les 8 nomenclatures de la base du front qui disposent d'une table de
-- traductions, pas seulement celles utilisées par le rapport Process Time
-- Analyses.
--
-- « Aucune ligne traduite » signifie : pas une seule ligne active dans la table
-- de traductions, quelle que soit la langue, avec un libellé non vide. Ces
-- entrées s'afficheront donc avec leur clé technique brute.
--
-- Utilise NOT EXISTS plutôt qu'une jointure agrégée : le test porte sur chaque
-- nomenclature dans son propre bloc, sans clé composée susceptible d'être
-- nulle.
--
-- Environnement : remplacer _prd par _test pour la préprod.

SELECT 'specy' AS nomenclature,
       CAST(n.id_good_specy AS STRING) AS cle,
       CAST(n.code AS STRING)          AS libelle_metier
FROM ext_mal_psql_maite_vision_board_prd.public.goods_species n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.goods_species_translations t
      WHERE t.good_specy = n.id_good_specy
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL
SELECT 'variety',
       CAST(n.id_good_variety AS STRING),
       CAST(n.code AS STRING)
FROM ext_mal_psql_maite_vision_board_prd.public.goods_varieties n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.goods_varieties_translations t
      WHERE t.good_variety = n.id_good_variety
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL
SELECT 'production_type',
       CAST(n.id_parameter_production_type AS STRING),
       CAST(n.code AS STRING)
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_types n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_type_translations t
      WHERE t.id_parameters_production_type = n.id_parameter_production_type
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL
SELECT 'variable',
       CAST(n.id_parameter_variable AS STRING),
       CAST(n.code AS STRING)
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_variables n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_variables_translations t
      WHERE t.parameter_variable = n.id_parameter_variable
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

-- Cette nomenclature n'a pas de colonne code : son libellé n'existe que dans
-- la table de traduction, donc une entrée non traduite n'a rien à afficher.
UNION ALL
SELECT 'production_line_variable',
       CAST(n.id_parameter_production_line_variable AS STRING),
       NULL
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables_translations t
      WHERE t.parameter_production_line_variable = n.id_parameter_production_line_variable
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL
SELECT 'localization',
       CAST(n.id_parameter_localization AS STRING),
       CAST(n.code AS STRING)
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localizations n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localizations_translations t
      WHERE t.id_parameter_localization = n.id_parameter_localization
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL
SELECT 'localization_group',
       CAST(n.id_parameter_localization_group AS STRING),
       CAST(n.code AS STRING)
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localization_groups n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localization_groups_translations t
      WHERE t.id_parameter_localization_group = n.id_parameter_localization_group
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

-- category_class peut être nul en base : on le remplace par « sans_classe »
-- pour que ces entrées restent visibles dans le résultat. Ce sont celles que
-- le pipeline BI n'importe pas, faute de famille renseignée.
UNION ALL
SELECT CONCAT('batch_note_', COALESCE(n.category_class, 'sans_classe')),
       CAST(n.id_batch_note_category AS STRING),
       CAST(n.category_label AS STRING)
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories n
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories_translations t
      WHERE t.batch_note_category = n.id_batch_note_category
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

ORDER BY 1, 2;
