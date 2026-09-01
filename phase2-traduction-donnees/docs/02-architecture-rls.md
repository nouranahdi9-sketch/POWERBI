# Phase 2 — Architecture proposée

## Principe

Le RLS filtre **à l'exécution de la requête**, contrairement aux colonnes
calculées DAX qui sont figées au rafraîchissement. C'est précisément ce qui
permet à deux utilisateurs de langues différentes de voir des libellés
différents sur le même modèle publié. La chaîne :

```
identité de l'embed  →  rôle RLS  →  filtre sur dim_language
                                        ↓ (relation 1→*)
                              chaque table de traduction ne
                              conserve qu'une ligne par clé
                                        ↓
                              le visuel affiche trad[label]
```

## Étape 1 — Compléter les traductions dans Databricks (indispensable)

Le fallback du PO (langue → anglais → clé, jamais de null) ne peut pas être fait
par le RLS. On construit donc, pour chaque table de traduction, une table
**complète et dense** : exactement une ligne par (clé × langue supportée).

```python
# Patron générique, à appliquer aux 8 tables
def build_translation_dim(df_trad, key_cols, languages_df, lang_en=2):
    actives = df_trad.filter(F.col("deleted") == False)
    keys    = actives.select(*key_cols).distinct()

    # produit cartésien clés × langues : garantit une ligne pour chaque combinaison
    grid = keys.crossJoin(languages_df.select("language"))

    en = (actives.filter(F.col("language") == lang_en)
                 .select(*key_cols, F.col("label").alias("label_en")))

    return (grid.alias("g")
        .join(actives.alias("t"), key_cols + ["language"], "left")
        .join(en.alias("e"), key_cols, "left")
        .withColumn("label",
            F.coalesce(F.col("t.label"),          # 1. la langue demandée
                       F.col("e.label_en"),        # 2. repli anglais
                       F.concat_ws("_", *[F.col(c).cast("string") for c in key_cols])))  # 3. la clé
        .select(*key_cols, "language", "label"))
```

Bénéfices, au-delà du fallback :
- le couple (clé, langue) est **unique et toujours présent** → après filtrage RLS
  il reste exactement une ligne par clé, donc pas de duplication de lignes ni de
  valeurs manquantes dans les visuels ;
- les libellés vides disparaissent des slicers, ce que le PO demande explicitement.

Pour `parameters_batch_note_categories_translations`, on éclate en plus le
préfixe pour obtenir une table par usage, ou une colonne `category_type`
(`location` / `event` / `detail` / `impact`) dérivée de `batch_note_category` :

```python
F.split(F.col("batch_note_category"), "_", 2).getItem(0).alias("category_type")
```

## Étape 2 — Faire remonter les clés dans les tables du modèle

Modifications à faire dans `transform_data.ipynb` (`batches_info`), **en ajout**
des colonnes existantes pour ne rien casser :

```python
F.col("c.id_good_variety"),                    # pour goods_varieties_translations
F.col("d.id_good_specy"),                      # pour goods_species_translations
F.col("h.id_parameter_production_type"),       # pour parameters_production_type_translations
```

Et dans `fact_batch_note.ipynb`, construire les clés préfixées :

```python
.withColumn("key_location", F.concat(F.lit("location_"), F.col("location")))
.withColumn("key_event",    F.concat(F.lit("event_"),    F.col("event")))
.withColumn("key_detail",   F.concat(F.lit("detail_"),   F.col("detail")))
.withColumn("key_impact",   F.concat(F.lit("impact_"),   F.col("impact")))
```
(à valider d'abord : les colonnes source portent-elles déjà le préfixe ?)

Ces clés doivent également être propagées à `dim_batches_specifications` et à
`fact_process_time_analyses` là où les libellés sont utilisés dans les visuels.

## Étape 3 — Le modèle Power BI

### `dim_language`
Une petite table de référence, **une seule ligne par langue** :

| `language` (int) | `code` | `label` |
|---|---|---|
| 1 | fr | Français |
| 2 | en | English |
| 5 | ro | Română |
| 6 | cs | Čeština |

(à compléter avec le référentiel officiel du front — il manque au dossier).

### Relations
- `dim_language[language]` **1 → \*** chaque table de traduction `[language]`,
  direction simple. Le RLS n'a alors besoin d'être écrit **qu'une seule fois**,
  sur `dim_language` : il se propage automatiquement à toutes les tables de
  traduction. C'est le point clé pour la maintenabilité — ajouter une table de
  traduction ne demande pas de toucher aux rôles.
- Chaque table de traduction `[clé]` **\* → 1** la dimension/le fait porteur de
  la clé, avec **cross-filter dans les deux sens** (`Both`) et l'option
  **« Appliquer le filtre de sécurité dans les deux directions »** activée sur la
  relation. Sans cela le libellé placé sur un axe ne filtrerait pas les faits.

> Variante à considérer si les performances se dégradent : remplacer la relation
> bidirectionnelle par une relation **plusieurs-à-plusieurs** de la table de
> traduction vers la table porteuse, filtre à sens unique (traduction → fait).
> Elle évite le filtrage de sécurité bidirectionnel, souvent coûteux. À arbitrer
> par mesure sur le vrai volume, pas a priori.

### Rôle RLS
Un seul rôle, dynamique, sur `dim_language` :

```dax
[code] = USERPRINCIPALNAME()
```

Le front passe le code langue (`"fr"`, `"en"`…) comme identité effective dans le
jeton d'embed. Avantage : **un seul rôle pour toutes les langues**, ajouter une
langue = ajouter une ligne dans `dim_language`, aucune republication du modèle.

Alternative : un rôle statique par langue (`FR`, `EN`, …) avec le filtre
`[language] = 1`, le front passant le nom du rôle. Plus lisible dans le service,
mais N rôles à maintenir manuellement.

### Usage dans les visuels
Les visuels et slicers pointent la colonne `label` de la table de traduction, et
non plus `variety_name` / `specy_name` / `production_type`. Les colonnes
d'origine restent dans le modèle (masquées) : elles servent de clé de tri
(`Trier par colonne`) pour que l'ordre reste stable d'une langue à l'autre.

## Étape 4 — Recette

- [ ] Un utilisateur par langue via **« Afficher comme »** dans le service.
- [ ] Vérifier qu'aucun visuel ne duplique de ligne (symptôme d'une clé non
      unique après filtrage RLS).
- [ ] Vérifier une clé volontairement non traduite → doit afficher l'anglais.
- [ ] Vérifier une clé absente partout → doit afficher la clé, jamais un vide.
- [ ] Vérifier que les totaux et les tris restent cohérents entre langues.
- [ ] Vérifier la cohabitation avec les traductions statiques de la phase 1
      (Tabular Editor) : la langue du rapport et la langue des données doivent
      être pilotées par la même valeur côté embed.

## Points ouverts

1. **Comment le front transmet-il la langue ?** (identité effective de l'embed,
   rôle statique, ou autre) — c'est le choix qui conditionne l'étape 3.
2. **Référentiel des langues** : le mapping `language` (int) ↔ code ISO n'est
   dans aucun des documents fournis.
3. **`Parameter`** : quel discriminant permet de savoir s'il faut lire
   `parameters_variables_translations` ou
   `parameters_production_line_variables_translations` ?
4. **`old_note_category`** : colonne de reprise, ou clé alternative à gérer ?
5. **`Month`** et **`Workshop`** : hors périmètre RLS, à arbitrer avec le PO.
