"""Construit le fichier de travail BOLELEMI1, avec les formules Excel apparentes.

Equivalent des Baseline_<SITE>_3ANS_Sources_Batch.xlsx des six autres sites : il
montre le cheminement des 617 couches jusqu'aux moyennes par mois et cahier des
charges, en formules Excel plutot qu'en code, pour qu'un relecteur puisse
verifier les chiffres sans lire une ligne de Python.

Onglets produits :
  Data brutes    les 617 couches telles qu'extraites du fichier source
  Data filtrees  les couches retenues, avec le mois de fin et la cle de regroupement
  NB             le nombre de couches par mois x cahier des charges, rouge sous 5
  un onglet par parametre  la moyenne, avec le repli sur la moyenne du mois

Usage : python scripts/build_fichier_travail_bolelemi.py
"""

from pathlib import Path

import pandas as pd
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from build_baseline_bolelemi import (  # noqa: E402
    BANDE_RENDEMENT_R2,
    SEUIL_INDIVIDUS,
    filtrer_categories,
    lire_cache_tcd,
    SOURCE,
)

RACINE = Path(__file__).resolve().parent.parent
SORTIE = RACINE / "Baseline_BOLELEMI1_3ANS_Sources_Batch.xlsx"

# Onglet de sortie -> (champ du fichier source, libelle lisible)
MESURES = {
    "malt_yield_r2": ("Malt Yield R2", "Rendement humide R2"),
    "malt_dry_yield": ("R2 Dry", "Rendement sec"),
    "goods_weight": ("Goods Weight", "Poids d'orge"),
    "goods_moisture": ("Goods Moisture", "Humidite de l'orge"),
    "malt_moisture": ("Moisture Malt Quality", "Humidite du malt"),
    "FAN": ("FAN", "FAN"),
    "friabilite": ("Friability", "Friabilite"),
    "coloration_EBC": ("Color EBC", "Couleur EBC"),
    "betaG": ("Betaglucans", "Beta-glucanes"),
}

CONTEXTE = ["Batch", "Specifications", "Variety", "Start of production", "End of production"]
MOIS = list(range(1, 13))

ENTETE = PatternFill("solid", fgColor="1C5CAB")
ROUGE = PatternFill("solid", fgColor="FFC7CE")
GRIS = PatternFill("solid", fgColor="EAF2FC")


def met_en_forme_entete(ws, ligne=1):
    for cellule in ws[ligne]:
        if cellule.value is not None:
            cellule.fill = ENTETE
            cellule.font = Font(color="FFFFFF", bold=True)
            cellule.alignment = Alignment(horizontal="center")
    ws.freeze_panes = ws.cell(row=ligne + 1, column=1)


def ecrire_table(ws, df):
    ws.append(list(df.columns))
    for ligne in df.itertuples(index=False):
        ws.append(["" if pd.isna(v) else v for v in ligne])
    met_en_forme_entete(ws)
    for rang, colonne in enumerate(df.columns, start=1):
        largeur = max(len(str(colonne)) + 2, 12)
        ws.column_dimensions[get_column_letter(rang)].width = largeur


def bloc_par_casier(ws, cahiers, titre, formule, depart=2):
    """Ecrit une grille cahiers des charges x 12 mois remplie par `formule(ligne, mois)`."""
    ws.cell(row=depart, column=1, value=titre).font = Font(bold=True, color="1C5CAB")
    for mois in MOIS:
        c = ws.cell(row=depart, column=1 + mois, value=mois)
        c.font = Font(bold=True)
        c.alignment = Alignment(horizontal="center")
        c.fill = GRIS
    for decalage, cdc in enumerate(cahiers, start=1):
        ligne = depart + decalage
        ws.cell(row=ligne, column=1, value=cdc).font = Font(bold=True)
        for mois in MOIS:
            ws.cell(row=ligne, column=1 + mois, value=formule(cdc, mois)).number_format = "0.00"
    ws.column_dimensions["A"].width = 22
    for mois in MOIS:
        ws.column_dimensions[get_column_letter(1 + mois)].width = 11
    return depart + len(cahiers)


def main():
    brut = lire_cache_tcd(SOURCE)

    # --- Onglet "Data brutes" : le fichier source, colonnes utiles seulement.
    colonnes = CONTEXTE + [champ for champ, _ in MESURES.values()]
    brutes = brut[colonnes].copy()

    # --- Onglet "Data filtrees" : mois de fin, cle, et valeurs apres filtrage.
    filtrees = pd.DataFrame({
        "Batch": brut["Batch"],
        "Cahier des charges": brut["Specifications"],
        "Mois": pd.to_datetime(brut["End of production"]).dt.month,
        "Fin de production": pd.to_datetime(brut["End of production"]).dt.date,
    })
    filtrees["Cle"] = filtrees["Cahier des charges"] + "-" + filtrees["Mois"].astype(str)
    for onglet, (champ, _) in MESURES.items():
        valeurs = pd.to_numeric(brut[champ], errors="coerce")
        if onglet == "malt_yield_r2":
            bas, haut = BANDE_RENDEMENT_R2
            valeurs = valeurs.where(valeurs.between(bas, haut))
        filtrees[onglet] = filtrer_categories(valeurs).reindex(valeurs.index)

    cahiers = sorted(filtrees["Cahier des charges"].dropna().unique())
    derniere = len(filtrees) + 1
    col = {c: get_column_letter(i + 1) for i, c in enumerate(filtrees.columns)}
    plage = lambda c: f"'Data filtrees'!${col[c]}$2:${col[c]}${derniere}"  # noqa: E731
    cdc, mois_, ref = plage("Cahier des charges"), plage("Mois"), plage("malt_yield_r2")

    with pd.ExcelWriter(SORTIE, engine="openpyxl") as classeur:
        brutes.to_excel(classeur, sheet_name="Data brutes", index=False)
        filtrees.to_excel(classeur, sheet_name="Data filtrees", index=False)
        classeur.book.create_sheet("NB")
        for onglet in MESURES:
            classeur.book.create_sheet(onglet)
        wb = classeur.book

        for nom in ("Data brutes", "Data filtrees"):
            met_en_forme_entete(wb[nom])
            for rang in range(1, wb[nom].max_column + 1):
                wb[nom].column_dimensions[get_column_letter(rang)].width = 15

        # NB : nombre de couches par casier, sur la mesure de reference.
        ws = wb["NB"]
        ws["A1"] = "Nombre de couches par cahier des charges et par mois de fin de production"
        ws["A1"].font = Font(bold=True, size=12, color="1C5CAB")
        fin = bloc_par_casier(ws, cahiers, "NB",
            lambda c, m: f'=COUNTIFS({cdc},$A{{ligne}},{mois_},{m},{ref},"<>")'.replace(
                "{ligne}", str(3 + cahiers.index(c))))
        ws.conditional_formatting.add(
            f"B3:M{fin}", CellIsRule(operator="lessThan", formula=["5"], fill=ROUGE))
        ws[f"A{fin + 2}"] = (f"Rouge = moins de {SEUIL_INDIVIDUS} couches : la moyenne du casier "
                             "n'est pas retenue, on prend celle du mois entier.")
        ws[f"A{fin + 2}"].font = Font(italic=True)

        # Un onglet par mesure. Chaque mesure a son propre comptage : toutes ne sont
        # pas relevees sur toutes les couches, donc le seuil de 5 s'apprecie mesure
        # par mesure et non sur un comptage unique.
        for onglet, (champ, libelle) in MESURES.items():
            ws = wb[onglet]
            valeurs = plage(onglet)
            ws["A1"] = f"{libelle} — nombre de couches, puis moyenne"
            ws["A1"].font = Font(bold=True, size=12, color="1C5CAB")

            fin_nb = bloc_par_casier(ws, cahiers, "NB",
                lambda c, m, v=valeurs: f'=COUNTIFS({cdc},$A{3 + cahiers.index(c)},{mois_},{m},{v},"<>")')
            ws.conditional_formatting.add(
                f"B3:M{fin_nb}", CellIsRule(operator="lessThan", formula=["5"], fill=ROUGE))

            def moyenne(c, m, valeurs=valeurs):
                ligne = 3 + cahiers.index(c)
                propre = f"AVERAGEIFS({valeurs},{cdc},$A{ligne},{mois_},{m})"
                du_mois = f"AVERAGEIFS({valeurs},{mois_},{m})"
                return f"=IF({get_column_letter(1 + m)}{ligne}>={SEUIL_INDIVIDUS},{propre},{du_mois})"

            fin = bloc_par_casier(ws, cahiers, "MOYENNE", moyenne, depart=fin_nb + 2)
            ligne = fin + 1
            ws.cell(row=ligne, column=1, value="monthly_average").font = Font(bold=True, italic=True)
            for m in MOIS:
                c = ws.cell(row=ligne, column=1 + m, value=f"=AVERAGEIFS({valeurs},{mois_},{m})")
                c.number_format = "0.00"
                c.fill = GRIS
            ws[f"A{ligne + 2}"] = ("Au moins 5 couches : moyenne du cahier des charges. "
                                   "En dessous : moyenne du mois, tous cahiers des charges confondus.")
            ws[f"A{ligne + 2}"].font = Font(italic=True)

    print(f"{SORTIE.name} ecrit")
    print(f"   Data brutes    : {len(brutes)} couches, {len(brutes.columns)} colonnes")
    print(f"   Data filtrees  : {len(filtrees)} couches, mois de fin et cle de regroupement")
    print(f"   NB             : {len(cahiers)} cahiers des charges x 12 mois, en formules COUNTIFS")
    print(f"   {len(MESURES)} onglets de moyennes en formules AVERAGEIFS avec le repli a {SEUIL_INDIVIDUS}")


if __name__ == "__main__":
    main()
