# Traduction des données — dossier de livraison

Rapport **Process Time Analyses**, embarqué dans l'application Vision Board.
Phase 2 du projet de traduction : les **valeurs** affichées dans le rapport,
après la phase 1 qui a traité les éléments statiques (titres, en-têtes,
libellés de boutons) via Tabular Editor.

Périmètre : **4 langues** — français, anglais, roumain, tchèque.

---

## 1. Le problème et la solution retenue

### Ce qu'il fallait résoudre

Un rapport embarqué affiche des valeurs venant de la base : noms d'espèces, de
variétés, catégories de notes de production. Ces valeurs sont stockées en une
seule langue, ou sous forme de clés techniques (`event_panne`,
`location_germination`). L'utilisateur tchèque voyait donc une interface
traduite mais des données en français ou en code brut.

### Pourquoi la RLS et pas une mesure DAX

Une colonne calculée est évaluée **au rafraîchissement** : elle ne peut pas
dépendre de l'utilisateur qui consulte. Une mesure, elle, dépend du contexte,
mais ne peut pas servir de colonne de regroupement — donc ni slicer, ni axe de
graphique.

La sécurité au niveau des lignes (RLS) est le seul mécanisme évalué **à la
requête** qui laisse une vraie colonne dans le modèle. C'est ce qui permet à un
libellé traduit de se comporter comme n'importe quelle colonne : filtrer, trier,
servir d'axe.

### Le principe

Chaque table de traduction contient **une ligne par clé et par langue** — un
produit cartésien dense. La RLS n'en laisse qu'une seule à l'exécution, celle
de la langue de l'utilisateur.

```
   dim_trad_specy (avant RLS)          dim_trad_specy (après RLS, culture = cs)
   ┌──────┬────────┬──────────┐        ┌──────┬────────┬──────────┐
   │ clé  │ langue │ libellé  │        │ clé  │ langue │ libellé  │
   ├──────┼────────┼──────────┤        ├──────┼────────┼──────────┤
   │  1   │  fr    │ Orge     │        │  1   │  cs    │ Ječmen   │
   │  1   │  en    │ Barley   │  ────► │  2   │  cs    │ Pšenice  │
   │  1   │  ro    │ Orz      │        └──────┴────────┴──────────┘
   │  1   │  cs    │ Ječmen   │
   │ ...  │  ...   │   ...    │
   └──────┴────────┴──────────┘
```

La densification garantit qu'aucune clé ne disparaît : même sans traduction, la
ligne existe avec un libellé de repli.

### La chaîne de repli

Pour chaque clé et chaque langue, le libellé est choisi dans cet ordre :

1. la traduction dans la langue demandée
2. à défaut, **l'anglais**
3. à défaut, la **clé métier** brute

La colonne `label_source` conserve la trace du niveau atteint —
`translated`, `fallback_en`, `fallback_key` — ce qui rend les manques mesurables
plutôt que silencieux.

---

## 2. Le modèle de données

### La nomenclature au milieu, et pourquoi

Une table de traduction ne peut **jamais** être du côté « un » d'une relation :
elle a 4 lignes par clé. La relier directement à un fait donne une relation
plusieurs-à-plusieurs, dite *limitée*, sur laquelle le filtre de RLS se propage
dans les deux sens quel que soit le réglage — et **ampute les totaux**, les
lignes de fait sans correspondance étant éliminées.

La nomenclature fournit le côté « un » qui manque :

```
   fait / dim  ──N:1──►  dim_specy  ◄──N:1──  dim_trad_specy
                         (1 ligne              (4 lignes
                          par espèce)           par espèce)
```

Les deux relations sont alors normales, la RLS reste confinée à la table de
traduction, et les totaux ne bougent pas.

**Cette voie a été testée et écartée sur mesure** : reliée directement à
`fact_batch_note`, `dim_trad_batch_note_impact` faisait tomber `Test_NbNotes`
en dessous de sa valeur. Relation supprimée, retour à 2,51 K.

### Réglages des relations

| Relation | Cardinalité | Filtre croisé | Filtre de sécurité |
|---|---|---|---|
| `dim_trad_*` → nomenclature | plusieurs à un | **à double sens** | **décoché** |
| `dim_batches_specifications` → nomenclature | plusieurs à un | unique | — |
| `fact_batch_note[key_*]` → nomenclature | plusieurs à un | unique | — |

Le double sens fait remonter le filtre du libellé vers le fait — c'est lui qui
rend les slicers opérants. Le filtre de sécurité décoché empêche la RLS de
redescendre sur les faits — c'est lui qui protège les totaux. Les deux réglages
sont indissociables et ont chacun été validés par un test dédié.

### `dim_trad_language` : déconnectée mais indispensable

Elle ne porte **aucune relation**. Les 8 règles du rôle l'interrogent par
`LOOKUPVALUE` pour convertir la culture de l'utilisateur en identifiant de
langue.

La relier aux tables de traduction créait des chemins ambigus. Le prix de ce
choix : la règle RLS est écrite 8 fois au lieu d'une. C'est le compromis retenu
pour obtenir un modèle valide.

**Ne pas la supprimer** : invisible partout ailleurs, sa disparition mettrait la
RLS en erreur.

---

## 3. Ce qui a été construit

### Côté Databricks — schéma `common`

Les tables vivent dans `<catalogue>.common`, partagé entre projets, et non dans
le schéma du rapport : elles ont vocation à servir à d'autres rapports.

**6 notebooks créés**

| Notebook | Rôle |
|---|---|
| `translation_function` | Bibliothèque : `build_translation_dim`, `publish_dim`, `ensure_delta_table`. N'écrit aucune table. |
| `dim_trad_language` | Référentiel des 4 langues, avec le `culture_code` que lit la RLS. |
| `build_nomenclatures` | 14 nomenclatures — le côté « un » des relations. |
| `build_translations` | 12 tables `dim_trad_*` — le côté « plusieurs ». |
| `main_translations` | Orchestrateur, planifiable indépendamment du pipeline BI. |
| `phase2_migration_schema` | `ALTER TABLE` ponctuels. Usage unique. |

**6 notebooks existants modifiés**

| Notebook | Modification |
|---|---|
| `env` | `source_catalog` remonté depuis `load_data` ; `common_schema`. |
| `transform_data` | Identifiants de traduction propagés ; `month_num` conservé. |
| `dim_batches_specifications` | 4 identifiants ajoutés. |
| `fact_batch_note` | Clés `key_location`, `key_event`, `key_detail`, `key_impact`. |
| `fact_process_time_analyses` | `month_num_mesure` nul ramené à 0. |
| `load_data`, `main_process_time_analyses` | Suites du déplacement de `source_catalog`. |

**Point d'architecture** : le job de traduction est **autonome**. Chaque
notebook porte ses propres `%run` et ne dépend pas de `load_data`. Il peut donc
être planifié à sa propre fréquence — quotidienne, la fréquence de mise à jour
des traductions n'exigeant pas mieux.

### Côté Power BI

- **15 tables** importées : 7 nomenclatures, 7 tables de traduction,
  `dim_trad_language`. Plus `dim_month` et `dim_trad_month` pour les mois.
- **22 relations** ajoutées, réglées comme indiqué plus haut.
- **1 rôle** `Translation`, 8 `tablePermission`.
- **7 mesures** `TREATAS` pour les tableaux détail (voir §5).

### Côté front

Une seule ligne de code : le rôle dans l'identité effective de l'appel
`GenerateToken`.

```json
"identities": [
  { "username": "...", "roles": ["Translation"], "datasets": ["<id>"] }
]
```

Un modèle sémantique portant des rôles RLS **refuse** un jeton sans identité
effective (HTTP 400) : ce n'est pas une option.

---

## 4. La règle RLS

Identique sur les 8 tables, au nom de table près :

```dax
VAR __culture = LOWER ( LEFT ( USERCULTURE (), 2 ) )
VAR __lang =
    COALESCE (
        LOOKUPVALUE (
            dim_trad_language[language],
            dim_trad_language[culture_code], __culture
        ),
        LOOKUPVALUE (
            dim_trad_language[language],
            dim_trad_language[culture_code], "en"
        )
    )
RETURN
    dim_trad_specy[language] = __lang
```

`LEFT(...,2)` ramène `fr-FR` à `fr` : la culture envoyée par le front est
complète, le référentiel ne stocke que la langue. Le `COALESCE` assure le repli
vers l'anglais pour toute culture hors périmètre.

---

## 5. Brancher les libellés dans le rapport

Deux cas, selon la nature du visuel.

### Slicers, graphiques, tableaux agrégés — remplacement direct

On remplace la colonne d'origine par `dim_trad_*[label]`. Le libellé sert de
filtre, qui descend vers le fait par la nomenclature. Aucun coût.

Concerne la grande majorité des visuels.

### Tableaux détail — par une mesure

Trois tableaux affichent des colonnes de fait **non agrégées** à côté des
libellés. Le remplacement direct y échoue : la colonne `label` deviendrait une
seconde clé de regroupement, et le moteur refuse d'apparier une ligne de fait
aux 4 libellés de sa clé.

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
transpose l'ensemble des identifiants visibles en une seule opération
ensembliste — testé performant sur la page non filtrée. Les variantes ligne à
ligne donnent le bon résultat mais sont trop lentes.

### Deux pièges

**Les filtres figés doivent porter sur la clé, jamais sur le libellé.** Un
filtre sur `label = "Panne"` fonctionne en français et vide le visuel en
tchèque. Il doit porter sur `batch_note_category = 'event_panne'`.

**Le tri.** Un libellé texte se trie alphabétiquement. Pour les mois, il faut
déclarer `label` trié par `month_num` (Outils de colonne → Trier par colonne).

---

## 6. Le cas des mois

Les noms de mois venaient de `month_name_mesure`, colonne de texte du fait qui
contient **français et anglais mélangés** — héritage d'une version antérieure du
notebook, le mode `update` ne supprimant jamais les anciennes lignes. Chaque mois
était donc tracé en deux barres distinctes.

Solution : le même montage, avec `dim_month` (13 clés, les 12 mois plus `0` pour
« non renseigné ») et `dim_trad_month` (52 lignes). Les libellés sont définis
dans le notebook — les mois ne dépendent d'aucune table du front.

La colonne fautive n'est plus affichée : le mélange devient sans effet.

**Non traité** : `dim_batches_specifications[month_label]`, qui porte le mois du
lot et non de la mesure. Deux notions distinctes ne peuvent pas partager une même
dimension — d'où l'erreur de chemins ambigus si on essaie. Le traduire suppose
une dimension dupliquée : 2 tables et une 9ᵉ règle RLS.

---

## 7. Recette

| Test | Attendu | Statut |
|---|---|---|
| Rôle actif, `COUNTROWS(dim_trad_specy)` | 4 au lieu de 16 | ✅ |
| Totaux avec et sans rôle | inchangés (244 322 K / 2,51 K) | ✅ |
| Clic sur un libellé | filtre les autres visuels | ✅ |
| Les 4 langues, culture forcée | libellés corrects | ✅ |
| Culture inconnue (`zz`) | repli anglais | ✅ |
| Publication dans le service | rôle présent, « Tester en tant que rôle » → 4 | ✅ |
| Embed avec `roles: ["Translation"]` | 4 | ✅ |
| Changement de langue dans l'application | les données suivent | ✅ |

La chaîne est validée de bout en bout, de PostgreSQL jusqu'à l'écran.

---

## 8. Exploitation

**Fréquence** : le job `main_translations` tourne quotidiennement. Une correction
de libellé met donc jusqu'à 24 h à apparaître.

**Responsabilité des données** : les libellés viennent des tables
`*_translations` de PostgreSQL, alimentées par l'équipe front. Le pipeline ne
fait que les recopier. Toute nouvelle entrée de nomenclature doit être créée
**avec ses 4 traductions**, faute de quoi elle s'affichera en anglais.

**Suivi** : `phase2-traduction-donnees/sql/traductions_manquantes.sql` liste,
pour chaque nomenclature, quel libellé manque dans quelle langue. Une ligne = une
traduction à écrire.

---

## 9. Points ouverts

**14 traductions à compléter** — 13 variétés et `detail_dispositif_securite`,
essentiellement en tchèque. Elles s'affichent en anglais en attendant.

**`mesure_name` reste en français.** C'est la colonne la plus lue de la page
d'accueil. Elle vient probablement de `parameters_production_line_variables`,
nomenclature qui n'a **aucune traduction, dans aucune langue** — plusieurs
centaines d'entrées. Ce n'est pas un oubli ponctuel mais une nomenclature jamais
alimentée : un chantier de saisie à cadrer séparément.

**86 catégories de notes sans `category_class`.** Le pipeline les écarte, faute
de famille renseignée. À trancher : le front les renseigne, ou elles restent hors
périmètre.

**`month_label`** — voir §6.

**Questions au front** : quel discriminant distingue `parameters_variables` de
`parameters_production_line_variables` ? `old_note_category` est-elle une colonne
de reprise ? `batch_status_localization` et `parameters_units_translations`
sont-elles dans le périmètre ?

---

## 10. Contenu du dossier

```
phase2-traduction-donnees/
├── docs/
│   ├── 00-dossier-de-livraison.md      ce document
│   ├── 01-analyse-existant.md          état des lieux initial
│   ├── 02-architecture-rls.md          conception détaillée, décisions
│   └── 03-branchement-visuels.md       checklist par onglet
└── sql/
    ├── copie_prod_vers_preprd.sql      mise en place de la préprod
    ├── ajout_colonnes_phase2.sql       migrations de schéma
    ├── traductions_manquantes.sql      suivi : quel libellé, quelle langue
    ├── traductions_synthese_metier.sql volumétrie par catégorie
    └── ...                             variantes de contrôle
```

Notebooks Databricks et modèle Power BI à la racine du dépôt.
