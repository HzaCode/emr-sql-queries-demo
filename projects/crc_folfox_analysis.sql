-- File: crc_folfox_analysis.sql 
-- Project: CRC Chemo Regimen Analysis


/*
Clinical Question: Can we identify Colorectal Cancer (CRC) patients who received the FOLFOX
chemotherapy regimen based on their medication administration records, and estimate the
number of cycles they completed?

Logic: Queries actual tables created by schema.sql and populated from CSVs.
1. Identify CRC patients from Diagnoses.
2. Select chemotherapy administrations for these patients from MedicationAdministrations.
3. Group administrations by patient and date.
4. Identify date groups where 'Leucovorin', '5-FU', and 'Oxaliplatin' were co-administered using GROUP_CONCAT (without DISTINCT for compatibility).
5. Assign a cycle number based on the sequence and timing (~14 days) of these FOLFOX administrations using LAG().
*/

WITH CRCPatients AS (
    SELECT DISTINCT patient_id
    FROM Diagnoses
    WHERE icd10_code LIKE 'C18.%' OR icd10_code LIKE 'C19.%' OR icd10_code LIKE 'C20.%'
),
ChemoAdmins AS (
    SELECT
        ma.patient_id,
        ma.medication_name,
        DATE(ma.administration_date) AS admin_date
    FROM MedicationAdministrations ma
    JOIN CRCPatients crc ON ma.patient_id = crc.patient_id
    WHERE ma.medication_name IN ('Leucovorin', '5-FU', 'Oxaliplatin', 'Irinotecan') -- Include all potential components
),
RegimenDayCheck AS (
    -- Aggregate drugs given on the same day per patient
    SELECT
        patient_id,
        admin_date,
        -- FINAL FIX: Removed DISTINCT entirely for maximum compatibility.
        GROUP_CONCAT(medication_name, '|') AS daily_drugs_combo
    FROM ChemoAdmins
    GROUP BY patient_id, admin_date
),
FoxStartDates AS (
     -- Identify dates where the FOLFOX combination was likely administered
     SELECT patient_id, admin_date
     FROM RegimenDayCheck
     -- Check if the required drugs are present in the concatenated string
     WHERE INSTR(daily_drugs_combo, '5-FU') > 0
       AND INSTR(daily_drugs_combo, 'Leucovorin') > 0
       AND INSTR(daily_drugs_combo, 'Oxaliplatin') > 0
       -- Exclude if Irinotecan also present
       AND INSTR(daily_drugs_combo, 'Irinotecan') = 0
),
CycleCalculation AS (
    SELECT
        patient_id,
        admin_date AS cycle_start_est_date,
        LAG(admin_date, 1) OVER (PARTITION BY patient_id ORDER BY admin_date) AS prev_cycle_start_est_date,
        -- NOTE: Date difference calculation varies by SQL dialect. JULIANDAY is common in SQLite.
        JULIANDAY(admin_date) - JULIANDAY(LAG(admin_date, 1) OVER (PARTITION BY patient_id ORDER BY admin_date)) AS days_since_last_cycle
    FROM FoxStartDates
)
-- Final Output: Show identified FOLFOX administrations and estimated cycle numbers
SELECT
    cyc.patient_id,
    p.first_name,
    p.last_name,
    cyc.cycle_start_est_date,
    cyc.days_since_last_cycle,
    ROW_NUMBER() OVER (PARTITION BY cyc.patient_id ORDER BY cyc.cycle_start_est_date) AS cycle_number_simple_est
FROM CycleCalculation cyc
JOIN Patients p ON cyc.patient_id = p.patient_id -- Need to join back to Patients to get names
ORDER BY cyc.patient_id, cyc.cycle_start_est_date;