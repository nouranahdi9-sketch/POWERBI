# Inventaire des champs traduisibles — les deux rapports

**Méthode** : extraction de tous les champs réellement projetés par les objets
visuels des deux rapports, puis tri entre ce qui est traduisible et ce qui ne
l'est pas, et rapprochement avec les tables `*_translations` disponibles en base.

**Pourquoi ce document** : jusqu'ici les manques ont été découverts un par un, au
fil de la navigation. Celui-ci fait le tour une bonne fois.

Les champs numériques, les dates et les mesures DAX sont exclus : ils n'ont pas
de libellé à traduire.

---

## Dashboard Self Service

92 champs affichés au total. 12 portent du texte destiné à l'utilisateur.

| champ | onglets | source du libellé | état |
|---|---|---|---|
| `dim_trad_specy[label]` | 6 + Page 1 | `goods_species_translations` | **fait** |
| `dim_trad_variety[label]` | 6 + Page 1 | `goods_varieties_translations` | **fait** |
| `dim_trad_production_type[label]` | 6 | `parameters_production_type_translations` | **fait** |
| `batch_report[parameter]` | BATCH | `parameters_variables_translations` | **zone 2** — figé sur `language = 2` |
| `fact_measurement[label]` | MEASUREMENT | `parameters_variables_translations` | **zone 2** — même origine, même blocage |
| `phase[prd_workshop]` | VESSEL | `processes_phases_translations` | **non traité** — codes anglais affichés |
| `manual_entries[parameter_variable]` | PROD (masqué) | `parameters_variables_translations` | zone 2, onglet masqué |
| `parameters_variables[code]` | ENERGY | le code technique lui-même | **non traité** — voir ci-dessous |
| `localisation[Attribut]` | LOCATION | `gold.localizations_pivot`, dépivoté | à qualifier |
| `localisation[Valeur]` | LOCATION | idem | à qualifier |
| `fact_measurement[status]` | MEASUREMENT | énumération (`OK`, `IN_ERROR`) | pas de source connue |
| `dim_specification[cdc]` | 6 | `requirement_specifications` | **pas de table de traduction en base** |

Sans objet pour la traduction : `dim_site[plant]` (noms de sites, noms propres),
`fact_weather[*]` (mesures et dates), `malt_quality_results[*]` et
`goods_quality_results[*]` (indicateurs numériques), `fact_measurement[measure_name]`
(code technique, doublé par `label`).

### Les trois manques à traiter

**1. `phase[prd_workshop]` — le plus simple**

Affiche `steeping`, `pregermination`, `germination`, `kilning` : des codes
techniques anglais, vus tels quels par tous les utilisateurs. Neuf valeurs au
total dans `processes_phases`.

La source existe : `processes_phases_translations`, renseignée dans les quatre
langues. Reste à établir la clé de jointure — `gold.phases.prd_workshop` porte
`kilning`, la table de traduction affiche `Killning`. Il faut vérifier si
`processes_phases` expose un code technique sur lequel joindre.

**2. `parameters_variables[code]` sur ENERGY**

Le tableau de l'onglet ENERGY affiche le **code technique** du paramètre, pas son
libellé. Deux corrections possibles, indépendantes de la traduction :
remplacer par le libellé traduit une fois la zone 2 faite, ou au minimum
brancher sur un libellé plutôt que sur le code.

**3. `localisation[Attribut]` et `[Valeur]`**

Issus de la vue `gold.localizations_pivot`, dépivotée. Les noms d'attributs
viennent probablement des colonnes de la vue, donc en anglais technique.
À qualifier avant de décider : ce sont peut-être des libellés déjà lisibles.

---

## Process Time Analyses

63 champs affichés. Les libellés traduisibles se répartissent en trois familles.

### a. Nomenclatures — branchées ou en cours

| champ | source | état |
|---|---|---|
| `dim_batches_specifications[specy_name]` | `goods_species_translations` | à rebrancher sur `dim_trad_specy` |
| `dim_batches_specifications[variety_name]` | `goods_varieties_translations` | à rebrancher sur `dim_trad_variety` |
| `dim_batches_specifications[production_type]` | `parameters_production_type_translations` | à rebrancher sur `dim_trad_production_type` |

Ces trois colonnes portent encore le libellé résolu à l'alimentation. Le
dispositif de traduction existe dans le modèle ; c'est le branchement des
visuels qui reste.

### b. Notes de production — traitées par mesures TREATAS

`fact_batch_note[location]`, `[event]`, `[detail]`, `[impact]` : quatre
catégories de notes, chacune avec sa table `dim_trad_batch_note_*`. Les mesures
`Emplacement`, `Événement`, `Détail`, `Impact` existent déjà. Reste le
branchement des visuels.

### c. Mesures TRS — en attente de l'équipe `trs_metadata`

| champ | nature |
|---|---|
| `fact_process_time_analyses[label]`, `[mesure_name]` | nom de la mesure |
| `fact_process_time_analyses[measure_type]` | type de mesure |
| `fact_process_time_analyses[categorie]` | catégorie de process |
| `fact_process_time_analyses[mesure_name_color]` | nom de mesure servant au formatage conditionnel |
| `fact_process_time_analyses[label - CyTiWai]`, `[label_graphe_*]` | libellés d'axes dérivés |

Aucune table de traduction en base aujourd'hui. C'est l'objet de la demande
adressée à l'équipe `trs_metadata` (document 04).

`mesure_name_color` demande une attention particulière : il pilote le formatage
conditionnel. Vérifié — il n'apparaît jamais en axe, toujours en colonne de
tableau, donc transformable.

### d. Déjà traité

`month_name_mesure` : traduit via `dim_month` et `dim_trad_month`.

### e. Sans objet

`dim_site[plant]` (noms propres), `batch_number`, `mes_number`, les dates, les
durées `hh:mm`, `flg_outlier`, `sequence`, `error_messages` (messages techniques),
`columns_source` (nom de colonne interne).

---

## Récapitulatif

| | Self Service | Process Time Analyses |
|---|---|---|
| fait | 3 nomenclatures | mois |
| en cours | — | 3 nomenclatures + 4 catégories de notes, branchement visuels |
| zone 2 | paramètres (`batch_report`, `fact_measurement`, `manual_entries`) | — |
| non traité | phases de process, code paramètre ENERGY, localisation | mesures TRS (en attente) |
| sans source | `cdc`, `status` | — |

## Ce qui n'a pas de source et n'en aura pas

Deux champs affichent du texte sans aucune table de traduction en base :

- **`dim_specification[cdc]`** — les cahiers des charges. Confirmé : aucune table
  `requirement_specifications_translations` n'existe. Le libellé restera dans sa
  langue de saisie.
- **`fact_measurement[status]`** — `OK`, `IN_ERROR`. Énumération technique, pas de
  référentiel. Traduisible seulement en dur, si le métier le demande.
