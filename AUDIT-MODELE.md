# Audit du modèle sémantique — Dashboard self-service

Source : export PBIP/TMDL du 28/08/2026. Source de données : Databricks SQL
Warehouse `adb-6120597545375074` (mode Import, 17 requêtes).

Objectif : réduire le temps de refresh, par optimisation du modèle et du
rapport, avant toute réduction du périmètre de données.

---

## Synthèse

| Constat | Ampleur | Priorité |
|---|---|---|
| Date/heure automatique activée | 54 tables cachées sur 72 | **1 — critique** |
| Colonnes d'audit inutiles dans le modèle | 37 colonnes | **2 — fort** |
| Aucune table de dates partagée | 0 `dim_date` | **3 — structurel** |
| Aucun refresh incrémentiel | 0 politique définie | **4 — fort** |
| Ruptures de query folding | 3 requêtes | **5 — moyen** |
| Relations bidirectionnelles | 7 relations | 6 — moyen |
| `fact_weather` en erreur | `PBI_ResultType = Exception` | 7 — à vérifier |

---

## 1. Date/heure automatique — le coupable principal

`model.tmdl` porte l'annotation `__PBI_TimeIntelligenceEnabled = 1`.

Conséquence directe : Power BI a créé **53 tables `LocalDateTable_*`** plus un
`DateTableTemplate`, soit **54 tables cachées sur les 72** que compte le modèle
(75 %), et **53 des 68 relations** (78 %).

Chaque table cachée est une table *calculée* de ce type :

```dax
Calendar(
    Date(Year(MIN('fact_weather'[germ_c2_start_date])), 1, 1),
    Date(Year(MAX('fact_weather'[germ_c2_start_date])), 12, 31)
)
```

et embarque 6 colonnes calculées (`Année`, `NoMois`, `Mois`, `NoTrimestre`,
`Trimestre`, `Jour`) plus une hiérarchie.

Pourquoi c'est fatal au refresh : les tables calculées sont reconstruites
**à chaque refresh**, après le chargement des données, dans une phase séquentielle
et non parallélisable. Le moteur doit, 53 fois, scanner la colonne source pour en
extraire MIN et MAX, générer le calendrier, puis évaluer 6 colonnes calculées et
construire une relation. Sur une plage de 10 ans, chaque table fait ~3 650 lignes ×
7 colonnes.

**Action** : Fichier → Options → Fichier actif → Chargement des données →
décocher **« Date/heure automatique »**. Les 54 tables et 53 relations
disparaissent d'un coup.

⚠️ Cette option casse les hiérarchies de dates utilisées dans les visuels. Il faut
donc traiter le point 3 (table de dates) dans la foulée, et reprendre les visuels
qui s'appuient sur une « Hiérarchie de dates ».

---

## 2. Colonnes d'audit importées pour rien

Sur les 53 colonnes `dateTime` du modèle, **37 sont des colonnes techniques** :

- `created_at` : 13 occurrences
- `updated_at` : 12 occurrences
- `deleted_at` : 12 occurrences

Elles ne sont utilisées dans aucune des 8 mesures du modèle, et personne n'analyse
un indicateur métier par date de suppression logique. Elles coûtent pourtant :

- une table de dates automatique chacune (soit 37 des 53, voir point 1) ;
- un dictionnaire par colonne, avec une cardinalité très élevée : un `datetime` à
  la seconde produit presque autant de valeurs distinctes que de lignes, ce qui est
  le pire cas pour la compression VertiPaq.

**Action** : les retirer côté Power Query (`Table.RemoveColumns`) ou, mieux, ne
plus les sélectionner dans la vue Databricks. Si l'une d'elles doit être conservée
pour une logique de filtrage, la réduire au grain utile (date seule plutôt que
datetime à la seconde).

`fact_weather` mérite un traitement à part : 52 colonnes dont 13 `dateTime`,
c'est-à-dire 13 tables de dates automatiques générées par une seule table.

---

## 3. Aucune table de dates partagée

Le modèle ne contient aucune `dim_date`. C'est la conséquence directe du point 1 :
la date/heure automatique a dispensé de créer une vraie dimension temps.

**Action** : créer une `dim_date` unique, **côté Databricks** de préférence (une
table ou vue dans le schéma `gold`), et la relier aux colonnes de date réellement
utilisées pour l'analyse. Une table de dates en DAX (`CALENDAR`) fonctionnerait
aussi, mais reste une table calculée reconstruite à chaque refresh — autant la
laisser à la source, où elle est chargée comme une table ordinaire.

---

## 4. Aucun refresh incrémentiel

Aucune table ne porte de `refreshPolicy`, et il n'existe ni paramètre `RangeStart`
ni `RangeEnd`. Chaque refresh recharge donc **l'intégralité** des 17 tables depuis
Databricks, y compris l'historique figé.

**Action** : après avoir traité les points 1 et 2, définir une politique de refresh
incrémentiel sur les tables de faits volumineuses (`fact_measurement`,
`fact_energy`, `fact_weather`, `batch_report`). C'est le levier le plus puissant
une fois le modèle assaini — mais il n'a de sens qu'après, sinon on ne fait
qu'accélérer le chargement de données qu'on n'aurait pas dû charger.

---

## 5. Query folding — trois requêtes à reprendre

La majorité des 17 requêtes sont de simples navigations vers une table Databricks,
donc entièrement déléguées à la source. Trois font exception.

**`localisation`** — `Table.UnvivotOtherColumns` ne se délègue pas. La vue
`localizations_pivot` est donc intégralement rapatriée dans le moteur mashup, puis
dépivotée en local. À déplacer dans une vue Databricks qui renvoie directement le
format dépivoté.

**`parameters_variables_translations`** — `Table.NestedJoin` référence la requête
`parameters_variables`. Celle-ci est alors évaluée deux fois : une fois pour sa
propre table, une fois à l'intérieur de la jointure. À remplacer par une jointure
côté Databricks.

**`batch_report`** — `Table.Sort(…, "custom_order")` est un pur gaspillage : le
moteur VertiPaq ne conserve pas l'ordre des lignes, ce tri est perdu au chargement.
La colonne dupliquée `Filtre DesiredFields` est par ailleurs une copie intégrale de
`parameter`, donc un second dictionnaire pour la même information. Pour un besoin
de tri d'affichage, utiliser « Trier par colonne » sur la colonne `custom_order`.

À surveiller aussi : `malt_quality_results` et `goods_quality_results` appliquent un
`Table.Distinct` sur un sous-ensemble de clés après `Table.SelectColumns`. La
délégation y est partielle selon le connecteur — à confirmer par le diagnostic de
requête (clic droit sur l'étape → « Afficher le plan de requête »).

---

## 6. Connexion Databricks — 17 énumérations de catalogue

Les 17 requêtes appellent chacune `Databricks.Catalogs(...)` puis naviguent par
`{[Name="…",Kind="Database"]}`. Chaque appel déclenche une énumération des
catalogues, schémas et tables d'Unity Catalog avant même de lire la moindre ligne.
Sur un métastore fourni, ce coût de métadonnées se paie 17 fois.

**Action** : vérifier dans les journaux de refresh la part du temps passée avant le
premier octet de données. Si elle est significative, remplacer la navigation par
`Value.NativeQuery` sur une source partagée.

À vérifier également : si le SQL Warehouse est en mode serverless et qu'il était
arrêté, le démarrage à froid ajoute plusieurs minutes au refresh, indépendamment du
modèle.

---

## 7. Relations bidirectionnelles et auto-détectées

Sept relations sont en `crossFilteringBehavior: bothDirections`, dont
`dim_batch ↔ dim_specification`, `dim_batch ↔ dim_site`,
`dim_batch ↔ dim_variety_specy`, `dim_batch ↔ dim_production_type` et
`fact_weather ↔ dim_batch`.

Sans effet sur le refresh, mais source d'ambiguïté de filtrage et de lenteur à
l'interrogation. À repasser en simple sens partout où le besoin ne l'exige pas.

Six relations portent par ailleurs le préfixe `AutoDetected_`, signe que la
détection automatique des relations est active. À désactiver et à valider
manuellement, pour éviter qu'un futur ajout de colonne ne crée une relation non
voulue.

---

## 8. `fact_weather` en erreur

La partition `fact_weather` porte `annotation PBI_ResultType = Exception`, alors
que toutes les autres portent `Table`. La dernière évaluation de cette requête a
donc échoué. À vérifier en priorité : une requête en erreur peut faire échouer ou
traîner l'ensemble du refresh.

---

## Ordre d'exécution recommandé

1. Vérifier l'erreur sur `fact_weather` (point 8)
2. Désactiver la date/heure automatique (point 1)
3. Supprimer les colonnes d'audit (point 2)
4. Créer `dim_date` côté Databricks et recâbler les visuels (point 3)
5. Mesurer le nouveau temps de refresh — les points 1 à 3 devraient déjà produire
   l'essentiel du gain
6. Reprendre les trois requêtes non déléguées (point 5)
7. Nettoyer les relations (point 7)
8. Mettre en place le refresh incrémentiel (point 4)

Les points 1 à 3 se traitent en moins d'une heure et ne demandent aucune
modification côté source.

---

## Pour aller plus loin

Ce diagnostic est établi sur la structure du modèle. Pour chiffrer le coût réel de
chaque colonne — taille en mémoire, cardinalité, ratio de compression — il faut un
export **VertiPaq Analyzer** : DAX Studio → Advanced → Export Metrics → fichier
`.vpax`, à déposer sur cette branche.

---

# Addendum — mesures relevées sur la source Databricks

Investigation menée après le premier audit, sur `fact_measurement`.

## Volumétrie réelle

```
lignes     347 633 572
batches         10 686
mesures            659
couples      6 388 392   (batch_id + measure_name distincts)
```

**Ratio lignes / couples = 54,4.** Chaque couple (batch, mesure) est stocké
54 fois en moyenne. La table « utile » fait 6,4 millions de lignes ; les
341 millions restants (98,2 % du volume) sont de la redondance accumulée par
un pipeline en `appendOnly` qui réempile à chaque exécution au lieu de
consolider.

## Stockage à la source

`DESCRIBE DETAIL` :

```
partitionColumns    []            aucune partition
clusteringColumns   []            aucun Z-order
numFiles            74
sizeInBytes         742 415 523   (~742 Mo, zstd)
```

742 Mo pour 347 millions de lignes, soit ~2 octets par ligne : la compression
Delta absorbe déjà très bien la redondance. La lecture à la source n'est donc
pas le goulot d'étranglement, et un `OPTIMIZE … ZORDER` ne se justifie pas.
Le coût du refresh est proportionnel au **nombre de lignes transférées puis
encodées dans VertiPaq**, pas à leur taille sur disque.

## Usage réel dans le rapport

`fact_measurement` n'alimente que **2 visuels sur une seule page** (MEASUREMENT) :
un tableau et un segment sur `measure_name`, dont la valeur par défaut est
`steep_process_duration`. Aucun autre visuel des 8 pages n'y touche.

## Leviers, par ordre de rendement

1. **Déduplication** (`ROW_NUMBER` sur `batch_id, measure_name`) : 347 M -> 6,4 M,
   soit -98 %. À matérialiser en vue ou table dans `gold`, pas dans Power Query.
   À valider d'abord : les 54 copies portent-elles la même `value` ?
2. **Année glissante** sur `dim_batch.debut_de_production` : conserve 23 % des
   lignes (mesuré : 79 942 394 sur 347 633 572). Cumulé avec la déduplication,
   amène le modèle autour de 1,5 M de lignes.
3. **Filtre sur les `measure_name` réellement consultées** : à arbitrer avec le
   métier, devient secondaire une fois les deux premiers appliqués.

Ne pas filtrer sur `created_at` : c'est l'horodatage d'insertion, et la table a
été créée le 29/01/2026 par reprise d'un historique de plusieurs années. Le
filtre métier est `dim_batch.debut_de_production`.

## Correctif de fond

La déduplication à la lecture soulage le rapport mais ne traite pas la cause.
Une table `appendOnly` qui réempile 54 fois la même mesure croît indéfiniment.
Le correctif durable est un `MERGE` à l'écriture dans le notebook amont — à
étudier, il bénéficierait à tous les consommateurs de la table.
