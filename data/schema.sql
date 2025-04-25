-- data/schema.sql

DROP TABLE IF EXISTS LabResults;
DROP TABLE IF EXISTS MedicationAdministrations;
DROP TABLE IF EXISTS Medications;
DROP TABLE IF EXISTS Biomarkers;
DROP TABLE IF EXISTS Staging;
DROP TABLE IF EXISTS Diagnoses;
DROP TABLE IF EXISTS Patients;

CREATE TABLE Patients (
    patient_id VARCHAR(36) PRIMARY KEY,  -- PK
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    birth_date DATE,
    sex VARCHAR(10)                      -- M/F/etc
);

CREATE TABLE Diagnoses (
    diagnosis_id VARCHAR(36) PRIMARY KEY, -- PK
    patient_id VARCHAR(36) REFERENCES Patients(patient_id), -- FK to Patients
    diagnosis_date DATE,
    icd10_code VARCHAR(10),               -- ICD-10 code
    histology VARCHAR(100),               -- e.g., Adenocarcinoma
    diagnosis_description VARCHAR(255)    -- Description text
);

CREATE TABLE Staging (
    staging_id VARCHAR(36) PRIMARY KEY,  -- PK
    diagnosis_id VARCHAR(36) REFERENCES Diagnoses(diagnosis_id), -- FK to Diagnoses
    staging_system VARCHAR(50),          -- e.g., AJCC TNM 8th
    t_stage VARCHAR(10),                 -- T stage
    n_stage VARCHAR(10),                 -- N stage
    m_stage VARCHAR(10),                 -- M stage
    overall_stage VARCHAR(10),           -- e.g., IIIa, IVb
    staging_date DATE
);

CREATE TABLE Biomarkers (
    biomarker_id VARCHAR(36) PRIMARY KEY, -- PK
    patient_id VARCHAR(36) REFERENCES Patients(patient_id), -- FK to Patients
    test_date DATE,
    marker_name VARCHAR(100),            -- e.g., EGFR, PDL1
    marker_result VARCHAR(100),          -- e.g., Exon 19 Del, Pos, 50%
    specimen_source VARCHAR(100)         -- e.g., Tissue, Blood
);

CREATE TABLE Medications (
    medication_id VARCHAR(36) PRIMARY KEY, -- PK
    patient_id VARCHAR(36) REFERENCES Patients(patient_id), -- FK to Patients
    medication_name VARCHAR(150),        -- Drug name or regimen (e.g., Osimertinib, FOLFOX)
    drug_class VARCHAR(100),             -- e.g., TKI, Chemo
    start_date DATE,
    end_date DATE,                       -- NULL = ongoing
    treatment_line INTEGER,              -- 1=1st line, 2=2nd...
    status VARCHAR(50)                   -- Active/Completed/Stopped
);

CREATE TABLE MedicationAdministrations (
    admin_id VARCHAR(36) PRIMARY KEY,    -- PK
    patient_id VARCHAR(36) REFERENCES Patients(patient_id), -- FK to Patients
    medication_name VARCHAR(150),        -- Specific drug given (e.g., Oxaliplatin)
    administration_date DATETIME,        -- Date & Time administered
    dose REAL,
    unit VARCHAR(50)                     -- e.g., mg, mg/m2
);

CREATE TABLE LabResults (
    lab_id VARCHAR(36) PRIMARY KEY,      -- PK
    patient_id VARCHAR(36) REFERENCES Patients(patient_id), -- FK to Patients
    test_name VARCHAR(100),              -- e.g., CA-125
    loinc_code VARCHAR(20),              -- LOINC (optional)
    result_value REAL,                   -- The number
    unit VARCHAR(50),
    result_datetime DATETIME,            -- Date & Time of result
    reference_range_low REAL,
    reference_range_high REAL            -- ULN (Upper Limit of Normal)
);

-- Indexes for faster joins/filters
CREATE INDEX idx_diag_patient ON Diagnoses(patient_id);
CREATE INDEX idx_stage_diag ON Staging(diagnosis_id);
CREATE INDEX idx_biomarker_patient ON Biomarkers(patient_id);
CREATE INDEX idx_med_patient ON Medications(patient_id);
CREATE INDEX idx_medadmin_patient ON MedicationAdministrations(patient_id);
CREATE INDEX idx_lab_patient ON LabResults(patient_id);
CREATE INDEX idx_lab_test_time ON LabResults(patient_id, test_name, result_datetime); -- For time series labs

-- More indexes? Maybe later if slow on big data:
-- CREATE INDEX idx_diag_code_hist ON Diagnoses(icd10_code, histology);
-- CREATE INDEX idx_med_line ON Medications(treatment_line);
-- CREATE INDEX idx_biomarker_name ON Biomarkers(marker_name);