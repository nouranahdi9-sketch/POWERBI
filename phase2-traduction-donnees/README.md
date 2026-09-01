# Phase 2 — Traduction des données (approche RLS)

Contexte : la phase 1 (traduction des éléments statiques : noms de colonnes, titres,
slicers…) a été réalisée via Tabular Editor + les Translation/Expression editors.
Cette phase 2 traite la traduction des **données** (valeurs des lignes), en
s'appuyant sur les tables de traduction fournies par l'équipe front et sur un
filtrage par RLS (Row-Level Security).

## Où déposer quoi

| Dossier | Contenu attendu |
|---|---|
| `notebooks/` | Les notebooks (`.ipynb` / `.py` / `.sql`) qui alimentent les tables du modèle |
| `powerbi/` | Le `.pbix` concerné (ou l'export `.Report` / `.SemanticModel` PBIP, `model.bim`, TMDL) |
| `specifications-po/` | Le contenu édité par le PO : noms et structure des tables de traduction |
| `dax-rls/` | Les rôles RLS, mesures et expressions DAX produits pendant cette phase |
| `docs/` | Notes de conception, schéma du modèle, décisions d'architecture |

## Principe visé

1. Les tables de traduction contiennent une ligne par (clé métier, langue, libellé).
2. Une table `Langue` (déconnectée ou filtrante) porte la langue courante.
3. Un rôle RLS filtre les tables de traduction sur `[Langue] = <langue de l'utilisateur>`,
   de sorte qu'une seule variante linguistique de chaque libellé reste visible.
4. Les visuels affichent la colonne de libellé traduit à la place du libellé source.

## Points à trancher (à compléter au fur et à mesure)

- [ ] Détermination de la langue : mapping utilisateur (`USERPRINCIPALNAME()`) ou sélection par slicer ?
- [ ] Granularité des tables de traduction : une table par dimension, ou une table pivot unique ?
- [ ] Impact sur les relations : traduction portée par la dimension elle-même ou par une table satellite ?
- [ ] Comportement des totaux et des tris (colonne "Trier par" en langue source).
- [ ] Cohabitation avec les traductions statiques de la phase 1.
