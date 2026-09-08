-- Quelle traduction manque, pour quel libellé, dans quelle langue
--
-- Une ligne par libellé et par langue manquante. Rien d'autre.
--
-- Chaque entrée de nomenclature est croisée avec les 4 langues du projet ;
-- on ne garde que les couples pour lesquels aucune traduction non vide
-- n'existe.
--
-- Environnement : remplacer _prd par _test pour la préprod.

SELECT 'Espèce' AS donnee,
       CAST(n.code AS STRING) AS libelle,
       CAST(n.id_good_specy AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.goods_species n
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.goods_species_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.good_specy = n.id_good_specy
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL

SELECT 'Variété' AS donnee,
       CAST(n.code AS STRING) AS libelle,
       CAST(n.id_good_variety AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.goods_varieties n
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.goods_varieties_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.good_variety = n.id_good_variety
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL

SELECT 'Type de production' AS donnee,
       CAST(n.code AS STRING) AS libelle,
       CAST(n.id_parameter_production_type AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_types n
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_type_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.id_parameters_production_type = n.id_parameter_production_type
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL

SELECT 'Variable' AS donnee,
       CAST(n.code AS STRING) AS libelle,
       CAST(n.id_parameter_variable AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_variables n
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_variables_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.parameter_variable = n.id_parameter_variable
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL

SELECT 'Variable de ligne de production' AS donnee,
       CONCAT(COALESCE(v.code, 'variable inconnue'), ' / ', COALESCE(p.name, 'ligne inconnue')) AS libelle,
       CAST(n.id_parameter_production_line_variable AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables n
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_variables v ON v.id_parameter_variable = n.variable
    LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines p ON p.id_plant_production_line = n.production_line
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.parameter_production_line_variable = n.id_parameter_production_line_variable
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL

SELECT 'Emplacement' AS donnee,
       CAST(n.code AS STRING) AS libelle,
       CAST(n.id_parameter_localization AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localizations n
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localizations_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.id_parameter_localization = n.id_parameter_localization
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL

SELECT 'Groupe d’emplacements' AS donnee,
       CAST(n.code AS STRING) AS libelle,
       CAST(n.id_parameter_localization_group AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localization_groups n
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_localization_groups_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.id_parameter_localization_group = n.id_parameter_localization_group
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

UNION ALL

SELECT 'Note de production' AS donnee,
       COALESCE(CAST(n.category_label AS STRING), CAST(n.id_batch_note_category AS STRING)) AS libelle,
       CAST(n.id_batch_note_category AS STRING) AS identifiant,
       l.nom AS langue_manquante
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories n
CROSS JOIN (
    SELECT 'FR' AS code, 'Français' AS nom
    UNION ALL SELECT 'EN', 'Anglais'
    UNION ALL SELECT 'RO', 'Roumain'
    UNION ALL SELECT 'CZ', 'Tchèque'
) l
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories_translations t
      JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_languages pl
        ON pl.id_parameter_language = t.language
       AND pl.code = l.code
      WHERE t.batch_note_category = n.id_batch_note_category
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )

ORDER BY donnee, libelle, langue_manquante;
