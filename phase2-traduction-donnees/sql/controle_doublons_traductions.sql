-- =====================================================================
-- Controle des doublons dans les tables de traduction
-- =====================================================================
--
-- A rejouer apres chaque alimentation des traductions, avant de brancher
-- ou de rebrancher des visuels Power BI.
--
-- Deux sortes de doublons, aux effets differents.
--
-- CAS 1 — plusieurs lignes pour une meme cle dans une meme langue
--   Effet : le RLS ne reduit plus a une ligne unique. L'entite apparait
--   en double dans les slicers, et les mesures TREATAS + MIN retiennent
--   arbitrairement le libelle le plus petit alphabetiquement.
--   Normalement impossible : build_translation_dim deduplique deja par
--   (cle, langue) en gardant la ligne la plus recente. Ce controle verifie
--   que cette garantie tient.
--
-- CAS 2 — un meme libelle porte par plusieurs cles, dans une meme langue
--   Effet : les slicers fusionnent les entites en une seule entree, et la
--   selectionner filtre toutes les cles concernees. Pas necessairement
--   une erreur : deux codes distincts peuvent legitimement partager un
--   nom commercial. A arbitrer avec le metier si le cas se presente.
--
-- Environnement : preprd. Adapter le catalogue pour prd.
--
-- Etat au 14/09/2026 : les deux controles renvoient zero ligne.
-- =====================================================================


-- ---------------------------------------------------------------------
-- CAS 1 — ne doit renvoyer aucune ligne
-- ---------------------------------------------------------------------

SELECT 'variety' AS nomenclature, id_good_variety AS cle, language, count(*) AS nb
FROM mal_maite_bi_preprd.common.dim_trad_variety
GROUP BY id_good_variety, language HAVING count(*) > 1

UNION ALL

SELECT 'specy', id_good_specy, language, count(*)
FROM mal_maite_bi_preprd.common.dim_trad_specy
GROUP BY id_good_specy, language HAVING count(*) > 1

UNION ALL

SELECT 'production_type', id_parameter_production_type, language, count(*)
FROM mal_maite_bi_preprd.common.dim_trad_production_type
GROUP BY id_parameter_production_type, language HAVING count(*) > 1;


-- ---------------------------------------------------------------------
-- CAS 2 — informatif : libelles partages entre plusieurs cles
-- ---------------------------------------------------------------------

SELECT 'variety' AS nomenclature, language, label,
       count(DISTINCT id_good_variety) AS nb_cles,
       collect_set(id_good_variety)    AS cles
FROM mal_maite_bi_preprd.common.dim_trad_variety
GROUP BY language, label HAVING count(DISTINCT id_good_variety) > 1

UNION ALL

SELECT 'specy', language, label,
       count(DISTINCT id_good_specy), collect_set(id_good_specy)
FROM mal_maite_bi_preprd.common.dim_trad_specy
GROUP BY language, label HAVING count(DISTINCT id_good_specy) > 1

UNION ALL

SELECT 'production_type', language, label,
       count(DISTINCT id_parameter_production_type),
       collect_set(id_parameter_production_type)
FROM mal_maite_bi_preprd.common.dim_trad_production_type
GROUP BY language, label HAVING count(DISTINCT id_parameter_production_type) > 1

ORDER BY nomenclature, nb_cles DESC;
