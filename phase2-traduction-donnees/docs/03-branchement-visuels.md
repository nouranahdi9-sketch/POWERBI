# Branchement des libellés traduits — checklist par onglet

Établi à partir du contenu réel du rapport (`Process Time Analyses.Report`).
**23 visuels** à modifier : 20 par simple remplacement de colonne, 3 tableaux
détail par mesure.

Garder le rôle `Translation` actif pendant tout le branchement
(*Affichage du rapport → Afficher comme*), sinon chaque slicer affiche les
4 langues empilées.

## Correspondances

| Colonne actuelle | Remplacer par |
|---|---|
| `dim_batches_specifications[specy_name]` | `dim_trad_specy[label]` |
| `dim_batches_specifications[variety_name]` | `dim_trad_variety[label]` |
| `dim_batches_specifications[production_type]` | `dim_trad_production_type[label]` |
| `fact_batch_note[location]` | `dim_trad_batch_note_location[label]` |
| `fact_batch_note[event]` | `dim_trad_batch_note_event[label]` |
| `fact_batch_note[detail]` | `dim_trad_batch_note_detail[label]` |
| `fact_batch_note[impact]` | `dim_trad_batch_note_impact[label]` |

Dans les **tableaux détail** uniquement, on ne met pas la colonne `label` mais la
mesure : `Espèce`, `Variété`, `Type de production`, `Emplacement`, `Événement`,
`Détail`, `Impact`.

---

## Cycle time — 2 slicers

- [ ] Slicer en haut à droite (x≈781) : `variety_name` → `dim_trad_variety[label]`
- [ ] Slicer à sa droite (x≈947) : `specy_name` → `dim_trad_specy[label]`

## Transfer time — 2 slicers

- [ ] Slicer x≈781 : `variety_name` → `dim_trad_variety[label]`
- [ ] Slicer x≈947 : `specy_name` → `dim_trad_specy[label]`

## Waiting time — 2 slicers

- [ ] Slicer x≈781 : `variety_name` → `dim_trad_variety[label]`
- [ ] Slicer x≈947 : `specy_name` → `dim_trad_specy[label]`

## Measures (all batches) — 3 slicers + 1 tableau

- [ ] Slicer x≈445 : `production_type` → `dim_trad_production_type[label]`
- [ ] Slicer x≈609 : `specy_name` → `dim_trad_specy[label]`
- [ ] Slicer x≈768 : `variety_name` → `dim_trad_variety[label]`
- [ ] **Tableau** (y≈236) : retirer `production_type`, `specy_name`,
      `variety_name` et ajouter les mesures `Type de production`, `Espèce`,
      `Variété`

## Production notes — 4 slicers + 1 tableau

- [ ] Slicer x≈306 : `location` → `dim_trad_batch_note_location[label]`
- [ ] Slicer x≈548 : `event` → `dim_trad_batch_note_event[label]`
- [ ] Slicer x≈783 : `detail` → `dim_trad_batch_note_detail[label]`
- [ ] Slicer x≈1025 : `impact` → `dim_trad_batch_note_impact[label]`
- [ ] **Tableau** (y≈203) : retirer `location`, `event`, `detail`, `impact` et
      ajouter les mesures `Emplacement`, `Événement`, `Détail`, `Impact`

## Overview - last hours — 1 tableau

- [ ] **Tableau** (y≈435) : retirer `location`, `event`, `detail`, `impact` et
      ajouter les mesures `Emplacement`, `Événement`, `Détail`, `Impact`

## Pareto — 2 slicers + 1 arbre

- [ ] Slicer x≈823 : `impact` → `dim_trad_batch_note_impact[label]`
- [ ] Slicer x≈1058 : `event` → `dim_trad_batch_note_event[label]`
- [ ] **Arbre de décomposition** (y≈125) : remplacer les trois niveaux
      `location`, `event`, `detail` par les colonnes `label` correspondantes

## Pareto - events & details — 2 histogrammes

- [ ] Histogramme de gauche (x≈0) : `event` → `dim_trad_batch_note_event[label]`
- [ ] Histogramme de droite (x≈687) : `event` et `detail` → colonnes `label`

## Pareto - zoom location — 1 courbe + 1 tableau

- [ ] **Courbe** (x≈0) : `location` → `dim_trad_batch_note_location[label]`
- [ ] **Tableau** (x≈737) : `location` → `dim_trad_batch_note_location[label]`
      — remplacement direct, ce tableau ne contient qu'une agrégation, pas de
      colonnes de fait brutes

---

## Point d'attention — les filtres figés

Certains visuels portent un **filtre au niveau du visuel ou de la page** sur les
mêmes colonnes, invisible tant qu'on n'ouvre pas le volet Filtres. Remplacer le
champ affiché sans reprendre le filtre laisse un montage incohérent.

Cas rencontré, page **Pareto**, slicer `event` (x≈1058) : un filtre
`fact_batch_note[event] est event_panne` restreignait le slicer à la seule
catégorie « panne ». Une fois le champ basculé sur
`dim_trad_batch_note_event[label]`, ce filtre ne joue plus son rôle — il filtre
les lignes de faits, ce qui ne restreint pas la liste d'une dimension, la
propagation n'allant pas dans ce sens. Le slicer proposait alors toutes les
catégories.

**Règle** : un filtre figé doit porter sur la **clé**, jamais sur le libellé.

- à supprimer : `fact_batch_note[event] est event_panne`
- à créer : `dim_trad_batch_note_event[batch_note_category] est event_panne`

Filtrer sur `label` figerait une valeur traduite : « Panne » en français
donnerait un slicer vide en tchèque et en roumain.

## Point d'attention — la table `dim_batch_note`

Les visuels de **Pareto - events & details** et **Pareto - zoom location**
référencent une table `dim_batch_note` (au singulier), distincte des quatre
nomenclatures `dim_batch_note_location` / `_event` / `_detail` / `_impact`
construites en phase 2. C'est une table héritée. À examiner avant de toucher à
ces visuels : si elle fait doublon, son retrait est un nettoyage à mener à part.

## Après le branchement

- [ ] Masquer dans le modèle les colonnes techniques des tables `dim_trad_*` :
      `language`, `label_source`, `created_at` et les clés
- [ ] Remettre la règle du rôle en production :
      `VAR __culture = LOWER ( LEFT ( USERCULTURE (), 2 ) )`
- [ ] Confirmer avec le front que le jeton d'embed passe bien
      `roles: ["Translation"]` dans l'identité effective
