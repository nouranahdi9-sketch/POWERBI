# Phase 2 — Architecture proposée

## Principe

Le RLS filtre **à l'exécution de la requête**, contrairement aux colonnes
calculées DAX qui sont figées au rafraîchissement. C'est précisément ce qui
permet à deux utilisateurs de langues différentes de voir des libellés
différents sur le même modèle publié. La chaîne :

```
identité de l'embed  →  rôle RLS  →  filtre sur dim_trad_language
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
# languages_df = dim_trad_language (les langues du périmètre), lang_en = 2 (English)
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

**Les clés viennent des nomenclatures**, pas des tables de traduction : la règle
du PO ne peut s'appliquer qu'à une ligne qui existe. Une clé jamais traduite
dans aucune langue n'aurait sinon aucune ligne, et s'afficherait vide.
Constat en preprd : 127 catégories de détail de notes sur 397.

**Le repli de dernier recours est le `code` métier** de la nomenclature
(`ORGE_6RH`, `TCR`) et non l'identifiant technique (`42`, `detail_TCR`) : c'est
l'interprétation la plus vraisemblable de « la clé » dans la règle du PO, et la
seule qui produise quelque chose de lisible. **À confirmer avec lui**, ainsi que
sa connaissance des clés jamais traduites.

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

### `dim_trad_language`
Une petite table de référence, **une seule ligne par langue** :

Alimentée depuis `parameters_languages` (voir « `dim_trad_language` — source réelle
et piège de codification » ci-dessous : la colonne `code` de la source ne peut
pas être rapprochée directement de `USERCULTURE()`).

### Relations

> **Correction apportée à la conception initiale.** Relier `dim_trad_language`
> en 1 → * à chaque table de traduction créait des **chemins ambigus** : avec les
> relations bidirectionnelles traduction ↔ nomenclature, plusieurs routes
> menaient des faits à la langue, et Power BI refuse d'ouvrir le modèle.
>
> `dim_trad_language` est donc une table **déconnectée**, et le rôle porte un
> `tablePermission` par table de traduction. Le filtre y est résolu par
> `LOOKUPVALUE` sur `dim_trad_language`. On perd le « RLS écrit une seule fois »,
> mais le modèle est valide et chaque filtre reste identique au mot près.
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
sur `dim_trad_language` :

```dax
VAR __culture   = LOWER ( LEFT ( USERCULTURE (), 2 ) )
VAR __supported = NOT ISEMPTY (
                      FILTER ( ALL ( dim_trad_language ), dim_trad_language[code] = __culture )
                  )
RETURN
    dim_trad_language[code] = IF ( __supported, __culture, "en" )
```

Trois choses à noter dans cette expression :

1. **`LEFT ( ... , 2 )`** — `USERCULTURE()` renvoie une culture complète
   (`fr-FR`, `en-GB`, `ro-RO`…). En ne comparant que les deux premiers
   caractères, toutes les variantes régionales d'une même langue retombent sur
   la même traduction, et le front n'a pas à normaliser ce qu'il envoie.
   Si `dim_trad_language` doit un jour distinguer `pt-BR` de `pt-PT`, il suffira de
   comparer la culture entière.
2. **Le garde-fou `__supported`** est indispensable. Sans lui, une culture
   inconnue ne ramène aucune ligne dans `dim_trad_language`, donc aucune ligne dans
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

### `dim_trad_language` — source réelle et piège de codification

Le référentiel existe : **`ext_mal_psql_maite_vision_board_<env>.public.parameters_languages`**
`id_parameter_language (int) | name | code | deleted | created_at | updated_at | deleted_at`

| `id_parameter_language` | `name` | `code` | culture attendue de `USERCULTURE()` | `LEFT(culture,2)` |
|---|---|---|---|---|
| 1 | Français | `FR` | `fr-FR` | `fr` ✅ |
| 2 | English | `EN` | `en-GB` / `en-US` | `en` ✅ |
| 3 | Polski | `PL` | `pl-PL` | `pl` — *hors périmètre* |
| 4 | українська | `UA` | `uk-UA` | `uk` — *hors périmètre* |
| 5 | Romanian | `RO` | `ro-RO` | `ro` ✅ |
| 6 | Czech | `CZ` | `cs-CZ` | **`cs` ❌** |

**Périmètre du projet : 4 langues — FR, EN, RO, CZ.** Le polonais et l'ukrainien
existent en base mais ne sont pas traités. `CULTURE_MAP` dans `dim_trad_language`
déclare le périmètre : une langue qui n'y figure pas n'entre pas dans le modèle.
Si l'ukrainien est ajouté un jour, attention à mapper `UA` vers `uk` et non `ua`.

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

dim_trad_language = (
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

Le rôle RLS compare alors `dim_trad_language[culture_code]`, pas `dim_trad_language[code]` :

```dax
VAR __culture   = LOWER ( LEFT ( USERCULTURE (), 2 ) )
VAR __supported = NOT ISEMPTY (
                      FILTER ( ALL ( dim_trad_language ),
                               dim_trad_language[culture_code] = __culture )
                  )
RETURN
    dim_trad_language[culture_code] = IF ( __supported, __culture, "en" )
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

### Cohabitation avec la phase 1 — vérifiée

Les mesures statiques de la phase 1 (`TITLE_*`, `TEXTE_*`) comparent la **culture
entière** contre la table `Translation` :

```dax
CALCULATE (
    SELECTEDVALUE ( Translation[TranslationText] ),
    Translation[LanguageCode] = USERCULTURE (),   -- "fr-FR"
    ...
)
```
avec un repli sur `"en-US"`.

La phase 2 compare les **2 premières lettres**. Les deux approches coïncident
tant que le front n'envoie que les cultures présentes dans `Translation`.

**Relevé en preprd** : `Translation` contient exactement `fr-FR`, `en-US`,
`ro-RO`, `cs-CZ` — les 4 cultures du projet. Aucune divergence possible.

La comparaison sur 2 lettres est un **sur-ensemble** de la comparaison exacte :
elle matche tout ce que la phase 1 matche, plus les variantes régionales
(`fr-BE`, `en-GB`). Un écart n'apparaîtrait que si le front envoyait une telle
variante — et ce serait alors la phase 1 qui se dégraderait (titres en anglais,
données dans la bonne langue), pas la phase 2.

> Amélioration possible de la phase 1, hors périmètre : comparer
> `LEFT ( USERCULTURE (), 2 )` dans les mesures la rendrait tolérante aux
> variantes régionales. Une trentaine de mesures à modifier.

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

## Étape 3 bis — Contraintes imposées par `delta_function`

La lecture de `delta_function.ipynb` impose trois adaptations, toutes intégrées
aux notebooks livrés :

1. **`handle_table_update` ne crée pas de table.** Ses deux modes appellent
   `DeltaTable.forName(...)`, qui échoue si la table est absente. Les 13 tables
   nouvelles de la phase 2 ont donc besoin d'un bootstrap : `ensure_delta_table()`
   crée la table vide (schéma du DataFrame + `created_at`) au premier passage.
2. **Aucune évolution de schéma demandée explicitement** — mais le comportement
   réel dépend d'un réglage du cluster. `handle_table_update` ne pose ni
   `option("mergeSchema", "true")` sur l'append du mode `full`, ni
   `withSchemaEvolution()` sur le MERGE du mode `update`. En revanche
   `spark.databricks.delta.schema.autoMerge.enabled`, s'il est actif sur le
   workspace, active l'évolution pour les deux. C'est apparemment le cas sur
   l'environnement de développement actuel, où des colonnes ont déjà été
   ajoutées par un simple run en mode `full`.
   Le notebook `phase2_migration_schema` reste livré comme **filet de sécurité** :
   idempotent, il ne fait rien quand les colonnes existent, et garantit le
   démarrage sur un environnement où le réglage serait inactif.
3. **Le mode `update` ne supprime jamais.** Le MERGE n'a ni
   `whenNotMatchedBySourceDelete` ni purge : une clé retirée à la source reste
   indéfiniment dans la table du modèle. Pour des tables de traduction, cela
   signifie des libellés fantômes persistants dans les slicers. Les tables de
   traduction et `dim_trad_language` sont donc écrites en **`mode="full"` imposé**
   (et non `execution_mode`) : elles sont petites et entièrement redérivées à
   chaque run.

## Étape 3 ter — Organisation en job dédié

Les tables de traduction sont des **référentiels partagés** : plusieurs projets
les consommeront, un seul job les alimente. Elles vivent donc dans
le schéma transverse `<catalogue>.common` (variable `translations_schema` définie dans `env`)
et non dans le schéma d'un projet.

### Notebooks

| Notebook | Rôle |
|---|---|
| `translation_function` | Les 3 fonctions, aucune table produite. Même rôle que `delta_function` |
| `dim_trad_language` | Le référentiel des langues, porteur du RLS |
| `build_translations` | Les 11 appels + le contrôle de couverture |
| `main_translations` | L'orchestrateur du job |

`build_translations` ne dépend pas de `load_data` : il charge lui-même ses 8
tables source, le job n'ayant aucun besoin des tables de mesures.
`source_catalog` est remonté dans `env`, partagé entre les deux pipelines.

### Planification

Le rythme se cale sur l'apparition de **nouvelles clés** (variétés, catégories de
notes, paramètres), pas sur les corrections de libellés : entre deux runs, une
clé nouvellement créée s'affiche sans libellé. Le front a confirmé qu'un refresh
séparé hebdomadaire est possible ; un run quotidien ramène le délai sous les 24 h
pour quelques minutes de calcul.

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

1. ~~Comment le front transmet-il la langue ?~~ **Tranché et validé en embed**
   le 04/09/2026 : la culture vient des `localeSettings`, pilotées par le
   sélecteur de langue de l'application (Čeština / English / Français /
   Română), et le rôle `Translation` est passé dans l'identité effective de
   l'appel `GenerateToken` :

   ```json
   "identities": [
     { "username": "...", "roles": ["Translation"], "datasets": ["<id>"] }
   ]
   ```

   Un dataset portant des rôles RLS **refuse** un token sans identité
   effective (HTTP 400, `InvalidRequest`) : `identities` n'est donc pas une
   option mais un passage obligé.

   Vérifié de bout en bout : `COUNTROWS ( dim_trad_specy )` renvoie **4** en
   embed (une langue) contre 16 sans rôle (quatre langues).

   Reste à confirmer avec le front qu'un **changement de langue régénère le
   token** : la RLS est figée à la création du token, alors que les
   `localeSettings` s'appliquent sans. Sans nouveau token, les titres
   changeraient de langue mais pas les données.
2. ~~Référentiel des langues~~ **Fourni** : `parameters_languages`, 6 langues.
   Attention au mapping `UA`→`uk` et `CZ`→`cs` (voir ci-dessus).
3. **`Parameter`** : quel discriminant permet de savoir s'il faut lire
   `parameters_variables_translations` ou
   `parameters_production_line_variables_translations` ?
4. **`old_note_category`** : colonne de reprise, ou clé alternative à gérer ?
5. **`Month`** et **`Workshop`** : hors périmètre RLS, à arbitrer avec le PO.

## Branchement des libellés dans le rapport — deux cas

La colonne `label` d'une table `dim_trad_*` vit du côté « plusieurs » de la
relation : une ligne par clé **et par langue**. C'est ce qui permet à la RLS d'en
retenir une seule à l'exécution, mais cela conditionne la façon de l'utiliser
dans un visuel.

### Cas 1 — slicers, graphiques, tableaux agrégés

Remplacement direct de l'ancienne colonne par la colonne `label`. Le libellé sert
de filtre, qui descend vers le fait par la nomenclature. Aucun coût
supplémentaire.

Concerne la grande majorité des visuels : les 9 slicers `specy_name` /
`variety_name` / `production_type` / `location` / `event` / `detail` / `impact`,
les graphiques `Gap_Heures` et l'arbre de décomposition.

### Cas 2 — tableaux détail à la granularité de la ligne de fait

Trois visuels `tableEx` affichent des colonnes de fait **non agrégées** à côté
des libellés :

| Page | Visuel | Libellés concernés |
|---|---|---|
| `490a406e0752c28c2e85` | `c51513a5669c210fc9b1` | `specy_name`, `variety_name`, `production_type` |
| `dad332f6dad7d49815c8` | `d5bb64bc6639d0a9939b` | `location`, `event`, `detail`, `impact` |
| `02505ab6f3fc1fb6e4ab` | `f759d34e07648838c008` | idem |

Le remplacement direct y échoue : la colonne `label` deviendrait une seconde clé
de regroupement, et le moteur refuse d'apparier une ligne de fait aux 4 libellés
de sa clé (« impossible de déterminer les relations entre les champs »).

**Solution retenue : une mesure par libellé, en `TREATAS`.**

```dax
Espèce =
CALCULATE (
    MIN ( dim_trad_specy[label] ),
    TREATAS (
        VALUES ( dim_batches_specifications[id_good_specy] ),
        dim_trad_specy[id_good_specy]
    )
)
```

Une mesure n'ajoute pas de clé de regroupement, donc pas d'ambiguïté. `TREATAS`
transpose l'ensemble des identifiants visibles vers la table de traduction en une
seule opération ensembliste — testé performant sur la page « Measures (all
batches) », non filtrée. Les variantes ligne à ligne (`SELECTEDVALUE` puis
`CALCULATE` avec un filtre scalaire, `CONCATENATEX`) donnent le bon résultat mais
sont trop lentes sur ce volume.

`MIN` est légitime : sous le rôle, la RLS ne laisse qu'un libellé par clé. Sans le
rôle, il en renvoie un des quatre — utile pour vérifier en développement que la
mesure fonctionne et que seule la RLS manque.

Les sept mesures : `Espèce`, `Variété`, `Type de production` (clés portées par
`dim_batches_specifications`), `Emplacement`, `Événement`, `Détail`, `Impact`
(clés `key_*` portées par `fact_batch_note`, rapprochées de
`batch_note_category`).

### Voie écartée — relation directe fait → traduction

Relier `fact_batch_note[key_impact]` directement à `dim_trad_batch_note_impact`
fait disparaître l'ambiguïté et les tableaux détail acceptent alors la colonne
`label`. **Mais les totaux tombent** : les deux tables ayant plusieurs lignes de
part et d'autre, Power BI impose une relation plusieurs-à-plusieurs, dite
*limitée*, sur laquelle le filtre de RLS se propage dans les deux sens quel que
soit le réglage de « Appliquer le filtre de sécurité dans les deux directions ».
Les lignes de fait sans correspondance sont éliminées : notes dont la clé est
vide, et notes pointant vers une catégorie supprimée (127 cas écartés par le
filtre `deleted = false`).

Testé et mesuré sur `key_impact` : `Test_NbNotes` baisse à l'activation du rôle.
Relation supprimée, retour à 2,51 K.

La nomenclature au milieu est donc structurellement nécessaire — c'est elle qui
fournit le côté « un » :

```
fact / dim  --N:1-->  dim_specy  <--N:1--  dim_trad_specy
                      (1 ligne              (4 lignes
                       par espèce)           par espèce)
```

Les deux relations sont alors normales et non limitées : la RLS reste confinée à
la table de traduction, et les totaux ne bougent pas.
