"""Construction du fichier d'entree "Baseline BOLELEMI.xlsx" a partir de BOL_Baseline_04082026.xlsx.

Le fichier source est un classeur de deux tableaux croises dynamiques. Les donnees
brutes ne sont pas sur la feuille : elles vivent dans le cache du TCD
(xl/pivotCache/pivotCacheRecords1.xml), soit 617 couches de la ligne BOLELEMI1.
Ce script les extrait, applique la methode de filtrage decrite dans le Confluence,
puis ecrit le classeur au format attendu par Baseline.ipynb : un onglet par
parametre, les cahiers des charges en lignes, les mois 1 a 12 en colonnes.

Usage : python scripts/build_baseline_bolelemi.py
"""

import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

import pandas as pd

RACINE = Path(__file__).resolve().parent.parent
SOURCE = RACINE / "BOL_Baseline_04082026.xlsx"
SORTIE = RACINE / "Baseline BOLELEMI1.xlsx"

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"

# --- Parametres de la methode (cf. page Confluence "Objectif de la Baseline") ---

# En dessous de ce nombre de couches, la case Mois x Cahier des charges bascule
# sur la moyenne du mois tous cahiers des charges confondus.
SEUIL_INDIVIDUS = 5

# Categorisation des valeurs pour ecarter les extremes : on arrondit valeur / PAS,
# on garde le bloc contigu de categories autour du mode, et on coupe des qu'une
# categorie tombe sous SEUIL_CATEGORIE fois l'effectif du mode.
PAS_CATEGORIE = 50
SEUIL_CATEGORIE = 0.25

# Seule bande explicitement chiffree dans la doc ("on garde les rendements
# entre 80% et 87%"). Les autres parametres ne passent que par la categorisation.
BANDE_RENDEMENT_R2 = (80, 87)

# Onglet du classeur -> champ du cache du TCD. Les trois onglets a None sont
# crees vides : les donnees correspondantes ne sont pas dans le fichier source.
PARAMETRES = {
    "malt_yield_r2": "Malt Yield R2",
    "malt_dry_yield": "R2 Dry",
    "goods_weight": "Goods Weight",
    "goods_moisture": "Goods Moisture",
    "malt_moisture": "Moisture Malt Quality",
    "electricity": None,
    "thermal": None,
    "FAN": "FAN",
    "friabilite": "Friability",
    "coloration_EBC": "Color EBC",
    "betaG": "Betaglucans",
    "quality": None,
}

MOIS = list(range(1, 13))


def lire_cache_tcd(chemin):
    """Retourne les enregistrements du cache du tableau croise dynamique."""
    with zipfile.ZipFile(chemin) as archive:
        definition = ET.fromstring(archive.read("xl/pivotCache/pivotCacheDefinition1.xml"))
        enregistrements = ET.fromstring(archive.read("xl/pivotCache/pivotCacheRecords1.xml"))

    champs_xml = definition.find(NS + "cacheFields")
    champs = [champ.get("name") for champ in champs_xml]
    partages = {}
    for rang, champ in enumerate(champs_xml):
        items = champ.find(NS + "sharedItems")
        if items is not None and len(items):
            partages[rang] = [item.get("v") for item in items]

    lignes = []
    for enregistrement in enregistrements:
        ligne = {}
        for rang, cellule in enumerate(enregistrement):
            type_cellule = cellule.tag.replace(NS, "")
            if type_cellule == "m":
                valeur = None
            elif type_cellule == "x":
                valeur = partages[rang][int(cellule.get("v"))]
            else:
                valeur = cellule.get("v")
            ligne[champs[rang]] = valeur
        lignes.append(ligne)
    return pd.DataFrame(lignes)


def filtrer_categories(valeurs):
    """Ecarte les valeurs extremes par categorisation (valeur / PAS_CATEGORIE).

    On garde le bloc contigu de categories autour du mode et on coupe des qu'une
    categorie passe sous le seuil, meme si une categorie plus lointaine remonte.
    """
    valeurs = valeurs.dropna()
    if valeurs.empty:
        return valeurs

    categories = (valeurs / PAS_CATEGORIE).round().astype(int)
    effectifs = categories.value_counts().sort_index()
    if len(effectifs) == 1:
        return valeurs

    mode = effectifs.idxmax()
    plancher = effectifs.max() * SEUIL_CATEGORIE

    gardees = {mode}
    for sens in (-1, 1):
        categorie = mode + sens
        while categorie in effectifs.index and effectifs[categorie] >= plancher:
            gardees.add(categorie)
            categorie += sens

    return valeurs[categories.isin(gardees)]


def preparer(df):
    """Normalise le cache : mois de fin de production, cahier des charges, valeurs filtrees."""
    prepare = pd.DataFrame(
        {
            "specification": df["Specifications"],
            # import_gains joint sur MONTH(date_fin_production) : c'est donc la fin
            # de production qui fait foi, pas le debut retenu par les TCD du fichier.
            "Month": pd.to_datetime(df["End of production"]).dt.month,
        }
    )

    for onglet, champ in PARAMETRES.items():
        if champ is None:
            prepare[onglet] = pd.NA
            continue
        valeurs = pd.to_numeric(df[champ], errors="coerce")
        if onglet == "malt_yield_r2":
            bas, haut = BANDE_RENDEMENT_R2
            valeurs = valeurs.where(valeurs.between(bas, haut))
        prepare[onglet] = filtrer_categories(valeurs).reindex(valeurs.index)

    return prepare


def moyennes(prepare, onglet, cahiers):
    """Moyenne par cahier des charges x mois, avec repli sur la moyenne du mois."""
    valeurs = prepare[["specification", "Month", onglet]].dropna(subset=[onglet])

    par_cdc = valeurs.groupby(["specification", "Month"])[onglet].agg(["mean", "count"])
    par_mois = valeurs.groupby("Month")[onglet].mean()

    table = pd.DataFrame(index=cahiers + ["monthly_average"], columns=MOIS, dtype=float)
    for cdc in cahiers:
        for mois in MOIS:
            cellule = par_cdc.loc[(cdc, mois)] if (cdc, mois) in par_cdc.index else None
            if cellule is not None and cellule["count"] >= SEUIL_INDIVIDUS:
                table.loc[cdc, mois] = cellule["mean"]
            else:
                table.loc[cdc, mois] = par_mois.get(mois, pd.NA)
    for mois in MOIS:
        table.loc["monthly_average", mois] = par_mois.get(mois, pd.NA)
    return table


def effectifs(prepare, cahiers):
    """Onglet nb_individus : couches retenues par cahier des charges x mois."""
    reference = prepare.dropna(subset=["malt_yield_r2"])
    comptes = reference.groupby(["specification", "Month"]).size()

    table = pd.DataFrame(0, index=cahiers + ["monthly_average"], columns=MOIS, dtype=int)
    for cdc in cahiers:
        for mois in MOIS:
            table.loc[cdc, mois] = int(comptes.get((cdc, mois), 0))
    for mois in MOIS:
        table.loc["monthly_average", mois] = int(table.loc[cahiers, mois].sum())
    return table


def main():
    brut = lire_cache_tcd(SOURCE)
    lignes = sorted(brut["Production line"].dropna().unique())
    print(f"{len(brut)} couches lues dans le cache du TCD, ligne(s) : {', '.join(lignes)}")

    prepare = preparer(brut)
    cahiers = sorted(prepare["specification"].dropna().unique())
    print(f"cahiers des charges : {', '.join(cahiers)}")

    tables = {"nb_individus": effectifs(prepare, cahiers)}
    for onglet, champ in PARAMETRES.items():
        tables[onglet] = moyennes(prepare, onglet, cahiers)
        if champ is None:
            print(f"  {onglet:<16} onglet cree vide (donnee absente du fichier source)")
        else:
            retenues = int(prepare[onglet].notna().sum())
            ecartees = int(pd.to_numeric(brut[champ], errors="coerce").notna().sum()) - retenues
            print(f"  {onglet:<16} {retenues:>3} couches retenues, {ecartees:>3} ecartees par le filtrage")

    with pd.ExcelWriter(SORTIE, engine="openpyxl") as classeur:
        for onglet, table in tables.items():
            table.index.name = "specification"
            table.to_excel(classeur, sheet_name=onglet)

    print(f"\n-> {SORTIE.name} ecrit ({len(tables)} onglets)")


if __name__ == "__main__":
    main()
