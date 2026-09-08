-- Variables de ligne de production sans aucune traduction — version exploitable
--
-- La table parameters_production_line_variables n'a pas de colonne code : sans
-- traduction, elle n'a rien à afficher, et son identifiant seul ne permet pas
-- au métier de savoir de quoi il s'agit.
--
-- Cette requête va donc chercher le contexte : la variable pointée et la ligne
-- de production concernée. Chaque ligne devient identifiable et traduisible.
--
-- Environnement : remplacer _prd par _test pour la préprod.

SELECT
    v.code                          AS `Variable`,
    p.name                          AS `Ligne de production`,
    n.id_parameter_production_line_variable AS `Identifiant technique`,
    CASE WHEN n.displayed THEN 'Oui' ELSE 'Non' END AS `Affichee dans l application`
FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables n
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.parameters_variables v
       ON v.id_parameter_variable = n.variable
LEFT JOIN ext_mal_psql_maite_vision_board_prd.public.plants_production_lines p
       ON p.id_plant_production_line = n.production_line
WHERE n.deleted = false
  AND NOT EXISTS (
      SELECT 1
      FROM ext_mal_psql_maite_vision_board_prd.public.parameters_production_line_variables_translations t
      WHERE t.parameter_production_line_variable = n.id_parameter_production_line_variable
        AND t.deleted = false
        AND TRIM(COALESCE(t.label, '')) <> ''
  )
ORDER BY 1, 2;


-- Variante : combien de variables distinctes sont réellement concernées.
-- Une même variable revient sur plusieurs lignes de production, donc le nombre
-- de libellés à écrire est bien inférieur au nombre de lignes ci-dessus.
--
-- SELECT v.code AS `Variable`, COUNT(*) AS `Nb de lignes de production`
-- FROM ... (même FROM et WHERE que ci-dessus)
-- GROUP BY 1 ORDER BY 2 DESC;
