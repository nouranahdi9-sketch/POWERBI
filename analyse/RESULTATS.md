# Écart de KPI entre les deux rapports recommandations

Fenêtre analysée : **18/07/2026 → 28/08/2026** · Exécution des requêtes : 15/09/2026

## Les deux KPI comparés

| | Monitoring — « Success » | Suivi — « Total Available Reco. » |
|---|---|---|
| Valeur | 1643 | 1662 |
| Mesure | `Evolution_succes` = `SUM(fact_monitoring_auto_manual_entries[flg_succes])` | `SUM(batches_reco[total])` |
| Table | `recommendations_monitoring.fact_monitoring_auto_manual_entries` | `recommendations.fact_batches_reco` |
| Slicer | `dim_calendar[date_simple]` → `calculation_date` | `DIM_PLANNED_DATE[Date]` → `planned_date` |
| Sémantique du filtre | chaque **recommandation**, sur sa date de fin d'intervalle de calcul | chaque **batch**, sur sa date de trempe planifiée |

Les deux comptent la même chose au fond : les couples `(batch, localisation)` ayant
une recommandation. Ils ne les filtrent pas sur le même axe de temps.

## Décomposition de l'écart (requête Q1)

| Bucket | Paires | Lecture |
|---|---|---|
| A — compté des deux côtés | 1500 | socle commun |
| B — Suivi seul, reco hors fenêtre | 162 | axe de date |
| C — Suivi seul, absente du Monitoring | **0** | — |
| D — Monitoring seul, batch hors fenêtre | 143 | axe de date |
| E — Monitoring seul, hors périmètre Suivi | **0** | — |

Contrôles : `A + B + C = 1662` ✅ · `A + D + E = 1643` ✅

**L'intégralité de l'écart vient de l'axe de date.** Les hypothèses de divergence de
périmètre (planning, `is_target_localization`, `deleted`, ROUEN1, lignes de production)
sont toutes vérifiées à zéro sur cette fenêtre.

## Le point critique

L'écart net de 19 est une **quasi-compensation entre 162 et 143**, pas un accord.

- 305 paires en désaccord, soit **18 % du KPI**
- 1500 paires communes sur 1662, soit **90 %**

Les recommandations d'un batch s'étalent sur tout le cycle de maltage
(steeping → germination → kilning). Filtrer sur la date de trempe du batch ou sur la
date de calcul de chaque reco ne sélectionne donc jamais le même ensemble. Sur une
fenêtre plus courte, ou sur une période où le volume de batches varie, l'écart net
peut atteindre plusieurs centaines sans qu'aucune donnée n'ait changé.

## Constats secondaires

**Filtre `deleted` absent du pipeline Monitoring** — `transform_data.ipynb` cellule 20
consomme `batches_production_planning` et `batches` sans filtrer `deleted`, là où
`import_recommendations.ipynb` cellules 6 et 7 le font.
Mesuré : 56 lignes d'échec rattachées à des batches supprimés, **0 succès**.
Effet sur le taux uniquement : 1643/2530 = 64,9 % → 1643/2474 = **66,4 %** une fois
corrigé. Aucune ligne de planning supprimée dans la fenêtre (volet latent).

**Asymétries latentes, impact nul aujourd'hui**
- ROUEN1 / Germination J5 (localisation 14) exclu côté Suivi seulement
  (`import_recommendations.ipynb` cellules 8 et 11) : aucune reco concernée dans la fenêtre.
- Filtres rapport sur `dim_site[plant]` : le Monitoring utilise une liste
  **d'exclusion** (`NOT IN (null,'BURTON1','STRASBOURG1')`), le Suivi une liste
  **blanche** de 8 lignes. Toute nouvelle ligne de production entrera automatiquement
  dans le Monitoring et jamais dans le Suivi.

**Typo** — `transform_data.ipynb` cellule 6 et `fact_monitoring_auto_manual_entries.ipynb` :
`"PR1" → "PROUYY1"` au lieu de `PROUVY1`. Sans effet sur les KPI (les visuels passent
par `dim_site[plant]`), mais la colonne `production_line` de la table de faits est fausse.

**RAS** — tous les `planned_date` sont à minuit, la relation vers `DIM_PLANNED_DATE`
est saine.

## Restant à vérifier

| Requête | Objet |
|---|---|
| Q8 | `flg_succes` figé — Q6 était invalide (grain `missing_value` vs grain paire) |
| Q9 | carte « Available Reco. » : 76 % à l'écran vs 66,1 % recalculé |
| Q10 | `recommendations.calculation_date` coïncide-t-il avec `calculation_interval_after_datetime` ? Conditionne le choix de l'axe commun |
| Q11 | fragilité de l'écart net, mois par mois |
