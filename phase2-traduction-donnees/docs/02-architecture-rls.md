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
# languages_df = dim_language (les 6 langues actives), lang_en = 2 (English)
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

Alimentée depuis `parameters_languages` (voir « `dim_language` — source réelle
et piège de codification » ci-dessous : la colonne `code` de la source ne peut
pas être rapprochée directement de `USERCULTURE()`).

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

### Rôle RLS — pilotage par `USERCULTURE()`

La langue n'est pas portée par l'identité de l'embed mais par la **culture** du
contexte de consultation, que le front pilote via les `localeSettings` de la
configuration d'embed. Un **seul rôle**, appliqué à tout le monde, avec un filtre
sur `dim_language` :

```dax
VAR __culture   = LOWER ( LEFT ( USERCULTURE (), 2 ) )
VAR __supported = NOT ISEMPTY (
                      FILTER ( ALL ( dim_language ), dim_language[code] = __culture )
                  )
RETURN
    dim_language[code] = IF ( __supported, __culture, "en" )
```

Trois choses à noter dans cette expression :

1. **`LEFT ( ... , 2 )`** — `USERCULTURE()` renvoie une culture complète
   (`fr-FR`, `en-GB`, `ro-RO`…). En ne comparant que les deux premiers
   caractères, toutes les variantes régionales d'une même langue retombent sur
   la même traduction, et le front n'a pas à normaliser ce qu'il envoie.
   Si `dim_language` doit un jour distinguer `pt-BR` de `pt-PT`, il suffira de
   comparer la culture entière.
2. **Le garde-fou `__supported`** est indispensable. Sans lui, une culture
   inconnue ne ramène aucune ligne dans `dim_language`, donc aucune ligne dans
   les tables de traduction, donc **un rapport entièrement vide**. Le repli sur
   `"en"` prolonge au niveau langue la règle de fallback que le PO a définie au
   niveau ligne.
3. **Un rôle reste nécessaire malgré tout.** En embed *app-owns-data*, le RLS
   n'est appliqué que si le jeton d'embed porte une identité effective avec un
   nom de rôle. Le front doit donc continuer à passer
   `roles: ["Translation"]` — la langue vient de la culture, mais
   l'activation du RLS vient du rôle. Sans ce rôle, aucun filtre ne s'applique
   et **toutes les langues s'affichent en même temps** (lignes dupliquées dans
   tous les visuels) : c'est le symptôme à reconnaître en recette.

### `dim_language` — source réelle et piège de codification

Le référentiel existe : **`ext_mal_psql_maite_vision_board_<env>.public.parameters_languages`**
`id_parameter_language (int) | name | code | deleted | created_at | updated_at | deleted_at`

| `id_parameter_language` | `name` | `code` | culture attendue de `USERCULTURE()` | `LEFT(culture,2)` |
|---|---|---|---|---|
| 1 | Français | `FR` | `fr-FR` | `fr` ✅ |
| 2 | English | `EN` | `en-GB` / `en-US` | `en` ✅ |
| 3 | Polski | `PL` | `pl-PL` | `pl` ✅ |
| 4 | українська | `UA` | `uk-UA` | **`uk` ❌** |
| 5 | Romanian | `RO` | `ro-RO` | `ro` ✅ |
| 6 | Czech | `CZ` | `cs-CZ` | **`cs` ❌** |

> ⚠️ **Le rapprochement direct `code` ↔ `USERCULTURE()` ne fonctionne pas.**
> La colonne `code` mélange des codes **langue** ISO 639-1 (`FR`, `EN`, `PL`, `RO`)
> et des codes **pays** ISO 3166 (`UA`, `CZ`). Or `USERCULTURE()` renvoie la
> partie *langue* de la culture :
> - ukrainien → `uk-UA`, donc `uk`, alors que la table dit `UA` ;
> - tchèque → `cs-CZ`, donc `cs`, alors que la table dit `CZ`.
>
> Un `LEFT(USERCULTURE(),2) = LOWER(code)` naïf ferait donc **basculer
> silencieusement les utilisateurs ukrainiens et tchèques sur le repli anglais**,
> sans erreur ni message — le pire type de bug sur ce projet, parce qu'il donne
> un rapport qui « marche » et qui est simplement dans la mauvaise langue.

**Correctif : une colonne de rapprochement explicite**, construite dans le
notebook et jamais dérivée de `code` :

```python
# mapping code métier → code langue ISO 639-1 attendu de USERCULTURE()
culture_map = {
    "FR": "fr",
    "EN": "en",
    "PL": "pl",
    "UA": "uk",   # ukrainien : ISO 639-1 = uk, la table porte le code pays UA
    "RO": "ro",
    "CZ": "cs",   # tchèque   : ISO 639-1 = cs, la table porte le code pays CZ
}
culture_expr = F.create_map([F.lit(x) for x in sum(culture_map.items(), ())])

dim_language = (
    spark.table(f"{source_catalog}.parameters_languages")
         .filter(F.col("deleted") == False)
         .select(
             F.col("id_parameter_language").alias("language"),
             F.col("code"),
             F.col("name").alias("label"),
             culture_expr[F.col("code")].alias("culture_code"),
         )
)
```

Le rôle RLS compare alors `dim_language[culture_code]`, pas `dim_language[code]` :

```dax
VAR __culture   = LOWER ( LEFT ( USERCULTURE (), 2 ) )
VAR __supported = NOT ISEMPTY (
                      FILTER ( ALL ( dim_language ),
                               dim_language[culture_code] = __culture )
                  )
RETURN
    dim_language[culture_code] = IF ( __supported, __culture, "en" )
```

Toute nouvelle langue ajoutée par le front devra être ajoutée à `culture_map` :
c'est le seul point de maintenance manuel de l'architecture. À défaut, la
nouvelle langue tombera proprement sur le repli anglais grâce au garde-fou —
dégradé, mais pas cassé.

### Couverture réelle des traductions

Les échantillons de `goods_species_translations` ne montrent que les langues
`1`, `2`, `5` et `6`. Le polonais (`3`) et l'ukrainien (`4`) semblent **absents
d'une partie des tables de traduction**. C'est exactement ce que la
densification de l'étape 1 traite : le produit cartésien clés × langues doit se
faire sur les **6 langues de `parameters_languages`**, pas sur les langues
présentes dans chaque table de traduction. Sans cela, un utilisateur polonais
verrait des lignes disparaître de ses visuels au lieu de voir le repli anglais.

### Limites à valider en recette

- **La culture arrive bien jusqu'au rapport** : les traductions statiques de la
  phase 1 (métadonnées Tabular Editor) fonctionnent déjà en embed, ce qui prouve
  que la locale est correctement transmise par la configuration d'embed.
  Nuance à lever malgré tout : les traductions de métadonnées sont résolues par
  la **couche de rendu du rapport** à partir de la culture de l'embed, alors que
  `USERCULTURE()` est résolue par le **moteur tabulaire** à partir de la locale
  de la connexion/requête. Les deux valeurs coïncident en pratique, mais ce
  n'est pas le même chemin de code. Test de 5 minutes pour lever le doute avant
  toute industrialisation : publier une mesure `Culture debug = USERCULTURE()`
  sur une carte dans le rapport embarqué et vérifier la valeur retournée pour
  deux langues.
- **Power BI Desktop** : `USERCULTURE()` y renvoie la locale de Desktop, pas
  celle d'un utilisateur simulé. « Afficher comme » ne permet donc **pas** de
  tester les langues : il faut changer la langue du modèle/de Desktop, ou tester
  directement dans le service via un jeton d'embed. À prévoir dans le plan de
  test.
- **Cache de requêtes** : le service met en cache les résultats par identité RLS.
  Comme ici la langue ne vient pas de l'identité mais de la culture, il faut
  **vérifier explicitement** que deux consultations de cultures différentes avec
  la même identité ne se servent pas mutuellement un résultat en cache. C'est le
  risque principal de cette approche, et il se teste en quelques minutes une fois
  le premier prototype publié.
- **`USERCULTURE()` n'est pas utilisable en colonne calculée** (elle est évaluée
  au rafraîchissement, pas à la requête). Toute la traduction doit donc passer
  par le filtrage RLS et par des colonnes de table, jamais par une colonne
  calculée DAX.

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

1. ~~Comment le front transmet-il la langue ?~~ **Tranché** : `USERCULTURE()`,
   la culture étant pilotée par les `localeSettings` de l'embed. Reste à
   confirmer avec le front que le rôle `Translation` sera bien passé dans
   l'identité effective du jeton.
2. ~~Référentiel des langues~~ **Fourni** : `parameters_languages`, 6 langues.
   Attention au mapping `UA`→`uk` et `CZ`→`cs` (voir ci-dessus).
3. **`Parameter`** : quel discriminant permet de savoir s'il faut lire
   `parameters_variables_translations` ou
   `parameters_production_line_variables_translations` ?
4. **`old_note_category`** : colonne de reprise, ou clé alternative à gérer ?
5. **`Month`** et **`Workshop`** : hors périmètre RLS, à arbitrer avec le PO.
