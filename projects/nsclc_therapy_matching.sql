-- File: nsclc_therapy_matching.sql 
-- Project: NSCLC Targeted Therapy Matching

/*
Goal: Check if Stage IV NSCLC patients with certain mutations get the right NCCN-recommended 1st line drug.

How:
1. Get Stage IV NSCLC patients (Dx + Staging tables).
2. Find their biomarker results (EGFR, ALK, ROS1, BRAF etc. from Biomarkers).
3. Find their 1st line drugs (Medications table, treatment_line = 1).
4. Use CASE WHEN (based on NCCN rules) to see if biomarker matches drug.
5. Label the match status.
*/

WITH RelevantPatients AS (
    -- Find Stage IV NSCLC patients
    SELECT
        p.patient_id,
        p.first_name,
        p.last_name,
        s.overall_stage,
        dx.diagnosis_date
    FROM Patients p
    JOIN Diagnoses dx ON p.patient_id = dx.patient_id
    JOIN Staging s ON dx.diagnosis_id = s.diagnosis_id
    WHERE
        dx.icd10_code LIKE 'C34.%' -- Lung ca
        AND dx.histology = 'Non-Small Cell Carcinoma' -- NSCLC
        AND s.overall_stage LIKE 'IV%' -- Stage 4
),
PatientBiomarkers AS (
    -- Get relevant biomarker results for these patients
    SELECT
        patient_id,
        marker_name,
        marker_result,
        test_date
    FROM Biomarkers
    WHERE marker_name IN ('EGFR Mutation', 'ALK Fusion', 'ROS1 Fusion', 'BRAF Mutation', 'MET Mutation', 'RET Fusion', 'KRAS Mutation')
      AND patient_id IN (SELECT patient_id FROM RelevantPatients)
),
FirstLineTherapy AS (
    -- Get their first line therapy (if any)
    SELECT
        patient_id,
        medication_name,
        drug_class,
        start_date
    FROM Medications
    WHERE treatment_line = 1
      AND status IN ('Active', 'Completed') -- Started Tx
      AND patient_id IN (SELECT patient_id FROM RelevantPatients)
)
-- Final check: combine patient info, biomarkers, 1st line tx, and check match
SELECT
    rp.patient_id,
    rp.first_name,
    rp.last_name,
    pb_egfr.marker_result AS egfr_mutation,
    pb_alk.marker_result AS alk_fusion,
    pb_ros1.marker_result AS ros1_fusion,
    pb_braf.marker_result AS braf_mutation,
    flt.medication_name AS first_line_therapy,
    flt.drug_class AS first_line_drug_class,
    flt.start_date AS first_line_start,

    -- Matching Logic (Simplified NCCN rules)
    CASE
        -- EGFR?
        WHEN pb_egfr.marker_result IN ('Exon 19 Deletion', 'L858R')
             AND flt.medication_name IN ('Osimertinib', 'Gefitinib', 'Erlotinib', 'Afatinib', 'Dacomitinib')
             THEN 'Matched (EGFR)'
        WHEN pb_egfr.marker_result IN ('Exon 19 Deletion', 'L858R')
             AND flt.medication_name IS NOT NULL -- Got *some* drug, but not the right one
             THEN 'Mismatch (EGFR+ / Non-EGFR TKI)'
        WHEN pb_egfr.marker_result IN ('Exon 19 Deletion', 'L858R')
             AND flt.medication_name IS NULL -- No 1st line drug recorded
             THEN 'Potential Mismatch (EGFR+ / No Line 1 Tx)'

        -- ALK?
        WHEN pb_alk.marker_result = 'Positive'
             AND flt.medication_name IN ('Alectinib', 'Brigatinib', 'Lorlatinib', 'Ceritinib', 'Crizotinib')
             THEN 'Matched (ALK)'
        WHEN pb_alk.marker_result = 'Positive' AND flt.medication_name IS NOT NULL THEN 'Mismatch (ALK+ / Non-ALK TKI)'
        WHEN pb_alk.marker_result = 'Positive' AND flt.medication_name IS NULL THEN 'Potential Mismatch (ALK+ / No Line 1 Tx)'

        -- ROS1?
        WHEN pb_ros1.marker_result = 'Positive'
             AND flt.medication_name IN ('Crizotinib', 'Entrectinib', 'Repotrectinib')
             THEN 'Matched (ROS1)'
        WHEN pb_ros1.marker_result = 'Positive' AND flt.medication_name IS NOT NULL THEN 'Mismatch (ROS1+ / Non-ROS1 TKI)'
        WHEN pb_ros1.marker_result = 'Positive' AND flt.medication_name IS NULL THEN 'Potential Mismatch (ROS1+ / No Line 1 Tx)'

         -- BRAF V600E?
        WHEN pb_braf.marker_result = 'V600E'
             AND flt.medication_name IN ('Dabrafenib+Trametinib') -- Combo therapy
             THEN 'Matched (BRAF V600E)'
        WHEN pb_braf.marker_result = 'V600E' AND flt.medication_name IS NOT NULL THEN 'Mismatch (BRAF V600E+ / Other Tx)'
        WHEN pb_braf.marker_result = 'V600E' AND flt.medication_name IS NULL THEN 'Potential Mismatch (BRAF V600E+ / No Line 1 Tx)'

        -- No known actionable driver? Check if Chemo/Immuno given (usually appropriate)
        WHEN (pb_egfr.marker_result IS NULL OR pb_egfr.marker_result = 'Wild Type')
         AND (pb_alk.marker_result IS NULL OR pb_alk.marker_result = 'Negative')
         AND (pb_ros1.marker_result IS NULL OR pb_ros1.marker_result = 'Negative')
         AND (pb_braf.marker_result IS NULL OR pb_braf.marker_result NOT LIKE 'V600E%')
         AND flt.drug_class IN ('Chemotherapy', 'Immunotherapy')
            THEN 'Appropriate Non-Targeted Tx (No Actionable Biomarker)'
         -- No known actionable driver AND no 1st line Tx?
         WHEN (pb_egfr.marker_result IS NULL OR pb_egfr.marker_result = 'Wild Type') -- etc for all markers
            AND flt.medication_name IS NULL
            THEN 'No Actionable Biomarker / No Line 1 Tx'

        ELSE 'Other/Unknown Scenario' -- Catch-all
    END AS therapy_matching_status

FROM RelevantPatients rp
LEFT JOIN PatientBiomarkers pb_egfr ON rp.patient_id = pb_egfr.patient_id AND pb_egfr.marker_name = 'EGFR Mutation'
LEFT JOIN PatientBiomarkers pb_alk ON rp.patient_id = pb_alk.patient_id AND pb_alk.marker_name = 'ALK Fusion'
LEFT JOIN PatientBiomarkers pb_ros1 ON rp.patient_id = pb_ros1.patient_id AND pb_ros1.marker_name = 'ROS1 Fusion' -- May be NULL
LEFT JOIN PatientBiomarkers pb_braf ON rp.patient_id = pb_braf.patient_id AND pb_braf.marker_name = 'BRAF Mutation' -- May be NULL
LEFT JOIN FirstLineTherapy flt ON rp.patient_id = flt.patient_id -- May be NULL (no 1st line Tx)
ORDER BY rp.patient_id;