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
