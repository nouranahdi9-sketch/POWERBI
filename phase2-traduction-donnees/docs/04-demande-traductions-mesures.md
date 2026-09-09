# Traduction des mesures — ce que nous attendons

**Destinataires** : équipe en charge de `trs_metadata`
**Contexte** : rapport *Process Time Analyses*, embarqué dans Vision Board
**Objet** : mise à disposition des libellés de mesures en 4 langues

---

## 1. Pourquoi cette demande

Le rapport est consulté en **français, anglais, roumain et tchèque**. Les
éléments d'interface et les données métier (espèces, variétés, catégories de
notes) sont désormais traduits automatiquement selon la langue de
l'utilisateur.

Les **noms de mesures** ne le sont pas encore. Ils viennent de `trs_metadata`,
qui ne contient qu'un libellé par mesure — celui du site auquel la ligne se
rapporte. Un utilisateur tchèque voit donc des libellés en français ou en
roumain.

Le mécanisme de traduction est en place et fonctionne. Il ne lui manque que la
matière : les libellés eux-mêmes.

---

## 2. Ce que nous vous demandons

**Uniquement les traductions.** Les tables techniques de mise en forme, les
relations et les règles d'affichage sont construites de notre côté à partir de
`trs_metadata`.

Trois ensembles de libellés sont concernés.

### a. Les mesures

Clé : **`measure_DA`** (le code technique, ex. `chargement_trempe`).

Deux champs à traduire :

| Champ | Description | Obligatoire |
|---|---|---|
| `label` | libellé affiché dans le rapport | oui |
| `measure_description` | description détaillée | non |

### b. Les types de mesure

Clé : **`measure_type`**. Ensemble fermé, quelques valeurs :
`TRANSFERT`, `ATTENTE`, `PRODUCTION_EFFECTIVE`, `CUVE_VIDE`,
`BATCH_CYCLE_DURATION`…

Un libellé par valeur et par langue.

### c. Les catégories de process

Clé : **`categorie`**. Ensemble fermé également :
`PRISE_DE_GRAINS`, `TREMPE`, `GERMINATION`, `TOURAILLAGE`…

Un libellé par valeur et par langue.

---

## 3. Format attendu

Les deux formats ci-dessous nous conviennent. **Choisissez celui qui vous est
le plus commode à maintenir** — notre traitement s'adapte.

### Option A — colonnes par langue dans `trs_metadata`

```
measure_DA          | label_fr           | label_en      | label_ro            | label_cs
chargement_trempe   | Chargement trempe  | Steeping load | Încărcare umectare  | ...
```

Plus simple à remplir et à relire dans un tableur : les manques se voient d'un
coup d'œil. Demande un `ALTER TABLE` à chaque nouvelle langue.

### Option B — une table de traductions dédiée

```
trs_metadata_translations
  measure_DA | language | label | description
```

Plus propre en base, extensible sans modification de schéma. Trois fois plus de
lignes à saisir.

**Notre préférence : l'option A**, parce que la saisie est manuelle et que la
relecture prime. Mais c'est votre table, votre choix.

Dans les deux cas, prévoir la même chose pour `measure_type` et `categorie` —
soit deux petites tables, soit un onglet dédié.

---

## 4. Règles à respecter

**Le code d'identification de la langue** : `fr`, `en`, `ro`, `cs` (ISO 639-1).
Attention, le tchèque est `cs`, pas `cz`.

**Un libellé par mesure et par langue.** Deux libellés pour le même couple
feraient apparaître la mesure en double dans le rapport.

**Ne pas laisser de chaîne vide.** Une case vide est traitée comme une
traduction absente — ce qui est le comportement voulu. Un espace ou un tiret
serait pris pour un libellé valide et affiché tel quel.

**Toute nouvelle mesure doit arriver avec ses traductions.** Sans elles, elle
s'affichera en anglais, ou avec son code technique si l'anglais manque aussi.

---

## 5. Ce qui se passe si une traduction manque

Le rapport ne reste jamais vide. Il applique une chaîne de repli :

| Situation | Ce que voit l'utilisateur |
|---|---|
| Traduction disponible dans sa langue | le libellé traduit |
| Absente, mais anglais disponible | **le libellé anglais** |
| Absente partout | **le code technique** (`chargement_trempe`) |

L'anglais est donc la langue de secours : c'est celle à privilégier si vous
devez procéder par étapes.

---

## 6. Volumétrie

À confirmer par vous :

```sql
SELECT count(DISTINCT measure_DA)   AS nb_mesures,
       count(DISTINCT measure_type) AS nb_types,
       count(DISTINCT categorie)    AS nb_categories
FROM <catalogue>.trs_metadata;
```

Les types et les catégories représentent quelques dizaines de libellés au
total : c'est par là que nous suggérons de commencer, le gain étant immédiat et
l'effort faible.

---

## 7. Ce que nous faisons de notre côté

- construction des tables de nomenclature depuis `trs_metadata`
- construction des tables de traduction au format attendu par Power BI
- relations, règles de sécurité, branchement des visuels
- un contrôle automatisé listant, pour chaque mesure, les langues manquantes —
  que nous pourrons vous transmettre régulièrement

Rien de tout cela ne vous concerne. Une fois les libellés saisis, ils
apparaissent dans le rapport au rafraîchissement suivant, sans intervention.

---

## 8. Questions ouvertes

1. Quel format retenez-vous, A ou B ?
2. Qui saisit les libellés — votre équipe, le métier, un prestataire ?
3. Une même mesure peut-elle avoir des libellés différents selon la ligne de
   production, ou le libellé est-il propre à la mesure quel que soit le site ?
   Cette réponse détermine la clé de traduction.
4. Quel délai envisagez-vous pour un premier jeu, même limité à l'anglais ?
