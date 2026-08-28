# Optimisation du modèle sémantique Power BI

Branche de travail : audit du modèle et du rapport avant toute réduction
du périmètre de données, dans le but de réduire le temps de refresh.

## Ce qui doit être déposé ici

- `*.SemanticModel/` et `*.Report/` : export **PBIP / TMDL** depuis Power BI
  Desktop (Fichier > Enregistrer sous > Projet Power BI). Format texte,
  diffable, lisible.
- `*.pbip` : fichier point d'entrée du projet.
- `.gitignore` : celui généré par Power BI Desktop (exclut `.pbi/cache.abf`
  et `localSettings.json`).
- `*.vpax` : export VertiPaq Analyzer depuis DAX Studio
  (Advanced > Export Metrics). Donne la taille et la cardinalité par colonne.

## Ce qui ne doit pas y être déposé

Les fichiers `.pbix` : leur modèle (`DataModel`) est compressé en XPress9,
donc ni diffable ni lisible. Les 6 `.pbix` initialement présents ont été
retirés de cette branche.
