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

## Autres points

| # | Quoi | Statut |
|---|---|---|
| 1 | Fixer les valeurs de départ des 4 listes de l'onglet Synthèse (Déchargement touraille, Transfert vers germoir, Transfert vers touraille, Temps de cycle touraille) | À faire en fin de développement |
| 2 | Supprimer les onglets Cycle time, Transfer time et Waiting time (masqués pour l'instant) | Après validation de l'onglet Synthèse |
