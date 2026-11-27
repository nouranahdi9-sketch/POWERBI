# Évolution TRS : ce qu'il reste à faire

## Traduction

| # | Quoi | Où | Statut |
|---|---|---|---|
| 1 | Ajouter la clé **TITLE_SYNTHESE** (titre de l'onglet Synthèse) pour les 4 langues | Table Databricks `common.translation`, ReportCode = `ProcessTimeAnalyses` | À faire |
| 2 | Vérifier que la légende des graphes Synthèse s'affiche traduite (Durée / Objectif métier) | Rapport publié (les libellés traduits ne s'affichent pas dans Desktop) | À vérifier après publication |

Textes proposés pour TITLE_SYNTHESE (à valider) :

| LanguageCode | TranslationText |
|---|---|
| fr-FR | Temps de process par batch |
| en-US | Process times per batch |
| ro-RO | Timpi de proces pe lot |
| cs-CZ | Procesní časy podle hromady |

Tant que la clé n'existe pas, le titre s'affiche en anglais (« Process times per batch »).

Clés de l'onglet Synthèse macro (même table, même ReportCode), textes proposés à valider :

| TranslationKey | fr-FR | en-US | ro-RO | cs-CZ |
|---|---|---|---|---|
| TITLE_SYNTHESE_MACRO | Revue hebdomadaire de la ligne de production | Weekly production line review | Analiza săptămânală a liniei de producție | Týdenní přehled výrobní linky |
| TITLE1_SYNTHESE_MACRO | Temps perdu | Lost time | Timp pierdut | Ztracený čas |
| TITLE2_SYNTHESE_MACRO | Notes production temps perdu - Top 10 | Production notes lost time - Top 10 | Note de producție timp pierdut - Top 10 | Výrobní poznámky ztracený čas - Top 10 |

| # | Quoi | Où | Statut |
|---|---|---|---|
| 5 | Ajouter la clé **TEXTE_CHOISIR_MESURE** (message des cartes de l'onglet Measures quand plusieurs mesures sont sélectionnées). Textes proposés : fr-FR « Choisir une mesure pour afficher les indicateurs », en-US « Select a measure to display the indicators », ro-RO « Alegeți o măsură pentru a afișa indicatorii », cs-CZ « Vyberte měření pro zobrazení ukazatelů » | Table `common.translation`, ReportCode = `ProcessTimeAnalyses` | À faire |
| 3 | Les boutons Localisation / Impact / Événement / Détail (onglet Synthèse macro) sont écrits en français dans toutes les langues | Table `Niveau notes` du modèle | À décider |
| 4 | Dans Desktop, en « Afficher en tant que : Translation », les libellés s'affichent dans les 4 langues à la fois (ex. tableau des temps de cycle, Top 10 des notes). Déjà le cas sur l'onglet Cycle time de la version de test | Rôle `Translation` (filtre sur USERCULTURE) | À vérifier, dans le service et dans le rôle |

## Autres points

| # | Quoi | Statut |
|---|---|---|
| 1 | Fixer les valeurs de départ des 4 listes de l'onglet Synthèse (Déchargement touraille, Transfert vers germoir, Transfert vers touraille, Temps de cycle touraille) | À faire en fin de développement |
| 2 | Supprimer les onglets Cycle time, Transfer time et Waiting time (masqués pour l'instant) | Après validation de l'onglet Synthèse |
| 3 | Supprimer l'onglet Batch-cycle (masqué, fusionné dans Measures) | Après validation de l'onglet Measures |
| 4 | Bouton « Détail » sélectionné par défaut sur Synthèse macro (aujourd'hui Localisation) | Avec les valeurs de départ |
| 5 | Supprimer les onglets Pareto et Pareto - events & details (masqués, fusionnés dans Production notes et Synthèse macro) | Après validation de l'onglet Production notes |

## Mise en production (MEP)

| # | Quoi | Statut |
|---|---|---|
| 1 | Notebooks : la preprod (version traduite) n'a peut-être pas le correctif PROD du 14/10/2026 dans `transform_data` (`manual_entries_dedup` : une seule saisie de poids par batch). À fusionner avant la MEP, sans perdre `measure_key` ni les codes en anglais de la preprod | À faire à la MEP |
| 2 | Correctif `manual_entries_dedup` : il trie sur `id_manual_entry`. Si c'est un UUID, le plus grand n'est pas forcément le plus récent ; trier plutôt sur une date de saisie (`created_at`) si elle existe | À vérifier |
| 3 | Preprod : supprimer la ligne en double du batch 3298 dans `dim_batches_specifications` (`batch_id = 'bbbd9bb3-2ea5-4822-97e3-ca583296351b'`, ligne avec `updated_at` vide), sinon l'actualisation Power BI échoue | À faire |

## Multi-impact

| # | Quoi | Statut |
|---|---|---|
| 1 | Databricks preprod : colonnes `impacts` et `key_impacts` ajoutées à `process_time_analyses.fact_batch_note` (ALTER TABLE), notebook `fact_batch_note` mis à jour (`notebooks_TRAD/`) | Fait |
| 2 | Power BI : multi-impact basé uniquement sur `key_impacts` (table de liaison `fact_batch_note_impact`) ; colonnes `impact` et `key_impact` retirées du modèle | Fait, à tester |
| 3 | Décommissionnement de la colonne `impact` à la source : retirer `"impact"` et la ligne `key_impact` du notebook `fact_batch_note`, sinon il plantera | Le jour du décommissionnement |
| 4 | Les notes sans `impacts` (si l'ancienne colonne n'a pas été reprise) n'ont plus d'impact dans le rapport. Vérifier : `SELECT COUNT(*) FROM ext_mal_psql_maite_vision_board_test.public.batches_notes WHERE deleted = false AND impact IS NOT NULL AND (impacts IS NULL OR impacts = '')` | À vérifier |
| 5 | MEP : `ALTER TABLE ... ADD COLUMNS (impacts STRING, key_impacts STRING)` sur `mal_maite_bi_prd.process_time_analyses.fact_batch_note` avant le premier lancement du notebook | À faire à la MEP |

## Clés de traduction (table common.translation)

| # | Quoi | Statut |
|---|---|---|
| 1 | Script `sql/traductions_evolution_TRS.sql` : TITLE_SYNTHESE, TITLE_SYNTHESE_MACRO, TITLE1_SYNTHESE_MACRO, TITLE2_SYNTHESE_MACRO, TEXTE_CHOISIR_MESURE (4 langues) | Fait en preprod (20 lignes, le 26/11) |
| 2 | Même script en PROD (`mal_maite_bi_prd`) | À faire à la MEP |

## Clés des temps de cycle (registre trs_metadata)

| # | Quoi | Statut |
|---|---|---|
| 1 | Les temps de cycle ont changé de clé dans les données : `duree_temps_cycle_trempe/germination/touraille` → `steep_cycle_duration`, `germ_cycle_duration`, `kiln_cycle_duration`. Tant que le job des traductions n'est pas relancé, ils n'ont plus de libellé et les visuels par mesure sont vides (tableau et liste des cycles de Synthèse macro, Cycle time) | Corrigé en preprod le 26/11 (job `main_translations` relancé) |
| 2 | MEP : relancer le job `main_translations` en PROD après la mise à jour du registre `trs_nomenclature` / `trs_translation`, avant d'actualiser le rapport | À faire à la MEP |

## Tests de non-régression DAX (`dax/tests_non_regression.dax`), le 27/11 en preprod

| Test | Résultat |
|---|---|
| 1. Graphes de Synthèse vs ancien calcul (93 299 couples batch x mesure) | OK, aucun écart |
| 2. Temps perdu (racine de l'arbre, carte) et unicité des notes | OK (6 233,93 h ; 2 780 notes, aucune en double) |
| 3. Filtre Impact, par impact | OK (notes trouvées = lignes de liaison pour chaque impact) |
| 4. Notes à plusieurs impacts | OK (2 notes de test, tous leurs impacts listés) |
| 5. Cartes de Measures vs anciennes cartes | OK pour les 74 mesures ; seul écart sur la ligne vide (8 lignes aux anciennes clés duree_temps_cycle_*, sans mesure correspondante) |
| 6. Tableau des temps de cycle | OK (trempe 25:20, germination 25:51, touraille 26:28, dans les 4 langues) |

Reste : vérifications visuelles de `Liste_verification_evolution_TRS.docx`, puis suppression des onglets masqués.
