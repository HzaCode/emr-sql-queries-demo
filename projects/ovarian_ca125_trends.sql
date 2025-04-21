-- File: ovarian_ca125_trends.sql 
-- Project: Ovarian CA-125 Monitoring


/*
Clinical Question: For Ovarian Cancer patients who normalized their CA-125 after initial
treatment, can we identify patterns of CA-125 elevation consistent with the GCIG
(Gynecologic Cancer InterGroup) criteria for biochemical recurrence?

Logic: Queries actual tables created by schema.sql and populated from CSVs.
1. Identify Ovarian Cancer patients from Diagnoses.
2. Select their CA-125 lab results from LabResults.
3. Use the LAG() window function to access the previous CA-125 value and date.
4. Apply the GCIG criteria: Current and Previous >= 2xULN, AND interval >= 7 days.
5. Flag records meeting the criteria.
*/

WITH OvarianPatients AS (
    SELECT DISTINCT patient_id
    FROM Diagnoses
    WHERE icd10_code LIKE 'C56.%' -- Ovarian Cancer
),
CA125_Measurements AS (
    SELECT
        lr.patient_id,
        lr.result_value AS ca125_level,
        lr.result_datetime,
        LAG(lr.result_value, 1) OVER (PARTITION BY lr.patient_id ORDER BY lr.result_datetime) AS prev_ca125_level,
        LAG(lr.result_datetime, 1) OVER (PARTITION BY lr.patient_id ORDER BY lr.result_datetime) AS prev_result_datetime,
        COALESCE(lr.reference_range_high, 35.0) as uln -- Default ULN to 35 if not provided in data
    FROM LabResults lr
    JOIN OvarianPatients op ON lr.patient_id = op.patient_id
    WHERE lr.test_name = 'CA-125' -- Or use LOINC code
      AND lr.result_value IS NOT NULL
      AND lr.result_datetime IS NOT NULL
      -- Ideally, filter for results *after* initial treatment normalization,
      -- but that logic isn't included here for simplicity.
),
GCIG_Check AS (
    SELECT
        patient_id,
        ca125_level,
        result_datetime,
        prev_ca125_level,
        prev_result_datetime,
        uln,
        (uln * 2.0) AS gcig_threshold_value,
        CASE
            WHEN ca125_level >= (uln * 2.0) -- Current >= 2xULN
             AND prev_ca125_level >= (uln * 2.0) -- Previous >= 2xULN
             AND prev_result_datetime IS NOT NULL
             -- NOTE: Date difference calculation varies by SQL dialect. JULIANDAY is common in SQLite.
             AND JULIANDAY(result_datetime) - JULIANDAY(prev_result_datetime) >= 7 -- Interval >= 7 days
            THEN TRUE
            ELSE FALSE
        END AS meets_gcig_criteria
    FROM CA125_Measurements
    WHERE prev_ca125_level IS NOT NULL -- Can only check criteria if there's a previous value
)
-- Final Output
SELECT
    gc.patient_id,
    p.first_name,
    p.last_name,
    -- Use STRFTIME for better date formatting in SQLite, adjust for other DBs
    STRFTIME('%Y-%m-%d %H:%M', gc.result_datetime) AS result_datetime_str,
    gc.ca125_level,
    STRFTIME('%Y-%m-%d %H:%M', gc.prev_result_datetime) AS prev_result_datetime_str,
    gc.prev_ca125_level,
    gc.uln,
    gc.gcig_threshold_value,
    gc.meets_gcig_criteria
FROM GCIG_Check gc
JOIN Patients p ON gc.patient_id = p.patient_id -- Need to join back to Patients to get names
ORDER BY gc.patient_id, gc.result_datetime;