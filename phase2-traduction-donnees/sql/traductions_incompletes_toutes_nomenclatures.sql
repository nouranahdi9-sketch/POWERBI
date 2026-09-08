-- Entrées de nomenclature auxquelles il manque AU MOINS UNE des 4 langues
--
-- Couvre les 8 nomenclatures de la base du front disposant d'une table de
-- traductions. Complète nomenclatures_sans_aucune_traduction.sql, qui ne
-- remonte que les manques totaux.
--
-- Une entrée ressort dès qu'il lui manque une langue, qu'elle en ait 0, 1, 2
-- ou 3 sur les 4. La colonne langues_manquantes dit lesquelles ajouter.
--
-- Une ligne de traduction existante mais au libellé vide ne compte pas.
-- L'agrégation est faite bloc par bloc, sur l'identifiant réel de chaque
-- nomenclature : aucune clé composée, donc aucun risque de jointure nulle.
--
-- Environnement : remplacer _prd par _test pour la préprod.
--
-- Attention au volume : production_line_variable remonte plusieurs centaines
-- d'entrées non traduites, et n'est pas utilisée par Process Time Analyses.
-- Pour s'en tenir au périmètre du rapport, ajouter avant le ORDER BY :
--     ) x WHERE x.nomenclature IN ('specy','variety','production_type',
--         'batch_note_location','batch_note_event','batch_note_detail',
--         'batch_note_impact')
-- en enveloppant l'ensemble des UNION dans SELECT * FROM ( ... ) x

SELECT * FROM (
    SELECT 'specy' AS nomenclature,
           CAST(n.id_good_specy AS STRING)                                     AS cle,
           CAST(n.code AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.goods_species n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.goods_species_translations t
           ON t.good_specy = n.id_good_specy
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
UNION ALL
SELECT * FROM (
    SELECT 'variety' AS nomenclature,
           CAST(n.id_good_variety AS STRING)                                     AS cle,
           CAST(n.code AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.goods_varieties n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.goods_varieties_translations t
           ON t.good_variety = n.id_good_variety
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
UNION ALL
SELECT * FROM (
    SELECT 'production_type' AS nomenclature,
           CAST(n.id_parameter_production_type AS STRING)                                     AS cle,
           CAST(n.code AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_types n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_production_type_translations t
           ON t.id_parameters_production_type = n.id_parameter_production_type
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
UNION ALL
SELECT * FROM (
    SELECT 'variable' AS nomenclature,
           CAST(n.id_parameter_variable AS STRING)                                     AS cle,
           CAST(n.code AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_variables n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_variables_translations t
           ON t.parameter_variable = n.id_parameter_variable
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
UNION ALL
SELECT * FROM (
    SELECT 'production_line_variable' AS nomenclature,
           CAST(n.id_parameter_production_line_variable AS STRING)                                     AS cle,
           CAST(NULL AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables_translations t
           ON t.parameter_production_line_variable = n.id_parameter_production_line_variable
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
UNION ALL
SELECT * FROM (
    SELECT 'localization' AS nomenclature,
           CAST(n.id_parameter_localization AS STRING)                                     AS cle,
           CAST(n.code AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localizations n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_localizations_translations t
           ON t.id_parameter_localization = n.id_parameter_localization
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
UNION ALL
SELECT * FROM (
    SELECT 'localization_group' AS nomenclature,
           CAST(n.id_parameter_localization_group AS STRING)                                     AS cle,
           CAST(n.code AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localization_groups n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_localization_groups_translations t
           ON t.id_parameter_localization_group = n.id_parameter_localization_group
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
UNION ALL
SELECT * FROM (
    SELECT CONCAT('batch_note_', COALESCE(n.category_class, 'sans_classe')) AS nomenclature,
           CAST(n.id_batch_note_category AS STRING)                                     AS cle,
           CAST(n.category_label AS STRING)                                                       AS libelle_metier,
           COUNT(DISTINCT l.code)                                      AS nb_langues,
           ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(l.code)), ', ')           AS langues_presentes,
           ARRAY_JOIN(
               SORT_ARRAY(
                   ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))
               ), ', ')                                                AS langues_manquantes
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories_translations t
           ON t.batch_note_category = n.id_batch_note_category
          AND t.deleted = false
          AND TRIM(COALESCE(t.label, '')) <> ''
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages l
           ON l.id_parameter_language = t.language
          AND l.deleted = false
          AND l.code IN ('FR', 'EN', 'RO', 'CZ')
    WHERE n.deleted = false
    GROUP BY 1, 2, 3
    HAVING COUNT(DISTINCT l.code) < 4
)
ORDER BY 1, 4, 2;
