# One Pager Maltimize - Catalogue des KPI

Référentiel des KPI du dashboard One Page : règle de gestion (issue de la spec
`Spec Onepage Dashboard Maltimize_VF.pptx`), source de données proposée et
statut de validation. A mettre à jour au fil des décisions.

Légende statut :
- ✅ source identifiée et règle claire
- 🟡 source proposée, à valider (DA / DE / DS / PO)
- 🔴 bloqué : source non disponible

## Décisions transverses

| # | Sujet | Proposition | Statut |
|---|---|---|---|
| T1 | Grain du filtre "sites" | Ligne de production (`plants_production_lines.common_code` : RO1, NG1...) | 🟡 |
| T2 | Date de référence pour le filtre date | A fixer par KPI (colonne "Date de référence" ci-dessous) | 🟡 |
| T3 | Pithiviers (PI6) | Exclu de tous les KPI, ou seulement avant une date ? | 🟡 |
| T4 | Comparaison | Période N (slicer) vs N-1 (Previous period / Same period last year / Custom) | ✅ |
| T5 | Langue | Libellés du rapport en anglais | ✅ |

## 1. Production Line Deployment (valeur à date)

| ID | KPI | Règle de gestion | Source proposée | Date de référence | Statut | Questions |
|---|---|---|---|---|---|---|
| D1 | Data digitalization | Nb de lignes dont les données manuelles ont été intégrées en masse : > 180 batchs | PG `batches` (deleted = false) + `plants_production_lines`. **Décision provisoire : tous les batchs**, quel que soit leur statut | `created_at` du 181e batch | ✅ validé (14 lignes) | Tous les batchs ou seulement les terminés : à valider avec le PO (PO1) |
| D2 | Metamodels | Nb de lignes dont le metamodel est en RUN | Référentiel des activations DS, module `metamodel` (`sql/D2_metamodels.sql`) | `valid_from` / `valid_to` | ⏳ | En attente de la table DS |
| D3 | AI Recommendations (T0 Target) | Lignes où la feature de recommandations IA tourne en PROD | Référentiel des activations DS, module `recommendations` (`sql/D3_ai_recommendations.sql`) | `valid_from` / `valid_to` | ⏳ | En attente de la table DS |
| D4 | Time Tracking & Production Notes | Lignes avec config note de production ET config TRS déployées | PG `batches_notes` (au moins une note) + `mal_maite_common_prd.gold.trs_metadata` (`sql/D4_time_tracking_production_notes.sql`) | Date de la 1re note de production | 🟡 en test | |

## 2. User Activity (30 derniers jours + tendance)

| ID | KPI | Règle de gestion | Source proposée | Date de référence | Statut | Questions |
|---|---|---|---|---|---|---|
| U1 | Maltimize unique users | Utilisateurs uniques de l'application sur 30 jours | Auth0 (non exposé aujourd'hui) | Date de connexion | 🔴 | Export Auth0 vers une table Databricks : coût / faisabilité DE |
| U2 | Dashboards PowerBI unique users | Utilisateurs uniques des dashboards PBI (embarqués ou non) + part directe vs embarquée | Journal d'activité Power BI (API Admin) ou Usage Metrics du workspace | Date de consultation | 🟡 | Si l'embarqué est en mode "app owns data", les utilisateurs Maltimize ne sont pas identifiables côté PBI |

## 3. Data Quality & Completeness (30 derniers jours + tendance)

| ID | KPI | Règle de gestion | Source proposée | Date de référence | Statut | Questions |
|---|---|---|---|---|---|---|
| Q1 | Uncaptured Aveva data | Recos indisponibles pour capteurs défaillants / chute de tags ÷ total recos | Dashboard monitoring, page Success & Failure Details : mesure `Evolution_echec_auto` (`flg_echec` avec `has_auto_value = 1` et `has_manual_value = 0`) ÷ `recos_attendues`. Table `mal_maite_bi_{env}.recommendations_monitoring.fact_monitoring_auto_manual_entries` | `date_creation_reco` | 🟡 | Le notebook utilise une autre règle (`succes_echec = 'ECHEC'` et `flg_auto = 1` et `id_alerting = 1`) : laquelle garder ? Inclure aussi les échecs auto + manuels dus au tag drop ? |
| Q2 | Missing manual entries | Recos indisponibles pour données manuelles (manuelles seules + manuelles et auto) ÷ total recos | Dashboard monitoring : `Evolution_echec_manual` + `Evolution_echec_manual_auto` (soit `flg_echec` avec `has_manual_value = 1`) ÷ `recos_attendues` | `date_creation_reco` | ✅ | |
| Q3 | % Batches with missing SAP mandatory data | Batchs terminés avec au moins 1 donnée SAP obligatoire manquante ÷ batchs terminés | PG `batches` + `parameters_batch_status` (code = `finished`) ; DE `mal_maite_{ligne}_{env}.gold.malt_quality_results` ; liste des 5 critères filtrée par ligne via DS `mal_maite_{env}.{ligne}.features` | Date de fin du batch | 🟡 | Clé de jointure = `fabrication_order` ? Batch sans aucun résultat qualité = manquant ? Statut "undefined" des batchs historiques ? Liste des lignes (Buzau, Burton, Bolelemi...) |
| Q4 | Mandatory SAP data missing | Nb de données SAP obligatoires manquantes ÷ nb total de données obligatoires (batchs terminés) | Mêmes sources que Q3 | Date de fin du batch | 🟡 | Idem Q3 ; données hors qualité (erreurs de saisie) : à voir DE |

## 4. AI Recommendation (30 derniers jours + tendance)

| ID | KPI | Règle de gestion | Source proposée | Date de référence | Statut | Questions |
|---|---|---|---|---|---|---|
| R1 | % Available recommendations | Déjà calculé dans le dashboard Overview | Deux définitions existent : (a) Suivi des recommandations `%reco_disponibles` = somme(`total`) ÷ somme(`nb_reco_opti`) dans `mal_maite_bi_{env}.recommendations.fact_batches_reco` ; (b) Dashboard monitoring : somme(`flg_succes`) ÷ `recos_attendues` | `planned_date` (a) ou `date_creation_reco` (b) | 🟡 | Laquelle correspond au dashboard Overview cité dans la spec ? |
| R2 | % Declared applied recommendations | Déjà calculé (calculation of applied recommendations) | Suivi des recommandations, table `mal_maite_bi_{env}.recommendations.fact_batches_calculation_date_reco` : `% reco appliquées sur total reçu` (`acceptee_et_appliquee` ÷ `total`) ou `% reco appliquées sur Évaluée` (÷ `evaluee`) | `calculation_date` | 🟡 | Quel dénominateur : total reçu ou évaluées ? |
| R3 | % Spec-compliant AI recommendations | Recos dont les 5 critères qualité prédits sont dans les bornes IA ÷ recos disponibles | `fact_delta_quality_realized_recommended` (dashboard Batch overview) | Date de calcul de la reco | 🟡 | Emplacement exact de la table (catalogue / schéma) |
| R4 | % Spec-compliant output batches | Batchs terminés avec les 5 qualités réelles dans les bornes IA ÷ batchs terminés | `fact_delta_quality_realized_recommended` ou `malt_quality_results` + bornes du cahier des charges | Date de fin du batch | 🟡 | Batchs sans qualité ou avec qualité partielle : exclus ou non conformes ? |
| R5 | Average AI malt yield (R2) | Moyenne du R2 prédit : 1re reco de trempe par batch (Buzau : 1re reco de germination), batchs terminés | Valeur prédite de R2 dans les tables de reco DS | Date de fin du batch | 🟡 | Table contenant le R2 prédit par reco |
| R6 | Average Real malt yield (R2) | Moyenne du R2 réel, batchs terminés avec R2 disponible | Paramètre `malt_yield_r2` ("R2 humide (%)") : déjà dans le projet Energy (`fact_batch_measures` + `dim_report_parameter_mapping`) | Date de fin du batch | ✅ | |

## 5. Process Time & Production Notes (30 derniers jours + tendance)

| ID | KPI | Règle de gestion | Source proposée | Date de référence | Statut | Questions |
|---|---|---|---|---|---|---|
| P1 | Process time dashboard (Views / Users / Days / View trend) | Consultations des dashboards embarqués | Usage Metrics Power BI du rapport Process Time Analyses (même source que U2) | Date de consultation | 🟡 | La spec demande si Days et Views sont utiles |
| P2 | Gap Target vs actual cycle time | Moyenne des écarts temps de cycle réel vs cible | `mal_maite_bi_{env}.process_time_analyses.fact_process_time_analyses` : `delta_target_business` (cycle time, hors outliers) ; mesures existantes du modèle TRS | `date_fin` | 🟡 | Cohérence de la moyenne tous sites confondus |
| P3 | Production notes | Nb de notes de production sur la période | `mal_maite_bi_{env}.process_time_analyses.fact_batch_note` (ou PG `batches_notes`) | `event_date` ou `date_saisie` ? | 🟡 | Quelle date ? |
| P4 | Production notes impacts | Répartition des notes par type d'impact (Temps, Qualité, Energie...) | `fact_batch_note.impact` | Idem P3 | 🟡 | Les libellés correspondent-ils à ceux de Metabase ? |

## Hors périmètre IDF (information MS)

| ID | Information | Source | Statut |
|---|---|---|---|
| X1 | Cybersecurity (lignes avec règles cyber implémentées) | Saisie MS (fichier de référence) | 🔴 |
| X2 | AVEVA (infra de collecte installée) | Saisie MS (fichier de référence) | 🔴 |
| X3 | Dataplatform & Historization | A voir DE : automatisable ? | 🔴 |

## Questions à clarifier

Les questions ouvertes (PO, DE, DS, BI) et les décisions prises sont suivies dans `notes_et_questions.md`.
