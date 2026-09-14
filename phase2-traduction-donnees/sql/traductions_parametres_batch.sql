-- =====================================================================
-- Les libelles de parametres de l'onglet BATCH sont-ils traduits ?
-- =====================================================================
--
-- CONTEXTE
--
-- La matrice de l'onglet BATCH du rapport Self Service affiche en colonnes
-- les valeurs de fact_batch_report.parameter : Malt Weight, Friability,
-- Color EBC, etc.
--
-- Ces libelles sont aujourd'hui resolus dans import_self_service avec
-- `pvt.language = 2` ecrit en dur, a cinq endroits : ils sont donc figes
-- en anglais, quelle que soit la langue de l'utilisateur.
--
-- Avant de decider comment les traduire, il faut savoir ce qui existe
-- deja en base. C'est l'objet de ce fichier.
--
-- Les parametres proviennent de deux referentiels distincts :
--   parameters_variables    + parameters_variables_translations
--   parameters_evaluations  + parameters_evaluations_translations
--
-- Perimetre du projet : FR, EN, RO, CZ (codes de parameters_languages).
--
-- Adapter <source> au schema PostgreSQL interroge.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. SYNTHESE — combien de parametres traduits dans combien de langues
-- ---------------------------------------------------------------------

WITH langues AS (
    SELECT id_parameter_language, code
    FROM <source>.parameters_languages
    WHERE deleted = false AND code IN ('FR','EN','RO','CZ')
),
variables AS (
    SELECT 'variable' AS referentiel, pv.id_parameter_variable AS id, pv.code
    FROM <source>.parameters_variables pv
    WHERE pv.deleted = false
),
trad_variables AS (
    SELECT pvt.parameter_variable AS id, l.code AS langue
    FROM <source>.parameters_variables_translations pvt
    JOIN langues l ON l.id_parameter_language = pvt.language
    WHERE pvt.deleted = false
      AND pvt.label IS NOT NULL AND trim(pvt.label) <> ''
)
SELECT
    count(DISTINCT v.id)                                              AS nb_parametres,
    count(DISTINCT CASE WHEN t.langue = 'FR' THEN v.id END)           AS traduits_fr,
    count(DISTINCT CASE WHEN t.langue = 'EN' THEN v.id END)           AS traduits_en,
    count(DISTINCT CASE WHEN t.langue = 'RO' THEN v.id END)           AS traduits_ro,
    count(DISTINCT CASE WHEN t.langue = 'CZ' THEN v.id END)           AS traduits_cz
FROM variables v
LEFT JOIN trad_variables t ON t.id = v.id;


-- ---------------------------------------------------------------------
-- 2. LE DETAIL — une ligne par parametre, les langues manquantes
--
--    C'est la liste a transmettre : chaque ligne dit exactement ce qui
--    manque et pour quelle langue.
-- ---------------------------------------------------------------------

WITH langues AS (
    SELECT id_parameter_language, code
    FROM <source>.parameters_languages
    WHERE deleted = false AND code IN ('FR','EN','RO','CZ')
),
trad AS (
    SELECT pvt.parameter_variable AS id, l.code AS langue, pvt.label
    FROM <source>.parameters_variables_translations pvt
    JOIN langues l ON l.id_parameter_language = pvt.language
    WHERE pvt.deleted = false
      AND pvt.label IS NOT NULL AND trim(pvt.label) <> ''
)
SELECT
    pv.code                                                    AS code_parametre,
    max(CASE WHEN t.langue = 'EN' THEN t.label END)            AS libelle_anglais,
    concat_ws(', ', sort_array(collect_set(t.langue)))         AS langues_presentes,
    concat_ws(', ', sort_array(array_except(
        array('FR','EN','RO','CZ'), collect_set(t.langue))))   AS langues_manquantes
FROM <source>.parameters_variables pv
LEFT JOIN trad t ON t.id = pv.id_parameter_variable
WHERE pv.deleted = false
GROUP BY pv.code
HAVING size(array_except(array('FR','EN','RO','CZ'), collect_set(t.langue))) > 0
ORDER BY size(array_except(array('FR','EN','RO','CZ'), collect_set(t.langue))) DESC,
         pv.code;


-- ---------------------------------------------------------------------
-- 3. MEME CHOSE POUR LES PARAMETRES D'EVALUATION
--
--    Le notebook utilise aussi parameters_evaluations pour resoudre
--    certains libelles (cellule 25). Meme controle.
-- ---------------------------------------------------------------------

WITH langues AS (
    SELECT id_parameter_language, code
    FROM <source>.parameters_languages
    WHERE deleted = false AND code IN ('FR','EN','RO','CZ')
),
trad AS (
    SELECT pet.id_parameter_evaluation AS id, l.code AS langue, pet.label
    FROM <source>.parameters_evaluations_translations pet
    JOIN langues l ON l.id_parameter_language = pet.language
    WHERE pet.deleted = false
      AND pet.label IS NOT NULL AND trim(pet.label) <> ''
)
SELECT
    pe.code                                                    AS code_parametre,
    max(CASE WHEN t.langue = 'EN' THEN t.label END)            AS libelle_anglais,
    concat_ws(', ', sort_array(collect_set(t.langue)))         AS langues_presentes,
    concat_ws(', ', sort_array(array_except(
        array('FR','EN','RO','CZ'), collect_set(t.langue))))   AS langues_manquantes
FROM <source>.parameters_evaluations pe
LEFT JOIN trad t ON t.id = pe.id_parameter_evaluation
WHERE pe.deleted = false
GROUP BY pe.code
HAVING size(array_except(array('FR','EN','RO','CZ'), collect_set(t.langue))) > 0
ORDER BY size(array_except(array('FR','EN','RO','CZ'), collect_set(t.langue))) DESC,
         pe.code;


-- ---------------------------------------------------------------------
-- 4. LES INDICATEURS CALCULES — ceux qui n'existent nulle part
--
--    Trois libelles sont ecrits en dur dans import_self_service et ne
--    correspondent a aucune ligne de parameters_variables :
--
--      R2 Dry            calcule cellule 22
--      Indice qualite    calcule cellule 26
--      Moisture Malt     lit() cellule 21
--
--    Cette requete verifie qu'ils sont bien absents des referentiels.
--    Si elle ne renvoie rien, ils n'existent pas en base : leur
--    traduction devra etre creee, soit par le metier dans
--    parameters_variables, soit en dur dans le notebook.
-- ---------------------------------------------------------------------

SELECT 'parameters_variables' AS referentiel, code
FROM <source>.parameters_variables
WHERE deleted = false
  AND (lower(code) LIKE '%r2%dry%' OR lower(code) LIKE '%quality%index%'
       OR lower(code) LIKE '%indice%' OR lower(code) LIKE '%moisture%malt%')

UNION ALL

SELECT 'parameters_evaluations', code
FROM <source>.parameters_evaluations
WHERE deleted = false
  AND (lower(code) LIKE '%r2%dry%' OR lower(code) LIKE '%quality%index%'
       OR lower(code) LIKE '%indice%' OR lower(code) LIKE '%moisture%malt%');
