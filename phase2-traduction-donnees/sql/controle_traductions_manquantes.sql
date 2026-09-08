-- Traductions manquantes dans les tables sources PostgreSQL
--
-- Recense les entrées de nomenclature auxquelles il manque au moins une des
-- 4 langues du périmètre (FR, EN, RO, CZ). Interroge directement la base du
-- front, sans passer par les tables dim_trad_* construites côté BI.
--
-- Environnement : remplacer _prd par _test pour la préprod.
-- Les 4 nomenclatures couvertes sont celles réellement traduites dans le
-- rapport Process Time Analyses.

WITH langues AS (
    SELECT id_parameter_language, code
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_languages
    WHERE deleted = false
      AND code IN ('FR', 'EN', 'RO', 'CZ')
),

-- Les entrées actives de chaque nomenclature, avec leur code métier.
nomenclatures AS (
    SELECT 'specy'                          AS nomenclature,
           CAST(id_good_specy AS STRING)    AS cle,
           CAST(code AS STRING)             AS libelle_metier
    FROM ext_mal_psql_maite_vision_board_prd.public.goods_species
    WHERE deleted = false

    UNION ALL
    SELECT 'variety',
           CAST(id_good_variety AS STRING),
           CAST(code AS STRING)
    FROM ext_mal_psql_maite_vision_board_prd.public.goods_varieties
    WHERE deleted = false

    UNION ALL
    SELECT 'production_type',
           CAST(id_parameter_production_type AS STRING),
           CAST(code AS STRING)
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_types
    WHERE deleted = false

    -- Les catégories de notes se répartissent en 4 familles (location, event,
    -- detail, impact) portées par category_class.
    UNION ALL
    SELECT CONCAT('batch_note_', category_class),
           CAST(id_batch_note_category AS STRING),
           CAST(category_label AS STRING)
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories
    WHERE deleted = false
),

-- Les traductions réellement renseignées : une ligne vide ne compte pas.
traductions AS (
    SELECT 'specy'                       AS nomenclature,
           CAST(t.good_specy AS STRING)  AS cle,
           l.code                        AS langue
    FROM ext_mal_psql_maite_vision_board_prd.public.goods_species_translations t
    JOIN langues l ON l.id_parameter_language = t.language
    WHERE t.deleted = false AND TRIM(COALESCE(t.label, '')) <> ''

    UNION ALL
    SELECT 'variety',
           CAST(t.good_variety AS STRING),
           l.code
    FROM ext_mal_psql_maite_vision_board_prd.public.goods_varieties_translations t
    JOIN langues l ON l.id_parameter_language = t.language
    WHERE t.deleted = false AND TRIM(COALESCE(t.label, '')) <> ''

    -- La table de traduction nomme sa clé au pluriel alors que la
    -- nomenclature l'écrit au singulier : incohérence de la source.
    UNION ALL
    SELECT 'production_type',
           CAST(t.id_parameters_production_type AS STRING),
           l.code
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_type_translations t
    JOIN langues l ON l.id_parameter_language = t.language
    WHERE t.deleted = false AND TRIM(COALESCE(t.label, '')) <> ''

    UNION ALL
    SELECT CONCAT('batch_note_', n.category_class),
           CAST(t.batch_note_category AS STRING),
           l.code
    FROM ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories_translations t
    JOIN langues l ON l.id_parameter_language = t.language
    JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_batch_note_categories n
         ON n.id_batch_note_category = t.batch_note_category
    WHERE t.deleted = false AND TRIM(COALESCE(t.label, '')) <> ''
)

SELECT
    n.nomenclature,
    n.cle,
    n.libelle_metier,
    COUNT(DISTINCT t.langue)                                          AS nb_langues,
    ARRAY_JOIN(SORT_ARRAY(COLLECT_SET(t.langue)), ', ')               AS langues_presentes,
    ARRAY_JOIN(
        SORT_ARRAY(
            ARRAY_EXCEPT(ARRAY('FR', 'EN', 'RO', 'CZ'), COLLECT_SET(t.langue))
        ), ', ')                                                      AS langues_manquantes
FROM nomenclatures n
LEFT JOIN traductions t
       ON t.nomenclature = n.nomenclature
      AND t.cle          = n.cle
GROUP BY n.nomenclature, n.cle, n.libelle_metier
HAVING COUNT(DISTINCT t.langue) < 4
ORDER BY nb_langues, n.nomenclature, n.cle;

-- Pour ne voir que les cas les plus graves — aucune traduction dans aucune
-- langue, donc la clé technique s'affiche telle quelle à l'utilisateur —
-- remplacer la clause HAVING par :
--     HAVING COUNT(DISTINCT t.langue) = 0
