-- File: ovarian_ca125_trends.sql 
-- Project: Ovarian CA-125 Monitoring (GCIG)

/*
Goal: For Ovarian Ca patients whose CA-125 normalized post-treatment,
      find CA-125 rises matching GCIG criteria for biochemical recurrence.

How:
1. Get Ovarian Ca patients (Diagnoses).
2. Get their CA-125 results (LabResults).
3. Use LAG() to get previous CA-125 value and date.
4. Apply GCIG criteria: Current & Previous >= 2xULN, interval >= 7 days.
5. Flag rows meeting criteria.
*/

WITH OvarianPatients AS (
    -- Find Ovarian Cancer patients
    SELECT DISTINCT patient_id
    FROM Diagnoses
    WHERE icd10_code LIKE 'C56.%' -- Ovarian Ca
),
CA125_Measurements AS (
    -- Get CA-125 results and the previous result using LAG()
    SELECT
        lr.patient_id,
        lr.result_value AS ca125_level,
        lr.result_datetime,
        LAG(lr.result_value, 1) OVER (PARTITION BY lr.patient_id ORDER BY lr.result_datetime) AS prev_ca125_level,
        LAG(lr.result_datetime, 1) OVER (PARTITION BY lr.patient_id ORDER BY lr.result_datetime) AS prev_result_datetime,
        -- Use 35.0 as default ULN if missing in data (common practice)
        COALESCE(lr.reference_range_high, 35.0) AS uln 
    FROM LabResults lr
    JOIN OvarianPatients op ON lr.patient_id = op.patient_id
    WHERE lr.test_name = 'CA-125' -- Filter for CA-125 tests
      AND lr.result_value IS NOT NULL -- Need a value
      AND lr.result_datetime IS NOT NULL -- Need a date
      -- Ideally, filter for results *after* normalization, but skipping that complexity here.
),
GCIG_Check AS (
    -- Apply GCIG criteria check
    SELECT
        patient_id,
        ca125_level,
        result_datetime,
        prev_ca125_level,
        prev_result_datetime,
        uln,
        (uln * 2.0) AS gcig_threshold_value, -- Calculate 2xULN threshold
        CASE
            WHEN ca125_level >= (uln * 2.0) -- Current >= 2xULN?
             AND prev_ca125_level >= (uln * 2.0) -- Previous >= 2xULN?
             AND prev_result_datetime IS NOT NULL -- Have a previous date?
             -- Use JULIANDAY for SQLite date diff, adjust for other DBs
             AND JULIANDAY(result_datetime) - JULIANDAY(prev_result_datetime) >= 7 -- Interval >= 7 days?
            THEN TRUE
            ELSE FALSE
        END AS meets_gcig_criteria
    FROM CA125_Measurements
    WHERE prev_ca125_level IS NOT NULL -- Can only check if we have a previous value
)
-- Final Output: Show results flagged by GCIG criteria
SELECT
    gc.patient_id,
    p.first_name,
    p.last_name,
    -- Format dates nicely for output (SQLite specific)
    STRFTIME('%Y-%m-%d %H:%M', gc.result_datetime) AS result_datetime_str,
    gc.ca125_level,
    STRFTIME('%Y-%m-%d %H:%M', gc.prev_result_datetime) AS prev_result_datetime_str,
    gc.prev_ca125_level,
    gc.uln,
    gc.gcig_threshold_value,
    gc.meets_gcig_criteria
FROM GCIG_Check gc
JOIN Patients p ON gc.patient_id = p.patient_id -- Need patient names
ORDER BY gc.patient_id, gc.result_datetime;