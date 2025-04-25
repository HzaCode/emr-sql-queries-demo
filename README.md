# SQL for Clinical Insights from EMR Data

## Project Overview

This repository contains a series of examples using SQL to analyze Electronic Medical Record (EMR) data. Each project aims to address a specific clinical or research-related question and derive meaningful insights relevant to patient care or clinical research.

**The project uses a pre-populated SQLite database (`oncology_data.db`) containing anonymized sample data. The structure of this database is defined in `data/schema.sql`.**

---

## Setup and Usage

1.  **Database:** The core data resides in the `oncology_data.db` file in the project root. 
2.  **Schema Reference:** To understand the tables and columns, refer to the `data/schema.sql` file.
3.  **Running the Analyses:**
    *   **Option 1: Manual Execution (Using a DB Tool)**
        *   Use a database tool that supports SQLite (e.g., [DB Browser for SQLite](https://sqlitebrowser.org/), [DBeaver](https://dbeaver.io/), or a compatible IDE extension).
        *   Connect to the `oncology_data.db` file.
        *   Open and run the individual SQL scripts located in the `projects/` directory:
            *   `projects/nsclc_therapy_matching.sql`
            *   `projects/crc_folfox_analysis.sql`
            *   `projects/ovarian_ca125_trends.sql`
    *   **Option 2: Automated Execution (Using Python Script - Recommended)**
        *   Ensure you have Python 3 installed.
        *   Open your terminal or command prompt in the project's root directory.
        *   Run the provided Python script: `python run_analysis.py`
        *   This script will automatically connect to the database and execute all three analysis queries, printing the results to your console. (Note: This script will be created in the next step).
4.  **Exploring the Data (Optional):** You can use the same database tools mentioned above to browse the tables and familiarize yourself with the sample data.

---

## Testing

This project includes basic tests to ensure the SQL queries execute correctly and return the expected columns.

1.  **Navigate** to the project root directory in your terminal.
2.  **Run the tests** using Python's `unittest` module:
    ```bash
    # Use discover to find tests in the tests/ directory
    py -m unittest discover -s tests -p "test_*.py" -v
    ```
    (Use `python` instead of `py` if that's your command for Python 3).

All tests should pass if the database file (`oncology_data.db`) is present and the SQL queries in the `projects/` directory are valid.

---

## Database Schema Overview

The `oncology_data.db` database contains the following main tables (defined in `data/schema.sql`):

*   `Patients`: Basic patient demographic information (Primary Key: `patient_id`).
*   `Diagnoses`: Patient cancer diagnoses (ICD-10 codes, histology). Links to `Patients` via `patient_id`.
*   `Staging`: Cancer staging information (TNM, overall stage) linked to diagnoses. Links to `Diagnoses` via `diagnosis_id`.
*   `Biomarkers`: Results of biomarker tests (e.g., gene mutations, protein expression). Links to `Patients` via `patient_id`.
*   `Medications`: Records of prescribed medications or treatment regimens (with treatment lines). Links to `Patients` via `patient_id`.
*   `MedicationAdministrations`: Specific instances of medication administration (used for detailed regimen analysis like FOLFOX). Links to `Patients` via `patient_id`.
*   `LabResults`: Results of laboratory tests (e.g., CA-125 levels). Links to `Patients` via `patient_id`.

---

## Analysis Projects

### 1. Advanced NSCLC Precision Therapy Matching Assessment

*   **Clinical Question:** For patients diagnosed with Stage IV Non-Small Cell Lung Cancer (NSCLC), do those with specific actionable driver mutations (based on biomarker data) receive a corresponding NCCN-guideline-recommended first-line targeted therapy?
*   **SQL Method Summary:** Connect patient, diagnosis, staging, biomarker, and medication tables, applying rule-based logic (`CASE WHEN` statements embedding NCCN-based rules) to match gene variants with corresponding targeted drugs, focusing on first-line treatment (`treatment_line = 1`).
*   **Code:** `projects/nsclc_therapy_matching.sql`
*   **Expected Output Columns:** Patient info, biomarker results (EGFR, ALK, ROS1, BRAF), first-line therapy details, and a `therapy_matching_status` indicating if the therapy matches NCCN guidelines based on biomarkers.

### 2. Colorectal Cancer FOLFOX Chemotherapy Regimen Identification and Cycle Evaluation

*   **Clinical Question:** Can we identify Colorectal Cancer (CRC) patients who received the FOLFOX chemotherapy regimen based on their medication administration records, and estimate the number of cycles they completed?
*   **SQL Method Summary:** Identify CRC patients (`Diagnoses`), select their chemotherapy administrations (`MedicationAdministrations`), group administrations by patient and date, identify co-administration of 'Leucovorin', '5-FU', and 'Oxaliplatin' (`GROUP_CONCAT`), and estimate cycle counts using sequence and timing (~14 days) via the `LAG()` window function.
*   **Code:** `projects/crc_folfox_analysis.sql`
*   **Expected Output Columns:** Patient info, estimated start date for each FOLFOX cycle (`cycle_start_est_date`), days since the previous cycle, and an estimated cycle number (`cycle_number_simple_est`).

### 3. Ovarian Cancer CA-125 Dynamic Monitoring Based on GCIG Standards

*   **Clinical Question:** For Ovarian Cancer patients who normalized their CA-125 after initial treatment, can we identify patterns of CA-125 elevation consistent with the GCIG (Gynecologic Cancer InterGroup) criteria for biochemical recurrence?
*   **SQL Method Summary:** Identify Ovarian Cancer patients (`Diagnoses`), select their CA-125 results (`LabResults`), use the `LAG()` window function to access consecutive values and dates, and apply GCIG criteria (Current & Previous value >= 2x ULN, interval >= 7 days) within `WHERE` or `CASE WHEN` clauses to flag potential recurrence patterns.
*   **Code:** `projects/ovarian_ca125_trends.sql`
*   **Expected Output Columns:** Patient info, CA-125 level and date, previous CA-125 level and date, Upper Limit of Normal (ULN), GCIG threshold, and a flag (`meets_gcig_criteria`) indicating if the rise meets GCIG biochemical recurrence criteria.
