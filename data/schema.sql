-- data/schema.sql

DROP TABLE IF EXISTS LabResults;
DROP TABLE IF EXISTS MedicationAdministrations;
DROP TABLE IF EXISTS Medications;
DROP TABLE IF EXISTS Biomarkers;
DROP TABLE IF EXISTS Staging;
DROP TABLE IF EXISTS Diagnoses;
DROP TABLE IF EXISTS Patients;

CREATE TABLE Patients (
    patient_id VARCHAR(36) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    birth_date DATE,
    sex VARCHAR(10)
);

CREATE TABLE Diagnoses (
    diagnosis_id VARCHAR(36) PRIMARY KEY,
    patient_id VARCHAR(36) REFERENCES Patients(patient_id),
    diagnosis_date DATE,
    icd10_code VARCHAR(10),
    histology VARCHAR(100),
    diagnosis_description VARCHAR(255)
);

CREATE TABLE Staging (
    staging_id VARCHAR(36) PRIMARY KEY,
    diagnosis_id VARCHAR(36) REFERENCES Diagnoses(diagnosis_id),
    staging_system VARCHAR(50), -- TNM, FIGO, etc.
    t_stage VARCHAR(10),
    n_stage VARCHAR(10),
    m_stage VARCHAR(10),
    overall_stage VARCHAR(10), -- Clinical Stage (e.g., IIIa, IVb)
    staging_date DATE
);

CREATE TABLE Biomarkers (
    biomarker_id VARCHAR(36) PRIMARY KEY,
    patient_id VARCHAR(36) REFERENCES Patients(patient_id),
    test_date DATE,
    marker_name VARCHAR(100), -- e.g., EGFR Mutation, PD-L1 TPS
    marker_result VARCHAR(100), -- e.g., Exon 19 Deletion, Positive, 50%, G12C
    specimen_source VARCHAR(100)
);

CREATE TABLE Medications (
    medication_id VARCHAR(36) PRIMARY KEY,
    patient_id VARCHAR(36) REFERENCES Patients(patient_id),
    medication_name VARCHAR(150), -- e.g., Osimertinib, FOLFOX (might represent regimen intent here)
    drug_class VARCHAR(100), -- e.g., Targeted Therapy, Chemotherapy
    start_date DATE,
    end_date DATE, -- NULL if ongoing
    treatment_line INTEGER, -- 1, 2, 3...
    status VARCHAR(50) -- Active, Completed, Stopped
);

CREATE TABLE MedicationAdministrations (
    admin_id VARCHAR(36) PRIMARY KEY,
    patient_id VARCHAR(36) REFERENCES Patients(patient_id),
    medication_name VARCHAR(150), -- Specific drug administered, e.g., Oxaliplatin
    administration_date DATETIME, -- Use DATETIME if time matters, else DATE
    dose REAL,
    unit VARCHAR(50) -- e.g., mg, mg/m2
);

CREATE TABLE LabResults (
    lab_id VARCHAR(36) PRIMARY KEY,
    patient_id VARCHAR(36) REFERENCES Patients(patient_id),
    test_name VARCHAR(100), -- e.g., CA-125, Creatinine
    loinc_code VARCHAR(20), -- Optional standard code
    result_value REAL, -- Use REAL or NUMERIC for lab values
    unit VARCHAR(50),
    result_datetime DATETIME, -- Use DATETIME for precise timing
    reference_range_low REAL,
    reference_range_high REAL
);

-- Optional: Add indexes for faster joins on foreign keys and common filter columns
CREATE INDEX idx_diag_patient ON Diagnoses(patient_id);
CREATE INDEX idx_stage_diag ON Staging(diagnosis_id);
CREATE INDEX idx_biomarker_patient ON Biomarkers(patient_id);
CREATE INDEX idx_med_patient ON Medications(patient_id);
CREATE INDEX idx_medadmin_patient ON MedicationAdministrations(patient_id);
CREATE INDEX idx_lab_patient ON LabResults(patient_id);
CREATE INDEX idx_lab_test_time ON LabResults(patient_id, test_name, result_datetime);