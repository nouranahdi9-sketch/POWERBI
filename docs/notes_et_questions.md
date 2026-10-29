# One Pager Maltimize - Notes et questions à clarifier

Journal des décisions prises et liste des questions ouvertes, à mettre à jour
au fil du projet. Le détail des KPI (règles, sources) est dans `kpi_catalog.md`.

## Numérotation des KPI

La lettre correspond au compartiment de la maquette, le chiffre au KPI dans ce compartiment. Les questions sont numérotées par interlocuteur : PO, DE (Data Engineers), DS (Data Scientists), BI (nous).

| N° | KPI | N° | KPI |
|---|---|---|---|
| D1 | Data digitalization | R3 | % Spec-compliant AI recommendations |
| D2 | Metamodels | R4 | % Spec-compliant output batches |
| D3 | AI Recommendations | R5 | Average AI malt yield (R2) |
| D4 | Time Tracking & Production Notes | R6 | Average Real malt yield (R2) |
| U1 | Maltimize unique users | P1 | Process time dashboard |
| U2 | Dashboards PowerBI unique users | P2 | Gap Target vs actual cycle time |
| Q1 | Uncaptured Aveva data | P3 | Production notes |
| Q2 | Missing manual entries | P4 | Production notes impacts |
| Q3 | % Batches with missing SAP mandatory data | X1 | Cybersecurity |
| Q4 | Mandatory SAP data missing | X2 | AVEVA |
| R1 | % Available recommendations | X3 | Dataplatform & Historization |
| R2 | % Declared applied recommendations |  |  |

Attention : le KPI **R2** (% Declared applied recommendations) n'a rien à voir avec le « R2 » de la maquette, qui désigne le rendement humide (KPI R5 et R6).

## Questions ouvertes

Légende : 🟡 à discuter · ⏳ en attente de réponse · ✅ tranchée (déplacée dans les décisions)

### A voir avec le PO

| # | KPI | Question | Décision provisoire | Statut |
|---|---|---|---|---|
| PO1 | D1 – Data digitalization | Compter tous les batchs (planifiés, en cours, terminés) ou seulement les batchs terminés ? | Tous les batchs | 🟡 |
| PO2 | Tous les KPI | Pithiviers (PI6) : exclu de tous les KPI, ou seulement à partir d'une date ? | Exclu (géré via le référentiel DS : `is_active = false`) | 🟡 |
| PO3 | Tous les KPI | Date de référence du filtre date pour les KPI "batch" : date de fin du batch ou date planifiée ? | Date de fin du batch | 🟡 |
| PO4 | Q1 – Uncaptured Aveva data | Garder la règle du notebook (`succes_echec = 'ECHEC'`, `flg_auto = 1`, `id_alerting = 1`) ou celle du dashboard monitoring (`Evolution_echec_auto`) ? Inclure les échecs dus au tag drop ? | Règle du dashboard monitoring | 🟡 |
| PO5 | R1 – % Available recommendations | Quelle définition correspond au dashboard Overview : recos reçues ÷ recos prévues au planning (`total ÷ nb_reco_opti`), ou recos en succès ÷ recos attendues ? | - | 🟡 |
| PO6 | R2 – % Declared applied recommendations | Dénominateur : total des recos reçues ou recos évaluées ? | - | 🟡 |
| PO7 | R4 – % Spec-compliant output batches | Batchs sans qualité ou avec qualité partielle : exclus du calcul ou comptés non conformes ? | - | 🟡 |
| PO8 | P1 – Process time dashboard | Les colonnes Days et Views sont-elles utiles (question posée dans la spec) ? | - | 🟡 |
| PO9 | P3 – Production notes<br>P4 – Production notes impacts | Date de référence des notes : date de l'événement (`event_date`) ou date de saisie ? | - | 🟡 |
| PO10 | Mise en page | Valider le principe des flèches de tendance colorées selon la polarité du KPI (vert = amélioration, rouge = dégradation), différent de la maquette | Polarité par KPI | 🟡 |
| PO11 | Comparaison | Valider le filtre de comparaison (Previous period par défaut, Same period last year, Custom) à la place d'un N-1 fixe | Filtre de comparaison | 🟡 |

### A voir avec les DE (Data Engineers)

| # | KPI | Question | Statut |
|---|---|---|---|
| DE1 | D2 – Metamodels | Existe-t-il une source officielle des metamodels en RUN ? En attendant : lignes avec au moins 1 batch, hors PI6 | 🟡 |
| DE2 | Q3 – % Batches with missing SAP mandatory data<br>Q4 – Mandatory SAP data missing | Clé de jointure entre `batches` et `malt_quality_results` : `fabrication_order` ? | 🟡 |
| DE3 | Q3 – % Batches with missing SAP mandatory data<br>Q4 – Mandatory SAP data missing | Un batch terminé sans aucun résultat qualité doit-il être compté comme "données manquantes" ? | 🟡 |
| DE4 | Q3 – % Batches with missing SAP mandatory data<br>Q4 – Mandatory SAP data missing | Le statut "undefined" des batchs historiques est-il bien recalculé ? | 🟡 |
| DE5 | Q3 – % Batches with missing SAP mandatory data<br>Q4 – Mandatory SAP data missing | Liste des lignes ayant une table `malt_quality_results` (Buzau, Burton, Bolelemi...) | 🟡 |
| DE6 | Q4 – Mandatory SAP data missing | Peut-on identifier les données "hors qualité" (erreurs de saisie) ? | 🟡 |
| DE7 | U1 – Maltimize unique users | Faisabilité et coût d'un export Auth0 vers une table Databricks | 🟡 |
| DE8 | X3 – Dataplatform & Historization | L'information peut-elle être obtenue automatiquement ? | 🟡 |

### A voir avec les DS (Data Scientists)

| # | KPI | Question | Statut |
|---|---|---|---|
| DS1 | Référentiel des activations | Ticket envoyé : suivre la livraison (nom et emplacement de la table, responsable, valeurs de `site` identiques aux tables de recos, dates initiales de mise en PROD, délai) | ⏳ |
| DS2 | R3 – % Spec-compliant AI recommendations<br>R4 – % Spec-compliant output batches | Emplacement de la table `fact_delta_quality_realized_recommended` (dashboard Batch overview) | 🟡 |
| DS3 | R5 – Average AI malt yield (R2) | Quelle table contient le R2 prédit par reco ? | 🟡 |
| DS4 | D4 – Time Tracking & Production Notes | "Config note de production déployée" = au moins une note saisie, ou une table de configuration ? | 🟡 |

### Côté BI (à faire / à vérifier)

| # | Sujet | Action | Statut |
|---|---|---|---|
| BI1 | R1 – % Available recommendations<br>R2 – % Declared applied recommendations<br>R3 – % Spec-compliant AI recommendations<br>R4 – % Spec-compliant output batches<br>R5 – Average AI malt yield (R2) | Committer les rapports et notebooks "Suivi des recommandations" et "Batch overview" sur `One_Pager` | ⏳ |
| BI2 | Q1 – Uncaptured Aveva data<br>Q2 – Missing manual entries | Vérifier si le dashboard monitoring filtre sur `flg_lasted_reco` (dernière reco seulement) | 🟡 |
| BI3 | U2 – Dashboards PowerBI unique users<br>P1 – Process time dashboard | Si les rapports sont embarqués en mode "app owns data", les utilisateurs Maltimize ne sont pas identifiables côté Power BI : à vérifier | 🟡 |
| BI4 | D4 – Time Tracking & Production Notes | Vérifier que `trs_metadata.prd_line` = `lower(plants_production_lines.name)` pour supprimer le CASE écrit en dur | 🟡 |
| BI5 | P2 – Gap Target vs actual cycle time | Vérifier que la moyenne des écarts reste cohérente tous sites confondus | 🟡 |

## Décisions prises

| Date | Sujet | Décision |
|---|---|---|
| 2026-10-28 | Organisation | Projet développé sur la branche `One_Pager` ; documentation dans `docs/` |
| 2026-10-28 | Architecture | Les notebooks produisent les données au grain fin (ligne × jour, ligne × batch) ; les KPI sont agrégés en DAX pour que les filtres sites et date fonctionnent |
| 2026-10-28 | Comparaison | Filtre de comparaison dynamique : Previous period (défaut, = spec), Same period last year, Custom (proposé au PO, cf. PO11) |
| 2026-10-28 | Power BI | Désactiver "Date/heure automatique" ; utiliser une table `dim_calendar` marquée comme table de dates |
| 2026-10-28 | Q2 – Missing manual entries | Règle validée : `flg_echec = 1` et `has_manual_value = 1`, ÷ `recos_attendues` (identique au dashboard monitoring) |
| 2026-10-28 | R6 – Average Real malt yield (R2) | Source : paramètre `malt_yield_r2` déjà utilisé dans le projet Energy |
| 2026-10-28 | Référentiel des activations | Demande envoyée aux DS : une ligne par ligne de production et par module, mise à jour en place ; colonnes `is_active`, `valid_from`, `valid_to` ; clé unique `production_line_id + module` |
| 2026-10-28 | Filtrage des lignes | Les données sont filtrées par jointure sur la colonne `site` avec le référentiel DS (`left_semi`) ; l'existence d'une table ne suffit pas à considérer une ligne déployée |
| 2026-10-29 | D1 – Data digitalization | Provisoire : tous les batchs non supprimés sont comptés (cf. PO1) ; date de digitalisation = date de création (`created_at`) du 181e batch. Requête `sql/D1_data_digitalization.sql` validée : 14 lignes |
| 2026-10-29 | D2 – Metamodels | Provisoire : lignes ayant au moins 1 batch non supprimé, hors PI6, en attendant une source officielle des DE (cf. DE1) |
| 2026-10-29 | Méthode | Une requête source par KPI dans `sql/<KPI>.sql` (détail au grain fin + contrôle de la valeur), testée dans Databricks puis regroupée dans les notebooks |

## Notes techniques

- **Corrections à faire dans les notebooks One Pager :**
    - `02_load_data` : `{source_catalog}.public.batches` donne `public.public.batches`.
    - `03` / `04` utilisent `fact_monitoring`, `batches`, `pl`, `notes`, `trs_metadata`, alors que `02` charge `df_monitoring`, `df_batches`, `df_pl`, `df_notes`, `df_trs_metadata`.
    - `02_load_data` lit le monitoring dans `mal_maite_prd` au lieu de `mal_maite_bi_prd`.
    - Remplacer `unionByName` par un `UNION ALL` SQL (bloqué sur les clusters partagés Unity Catalog).
    - % batchs avec données SAP manquantes : jointure sur `batch_id` inexistant, jointure `inner` qui ignore les batchs sans résultat qualité, dénominateur manquant.
- **Référentiel des activations :** si un site est désactivé puis réactivé, la nouvelle période écrase l'ancienne (une seule ligne par site et par module). A faire évoluer si le cas se présente.
- **Données d'avant la mise en PROD :** elles pourront être écartées avec `date >= valid_from` une fois le référentiel disponible.
