# Phase 2 — Analyse de l'existant

Sources analysées : `Tables.docx` (27 captures Databricks Catalog Explorer),
`Document PO.docx`, et les notebooks du pipeline `process_time_analyses`.

---

## 1. Les tables de traduction

Toutes dans `ext_mal_psql_maite_vision_board_<env>.public` (le `source_catalog`
déjà utilisé par `load_data`). Elles partagent **exactement le même patron** :

`<clé métier> | language (int) | label (varchar) | deleted (bool) | created_at | updated_at | deleted_at`

| Table | Clé métier | Type |
|---|---|---|
| `goods_species_translations` | `good_specy` | int |
| `goods_varieties_translations` | `good_variety` | int |
| `parameters_production_type_translations` | `id_parameters_production_type` | int |
| `parameters_variables_translations` | `parameter_variable` | int |
| `parameters_production_line_variables_translations` | `parameter_production_line_variable` | int |
| `parameters_localizations_translations` | `id_parameter_localization` | int |
| `parameters_localization_groups_translations` | `id_parameter_localization_group` **+ `production_line`** | int + int |
| `parameters_batch_note_categories_translations` | `batch_note_category` **+ `old_note_category`** | varchar(128) + string |

### Points structurants

- **Format long** (une ligne par clé × langue) : c'est le format qui permet le RLS.
  Aucun dépivotage nécessaire.
- **`language` est un entier**, pas un code ISO. Valeurs observées dans
  `goods_species_translations` : `1` = FR (« Espèce inconnue », « Orge 6RH »),
  `2` = EN (« Unknown specy », « Barley 6RW »), `5` = RO (« Varietate necunoscută »),
  `6` = CS (« Neznámý druh »). → **il faut la table de référence des langues**
  (le mapping id ↔ code) auprès de l'équipe front ; il n'est pas dans le Word.
- **Soft delete** : `deleted` + `deleted_at`. Tout chargement doit filtrer
  `deleted = false`, comme le fait déjà le pipeline sur les autres tables.
- **Deux clés composites** à traiter à part :
  - `parameters_localization_groups_translations` : la clé est
    (`id_parameter_localization_group`, `production_line`) — une même localisation
    porte un libellé différent selon la ligne de production.
  - `parameters_batch_note_categories_translations` : la clé `batch_note_category`
    est **préfixée par le type** — valeurs observées `detail_TCR`, `detail_B`,
    `detail_defaut_niveau_haut_BOM3`, `detail_NS`… La même table sert donc pour
    `location`, `event`, `detail` et `impact` via le préfixe.
    `old_note_category` est à `null` sur tout l'échantillon (colonne de reprise ?
    à confirmer avec le front).

---

## 2. Ce que demande le PO

Le `Document PO.docx` classe chaque élément à traduire par un code couleur :

- 🟢 **Changement de config TRS** — la traduction viendra de la métadonnée TRS
  (`mal_maite_common_<env>.gold.trs_metadata`), qui doit évoluer pour porter une
  clé de langue. Concerne : `label`, `measure_description`, `CATEGORY`, `TYPE`,
  et le contenu des filtres *Measure Type* / *Measure*.
  → **hors périmètre RLS**, dépendance amont sur l'équipe TRS.
- 🟡 **Translations présentes dans la base PostgreSQL** — c'est le périmètre RLS,
  couvert par les 8 tables ci-dessus.
- ⚫ **Autre / non résolu** :
  - `Month` (noms de mois) — actuellement générés en dur dans `transform_data`
    (`mois_fr`) puis réécrits en anglais par `date_format(...,"MMMM")` dans
    `fact_process_time_analyses`. Aucune table de traduction : à traiter par une
    dimension calendrier multilingue, pas par RLS sur une table source.
  - `Workshop` (page Vessel) — **aucune table de traduction n'existe**, le PO le
    signale comme impossible en l'état.
  - Légende « Total time lost » — libellé statique, relève de la phase 1.

### Règle de fallback imposée par le PO

1. la langue demandée ;
2. sinon l'anglais ;
3. sinon la clé elle-même — **jamais de null**.

**Cette règle ne peut pas être portée par le RLS.** Le RLS ne sait que *supprimer*
des lignes, pas en substituer une autre. Le fallback doit donc être matérialisé
en amont, dans les notebooks (voir `02-architecture-rls.md`).

---

## 3. Ce que le modèle expose aujourd'hui — le point bloquant

Le pipeline actuel **ne conserve pas les clés entières** qui permettraient de
joindre les tables de traduction. Il projette directement les libellés / codes :

| Notebook | Colonne produite | Origine | Clé de traduction nécessaire |
|---|---|---|---|
| `transform_data` → `batches_info` | `specy_name` | `goods_species.code` | `id_good_specy` **absent** |
| `transform_data` → `batches_info` | `variety_name` | `goods_varieties.code` | `id_good_variety` **absent** |
| `transform_data` → `batches_info` | `production_type` | `parameters_production_types.code` | `id_parameter_production_type` **absent** |
| `transform_data` → `batches_info` | (jointure `parameters_variables` filtrée sur `code = 'goods_weight'`) | — | `id_parameter_variable` **absent** |
| `fact_batch_note` | `location`, `impact`, `event`, `detail` | `batches_notes.*` | valeurs **non préfixées** ? à vérifier |
| `fact_process_time_analyses` | `label`, `categorie`, `measure_type`, `measure_description` | `trs_metadata` | 🟢 périmètre TRS |

**Conséquence : la première tâche de la phase 2 est de modifier les notebooks pour
faire remonter les identifiants**, en gardant les colonnes actuelles (non
régressif). Sans ces clés, aucune relation vers les tables de traduction n'est
possible.

Sur `fact_batch_note` en particulier : la clé de la table de traduction est
`detail_TCR` alors que la colonne `detail` de `batches_notes` contient
vraisemblablement `TCR`. Il faudra soit construire la clé préfixée dans le
notebook (`concat('detail_', detail)`), soit confirmer avec le front que la
colonne source porte déjà le préfixe. **À vérifier sur les données.**

---

## 4. Périmètre concret par page de rapport

D'après le `Document PO.docx` :

| Page | Éléments 🟡 (RLS) | Table de traduction |
|---|---|---|
| Overview / Production notes | location, event, detail, impact | `parameters_batch_note_categories_translations` |
| Cycle Time | Variety, Species | `goods_varieties_translations`, `goods_species_translations` |
| Measures - All batches | Production Type, Specy, Variety | `parameters_production_type_translations` + les 2 ci-dessus |
| Pareto | Location / Impact / Event / Detail label | `parameters_batch_note_categories_translations` |
| Pareto - Zoom Location | Location (légende + table) | `parameters_localizations_translations`, `parameters_localization_groups_translations` |
| Self Service - Location / Batch | Variety, Species, Parameter | + `parameters_variables_translations` ou `parameters_production_line_variables_translations` |
| Self Service - Measurement | Variety, Species, Parameter, Production Type, Label | idem |
| Self Service - Vessel | Production Type, Variety, Species (⚫ Workshop impossible) | idem |
| Self Service - Weather / Energy | Parameter | `parameters_variables_translations` |

Le PO note que `Parameter` pointe **soit** `parameters_variables_translations`
**soit** `parameters_production_line_variables_translations` « selon ce qu'il
pointe » : il faudra un discriminant dans le modèle (type de paramètre) pour
choisir la bonne table — sinon les deux traductions se superposent.
