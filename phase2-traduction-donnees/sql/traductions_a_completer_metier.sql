-- Traductions à compléter — toutes les nomenclatures
--
-- Version destinée au métier : noms de données et de langues en clair.
-- Couvre les 8 nomenclatures de l'application disposant d'une table de
-- traductions, sans restriction au périmètre du rapport.
--
-- Une donnée ressort dès qu'il lui manque une des 4 langues du projet
-- (français, anglais, roumain, tchèque). Une ligne de traduction existante
-- mais au libellé vide ne compte pas comme traduite.
--
-- La colonne « Affiché dans Process Time Analyses » permet de prioriser :
-- les données marquées Non sont utilisées ailleurs dans l'application.
--
-- Environnement : remplacer _prd par _test pour la préprod.
--
-- Une requête de synthèse par catégorie figure en fin de fichier.

SELECT
    CASE resultat.categorie
        WHEN 'specy'                    THEN 'Espèce'
        WHEN 'variety'                  THEN 'Variété'
        WHEN 'production_type'          THEN 'Type de production'
        WHEN 'variable'                 THEN 'Variable'
        WHEN 'production_line_variable' THEN 'Variable de ligne de production'
        WHEN 'localization'             THEN 'Emplacement'
        WHEN 'localization_group'       THEN 'Groupe d’emplacements'
        WHEN 'batch_note_location'      THEN 'Note de production — Emplacement'
        WHEN 'batch_note_event'         THEN 'Note de production — Événement'
        WHEN 'batch_note_detail'        THEN 'Note de production — Détail'
        WHEN 'batch_note_impact'        THEN 'Note de production — Impact'
        WHEN 'batch_note_sans_classe'   THEN 'Note de production — famille non renseignée'
        ELSE resultat.categorie
    END                                              AS `Donnee`,
    resultat.libelle_actuel                         AS `Libelle actuel`,
    resultat.identifiant                            AS `Identifiant technique`,
    resultat.deja_traduit                           AS `Deja traduit en`,
    resultat.a_completer                            AS `A completer en`,
    CASE
        WHEN resultat.nb_langues = 0
            THEN 'Critique — aucun libellé, le code technique s’affiche'
        ELSE 'À corriger — le libellé anglais s’affiche à la place'
    END                                             AS `Consequence utilisateur`,
    CASE
        WHEN resultat.categorie IN (
            'specy', 'variety', 'production_type',
            'batch_note_location', 'batch_note_event',
            'batch_note_detail', 'batch_note_impact'
        ) THEN 'Oui'
        ELSE 'Non'
    END                                             AS `Affiche dans le rapport`
FROM (
SELECT * FROM (
    SELECT 'specy' AS categorie,
           CAST(n.id_good_specy AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'variety' AS categorie,
           CAST(n.id_good_variety AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'production_type' AS categorie,
           CAST(n.id_parameter_production_type AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'variable' AS categorie,
           CAST(n.id_parameter_variable AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'production_line_variable' AS categorie,
           CAST(n.id_parameter_production_line_variable AS STRING) AS identifiant,
           CAST(NULL AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'localization' AS categorie,
           CAST(n.id_parameter_localization AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'localization_group' AS categorie,
           CAST(n.id_parameter_localization_group AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT CONCAT('batch_note_', COALESCE(n.category_class, 'sans_classe')) AS categorie,
           CAST(n.id_batch_note_category AS STRING) AS identifiant,
           CAST(n.category_label AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
) resultat
ORDER BY resultat.nb_langues, 1, 2;


-- ---------------------------------------------------------------------------
-- Synthèse : combien de données à compléter par catégorie.
-- Utile pour cadrer la charge avant d'envoyer la liste détaillée.
-- ---------------------------------------------------------------------------

-- SELECT
--     CASE resultat.categorie
        WHEN 'specy'                    THEN 'Espèce'
        WHEN 'variety'                  THEN 'Variété'
        WHEN 'production_type'          THEN 'Type de production'
        WHEN 'variable'                 THEN 'Variable'
        WHEN 'production_line_variable' THEN 'Variable de ligne de production'
        WHEN 'localization'             THEN 'Emplacement'
        WHEN 'localization_group'       THEN 'Groupe d’emplacements'
        WHEN 'batch_note_location'      THEN 'Note de production — Emplacement'
        WHEN 'batch_note_event'         THEN 'Note de production — Événement'
        WHEN 'batch_note_detail'        THEN 'Note de production — Détail'
        WHEN 'batch_note_impact'        THEN 'Note de production — Impact'
        WHEN 'batch_note_sans_classe'   THEN 'Note de production — famille non renseignée'
        ELSE resultat.categorie
    END                                           AS `Donnee`,
--     COUNT(*)                                     AS `Nb a completer`,
--     SUM(CASE WHEN resultat.nb_langues = 0 THEN 1 ELSE 0 END)
--                                                  AS `Dont aucune traduction`
-- FROM (
-- SELECT * FROM (
    SELECT 'specy' AS categorie,
           CAST(n.id_good_specy AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'variety' AS categorie,
           CAST(n.id_good_variety AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'production_type' AS categorie,
           CAST(n.id_parameter_production_type AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'variable' AS categorie,
           CAST(n.id_parameter_variable AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'production_line_variable' AS categorie,
           CAST(n.id_parameter_production_line_variable AS STRING) AS identifiant,
           CAST(NULL AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'localization' AS categorie,
           CAST(n.id_parameter_localization AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT 'localization_group' AS categorie,
           CAST(n.id_parameter_localization_group AS STRING) AS identifiant,
           CAST(n.code AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
    SELECT CONCAT('batch_note_', COALESCE(n.category_class, 'sans_classe')) AS categorie,
           CAST(n.id_batch_note_category AS STRING) AS identifiant,
           CAST(n.category_label AS STRING)                   AS libelle_actuel,
           COUNT(DISTINCT l.code)  AS nb_langues,
           ARRAY_JOIN(
               TRANSFORM(SORT_ARRAY(COLLECT_SET(l.code)), c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END), ', '
           ) AS deja_traduit,
           ARRAY_JOIN(
               TRANSFORM(
                   SORT_ARRAY(ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(l.code))),
                   c -> CASE c
                    WHEN 'FR' THEN 'Français'
                    WHEN 'EN' THEN 'Anglais'
                    WHEN 'RO' THEN 'Roumain'
                    WHEN 'CZ' THEN 'Tchèque'
                END
               ), ', '
           ) AS a_completer
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
-- ) resultat
-- GROUP BY 1
-- ORDER BY 2 DESC;
