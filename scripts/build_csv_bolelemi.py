"""Produit Baseline_BOLELEMI1.csv : les lignes baseline du seul site BOLELEMI1.

Reprend ce que fait Baseline.ipynb (depivotage, cle de jointure, resolution des
referentiels, mise en forme des colonnes), mais pour un site unique, afin de
permettre un chargement cible dans Databricks sans recharger les six autres.

Le chargement se fait avec Import_table_baseline_BOLELEMI1.ipynb, copie du
notebook de prod dont la cellule de TRUNCATE a ete retiree : le MERGE en mode
"upsert" insere les lignes manquantes sans toucher aux autres sites.

Usage : python scripts/build_csv_bolelemi.py
"""

from pathlib import Path

import pandas as pd

RACINE = Path(__file__).resolve().parent.parent
SOURCE = RACINE / "Baseline BOLELEMI1.xlsx"
SORTIE = RACINE / "Baseline_BOLELEMI1.csv"

# ---------------------------------------------------------------------------
# VALEURS PROVISOIRES - a remplacer par les identifiants reels avant chargement
# ---------------------------------------------------------------------------
# id_plant_production_line de BOLELEMI1 dans plants_production_lines (releve en base).
ID_SITE = 15
SITE = "BOLELEMI1"

# id_requirement_specification de 2RS et IBON, a creer dans
# requirement_specifications. Le referentiel connu va de 0 a 59 sans trou.
# Tant que les deux cahiers des charges n'existent pas, le script de prod leur
# attribuerait 99 a tous les deux, ce qui produirait deux lignes de meme cle
# metier par mois et ferait echouer le MERGE.
ID_SPECIFICATION = {"2RS": 60, "IBON": 61}

# Espece et variete dominantes, relevees sur les 617 couches du fichier source :
# 2RS -> TRAVELER (364 couches sur 494), IBON -> IBON (123 sur 123).
SPECY_VARIETE = {"2RS": ("2RP", "TRAVELER"), "IBON": ("2RP", "IBON")}

# Valeur par defaut du script de prod pour un cahier des charges inconnu du
# referentiel. La ligne monthly_average n'en est pas un : elle sert de repli.
ID_SPECIFICATION_DEFAUT = 99

ONGLETS = {
    "nb_individus": "nb_individus",
    "malt_yield_r2": "Baseline_malt_yield_r2",
    "malt_dry_yield": "Baseline_malt_dry_yield",
    "goods_weight": "Baseline_goods_weight",
    "goods_moisture": "Baseline_goods_moisture",
    "malt_moisture": "Baseline_malt_moisture",
    "electricity": "Baseline_electricity",
    "thermal": "Baseline_thermal",
    "FAN": "Baseline_FAN",
    "friabilite": "Baseline_friabilite",
    "coloration_EBC": "Baseline_coloration_EBC",
    "betaG": "Baseline_betaG",
    "quality": "Baseline_quality",
}

# Ordre impose par la table cible : Import_table_baseline s'arrete si les
# colonnes du fichier ne correspondent pas exactement a celles de la table.
COLONNES = [
    "id_specification", "specification", "id_site", "site", "Month",
    "goods_specy", "goods_variety", "nb_individus",
    "Baseline_malt_yield_r2", "Baseline_malt_dry_yield", "Baseline_goods_weight",
    "Baseline_goods_moisture", "Baseline_malt_moisture", "Baseline_electricity",
    "Baseline_thermal", "Baseline_FAN", "Baseline_friabilite",
    "Baseline_coloration_EBC", "Baseline_betaG", "Baseline_quality",
    "created_at", "updated_at", "deleted_at",
]


def depivoter(onglet, valeur):
    """Passe les mois de colonnes en lignes, comme le melt de Baseline.ipynb."""
    table = pd.read_excel(SOURCE, sheet_name=onglet)
    table = table.rename(columns={table.columns[0]: "specification"})
    long = table.melt(id_vars=["specification"], var_name="Month", value_name=valeur)
    long["key"] = long["specification"] + long["Month"].astype(str)
    return long


def main():
    baseline = depivoter("nb_individus", "nb_individus")
    for onglet, valeur in ONGLETS.items():
        if onglet == "nb_individus":
            continue
        baseline = baseline.merge(depivoter(onglet, valeur)[["key", valeur]], on="key", how="left")
    baseline = baseline.drop(columns="key")

    baseline["id_site"] = ID_SITE
    baseline["site"] = SITE
    baseline["id_specification"] = (
        baseline["specification"].map(ID_SPECIFICATION).fillna(ID_SPECIFICATION_DEFAUT).astype(int)
    )
    baseline["goods_specy"] = baseline["specification"].map(lambda s: SPECY_VARIETE.get(s, (None, None))[0])
    baseline["goods_variety"] = baseline["specification"].map(lambda s: SPECY_VARIETE.get(s, (None, None))[1])
    for horodatage in ("created_at", "updated_at", "deleted_at"):
        baseline[horodatage] = ""

    baseline = baseline[COLONNES].sort_values(["id_specification", "Month"])
    # Fins de ligne Windows, comme le Baseline.csv produit par le script de prod.
    baseline.to_csv(SORTIE, index=False, lineterminator="\r\n")

    doublons = baseline.duplicated(subset=["id_specification", "id_site", "Month"]).sum()
    print(f"{len(baseline)} lignes ecrites dans {SORTIE.name}")
    print(f"cahiers des charges : {', '.join(sorted(baseline['specification'].unique()))}")
    print(f"cle metier (id_specification, id_site, Month) : {doublons} doublon(s)")
    vides = [c for c in COLONNES if baseline[c].isna().all()]
    print(f"colonnes entierement vides : {', '.join(vides) if vides else 'aucune'}")


if __name__ == "__main__":
    main()
