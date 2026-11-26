-- Évolution TRS : clés de traduction des nouveaux textes du rapport Process Time Analyses.
-- Les mesures TITLE_* / TEXTE_* du modèle lisent common.translation selon la langue de l'utilisateur,
-- avec repli sur en-US, puis sur un texte par défaut en anglais.
-- À lancer en preprod, puis en PROD à la MEP (remplacer mal_maite_bi_preprd par mal_maite_bi_prd).
-- Relançable sans risque : une clé déjà présente est mise à jour, jamais dupliquée.

-- 1. Contrôle avant : colonnes de la table et codes de langue déjà utilisés
DESCRIBE TABLE mal_maite_bi_preprd.common.translation;

SELECT LanguageCode, COUNT(*) AS nb
FROM mal_maite_bi_preprd.common.translation
WHERE ReportCode = 'ProcessTimeAnalyses'
GROUP BY LanguageCode;

-- 2. Ajout ou mise à jour des clés
MERGE INTO mal_maite_bi_preprd.common.translation AS t
USING (
  SELECT * FROM VALUES
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE',        'fr-FR', 'Temps de process par batch'),
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE',        'en-US', 'Process times per batch'),
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE',        'ro-RO', 'Timpi de proces pe lot'),
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE',        'cs-CZ', 'Procesní časy podle šarže'),
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE_MACRO',  'fr-FR', 'Revue hebdomadaire de la ligne de production'),
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE_MACRO',  'en-US', 'Weekly production line review'),
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE_MACRO',  'ro-RO', 'Analiza săptămânală a liniei de producție'),
    ('ProcessTimeAnalyses', 'TITLE_SYNTHESE_MACRO',  'cs-CZ', 'Týdenní přehled výrobní linky'),
    ('ProcessTimeAnalyses', 'TITLE1_SYNTHESE_MACRO', 'fr-FR', 'Temps perdu'),
    ('ProcessTimeAnalyses', 'TITLE1_SYNTHESE_MACRO', 'en-US', 'Lost time'),
    ('ProcessTimeAnalyses', 'TITLE1_SYNTHESE_MACRO', 'ro-RO', 'Timp pierdut'),
    ('ProcessTimeAnalyses', 'TITLE1_SYNTHESE_MACRO', 'cs-CZ', 'Ztracený čas'),
    ('ProcessTimeAnalyses', 'TITLE2_SYNTHESE_MACRO', 'fr-FR', 'Notes de production - temps perdu - Top 10'),
    ('ProcessTimeAnalyses', 'TITLE2_SYNTHESE_MACRO', 'en-US', 'Production notes - lost time - Top 10'),
    ('ProcessTimeAnalyses', 'TITLE2_SYNTHESE_MACRO', 'ro-RO', 'Note de producție - timp pierdut - Top 10'),
    ('ProcessTimeAnalyses', 'TITLE2_SYNTHESE_MACRO', 'cs-CZ', 'Výrobní poznámky - ztracený čas - Top 10'),
    ('ProcessTimeAnalyses', 'TEXTE_CHOISIR_MESURE',  'fr-FR', 'Choisir une mesure pour afficher les indicateurs'),
    ('ProcessTimeAnalyses', 'TEXTE_CHOISIR_MESURE',  'en-US', 'Select a measure to display the indicators'),
    ('ProcessTimeAnalyses', 'TEXTE_CHOISIR_MESURE',  'ro-RO', 'Alegeți o măsură pentru a afișa indicatorii'),
    ('ProcessTimeAnalyses', 'TEXTE_CHOISIR_MESURE',  'cs-CZ', 'Vyberte měření pro zobrazení ukazatelů')
  AS s(ReportCode, TranslationKey, LanguageCode, TranslationText)
) AS s
ON  t.ReportCode = s.ReportCode
AND t.TranslationKey = s.TranslationKey
AND t.LanguageCode = s.LanguageCode
WHEN MATCHED THEN UPDATE SET t.TranslationText = s.TranslationText
WHEN NOT MATCHED THEN INSERT (ReportCode, TranslationKey, LanguageCode, TranslationText)
  VALUES (s.ReportCode, s.TranslationKey, s.LanguageCode, s.TranslationText);

-- 3. Contrôle après : 5 clés x 4 langues = 20 lignes attendues
SELECT TranslationKey, LanguageCode, TranslationText
FROM mal_maite_bi_preprd.common.translation
WHERE ReportCode = 'ProcessTimeAnalyses'
  AND TranslationKey IN ('TITLE_SYNTHESE', 'TITLE_SYNTHESE_MACRO', 'TITLE1_SYNTHESE_MACRO',
                         'TITLE2_SYNTHESE_MACRO', 'TEXTE_CHOISIR_MESURE')
ORDER BY TranslationKey, LanguageCode;
