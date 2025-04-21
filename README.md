# SQL for Clinical Insights from EMR Data

## Project Overview

This repository contains a series of examples using SQL to analyze Electronic Medical Record (EMR) data. Each project aims to address a specific clinical or research-related question and derive meaningful insights relevant to patient care or clinical research.

---

### 1. Advanced NSCLC Precision Therapy Matching Assessment

*   **Clinical Question:** For patients diagnosed with Stage IV Non-Small Cell Lung Cancer (NSCLC), do those with specific actionable driver mutations (based on biomarker data) receive a corresponding NCCN-guideline-recommended first-line targeted therapy?
*   **SQL Method Summary:** Connect patient, diagnosis, staging, biomarker, and medication tables, applying rule-based logic (`CASE WHEN` statements embedding NCCN-based rules) to match gene variants with corresponding targeted drugs, focusing on first-line treatment (`treatment_line = 1`).
*   **Code:** `projects/nsclc_therapy_matching.sql`

---

### 2. Colorectal Cancer FOLFOX Chemotherapy Regimen Identification and Cycle Evaluation

*   **Clinical Question:** Can we identify Colorectal Cancer (CRC) patients who received the FOLFOX chemotherapy regimen based on their medication administration records, and estimate the number of cycles they completed?
*   **SQL Method Summary:** Identify CRC patients (`Diagnoses`), select their chemotherapy administrations (`MedicationAdministrations`), group administrations by patient and date, identify co-administration of 'Leucovorin', '5-FU', and 'Oxaliplatin' (`GROUP_CONCAT`), and estimate cycle counts using sequence and timing (~14 days) via the `LAG()` window function.
*   **Code:** `projects/crc_folfox_analysis.sql`

---

### 3. Ovarian Cancer CA-125 Dynamic Monitoring Based on GCIG Standards

*   **Clinical Question:** For Ovarian Cancer patients who normalized their CA-125 after initial treatment, can we identify patterns of CA-125 elevation consistent with the GCIG (Gynecologic Cancer InterGroup) criteria for biochemical recurrence?
*   **SQL Method Summary:** Identify Ovarian Cancer patients (`Diagnoses`), select their CA-125 results (`LabResults`), use the `LAG()` window function to access consecutive values and dates, and apply GCIG criteria (Current & Previous value >= 2x ULN, interval >= 7 days) within `WHERE` or `CASE WHEN` clauses to flag potential recurrence patterns.
*   **Code:** `projects/ovarian_ca125_trends.sql`
