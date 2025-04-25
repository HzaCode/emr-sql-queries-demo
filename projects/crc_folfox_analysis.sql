-- File: crc_folfox_analysis.sql 
-- Project: CRC Chemo Regimen Analysis


/*
Goal: Find CRC patients who got FOLFOX and estimate completed cycles.

How:
1. Find CRC patients (Diagnoses).
2. Get their chemo administrations (MedicationAdministrations).
3. Group chemo drugs given on the same day for each patient.
4. Find days where Leucovorin + 5-FU + Oxaliplatin were given together (using GROUP_CONCAT).
5. Estimate cycle number based on sequence and ~14 day intervals using LAG().
*/

WITH CRCPatients AS (
    -- Get patient IDs for Colorectal Cancer
    SELECT DISTINCT patient_id
    FROM Diagnoses
    WHERE icd10_code LIKE 'C18.%' OR icd10_code LIKE 'C19.%' OR icd10_code LIKE 'C20.%' -- CRC codes
),
ChemoAdmins AS (
    -- Get chemo administration records for these patients
    SELECT
        ma.patient_id,
        ma.medication_name,
        DATE(ma.administration_date) AS admin_date -- Just need the date part
    FROM MedicationAdministrations ma
    JOIN CRCPatients crc ON ma.patient_id = crc.patient_id
    WHERE ma.medication_name IN ('Leucovorin', '5-FU', 'Oxaliplatin', 'Irinotecan') -- FOLFOX components + Irinotecan (for FOLFIRI exclusion)
),
RegimenDayCheck AS (
    -- Combine drugs given on the same day into a single string
    SELECT
        patient_id,
        admin_date,
        -- Using GROUP_CONCAT without DISTINCT for compatibility
        GROUP_CONCAT(medication_name, '|') AS daily_drugs_combo
    FROM ChemoAdmins
    GROUP BY patient_id, admin_date
),
FoxStartDates AS (
     -- Find dates where the FOLFOX combo was likely given (L+F+O, but no I)
     SELECT patient_id, admin_date
     FROM RegimenDayCheck
     WHERE INSTR(daily_drugs_combo, '5-FU') > 0
       AND INSTR(daily_drugs_combo, 'Leucovorin') > 0
       AND INSTR(daily_drugs_combo, 'Oxaliplatin') > 0
       AND INSTR(daily_drugs_combo, 'Irinotecan') = 0 -- Exclude FOLFIRI
),
CycleCalculation AS (
    -- Calculate days between likely FOLFOX start dates
    SELECT
        patient_id,
        admin_date AS cycle_start_est_date,
        LAG(admin_date, 1) OVER (PARTITION BY patient_id ORDER BY admin_date) AS prev_cycle_start_est_date,
        -- JULIANDAY works for SQLite date diff; other DBs use different functions
        JULIANDAY(admin_date) - JULIANDAY(LAG(admin_date, 1) OVER (PARTITION BY patient_id ORDER BY admin_date)) AS days_since_last_cycle
    FROM FoxStartDates
)
-- Final Output: Show the estimated FOLFOX cycles
SELECT
    cyc.patient_id,
    p.first_name,
    p.last_name,
    cyc.cycle_start_est_date,
    cyc.days_since_last_cycle,
    -- Simple cycle count based on order of estimated start dates
    ROW_NUMBER() OVER (PARTITION BY cyc.patient_id ORDER BY cyc.cycle_start_est_date) AS cycle_number_simple_est
FROM CycleCalculation cyc
JOIN Patients p ON cyc.patient_id = p.patient_id -- Join back to get patient names
ORDER BY cyc.patient_id, cyc.cycle_start_est_date;