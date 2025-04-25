import unittest
import sqlite3
import os

# --- Config --- 
DB_FILE = "oncology_data.db"
SQL_FOLDER = "projects"

# Expected output columns for each SQL query
EXPECTED_COLUMNS = {
    "nsclc_therapy_matching.sql": [
        "patient_id", "first_name", "last_name", "egfr_mutation", "alk_fusion",
        "ros1_fusion", "braf_mutation", "first_line_therapy", "first_line_drug_class",
        "first_line_start", "therapy_matching_status"
    ],
    "crc_folfox_analysis.sql": [
        "patient_id", "first_name", "last_name", "cycle_start_est_date",
        "days_since_last_cycle", "cycle_number_simple_est"
    ],
    "ovarian_ca125_trends.sql": [
        "patient_id", "first_name", "last_name", "result_datetime_str", "ca125_level",
        "prev_result_datetime_str", "prev_ca125_level", "uln",
        "gcig_threshold_value", "meets_gcig_criteria"
    ]
}

# --- Test Class ---
class TestSQLQueries(unittest.TestCase):
    """Tests if the SQL queries in projects/ run and have the right columns."""

    conn = None # Share connection across tests in this class

    @classmethod
    def setUpClass(cls):
        """Connect to DB once before running tests in this class."""
        if not os.path.exists(DB_FILE):
            # Make sure DB file is there before starting
            raise FileNotFoundError(f"DB file '{DB_FILE}' missing. Run tests from project root?")
        try:
            if cls.conn is None: # Only connect if not already connected
                cls.conn = sqlite3.connect(DB_FILE)
        except Exception as e:
            # Clean up connection if setup failed
            if cls.conn:
                 cls.conn.close()
            cls.conn = None
            raise ConnectionError(f"DB connection failed during setup: {e}")

    @classmethod
    def tearDownClass(cls):
        """Close DB connection after all tests here are done."""
        if cls.conn:
            cls.conn.close()
            cls.conn = None # Good practice

    def setUp(self):
         """Check DB connection before each test method."""
         # If setUpClass failed, don't bother running tests
         if TestSQLQueries.conn is None:
              self.skipTest("DB connection not available (setUpClass likely failed).")

    def _run_query_and_check(self, sql_filename, expect_results=True):
        """Helper: runs a query, checks columns, optionally checks for >0 results."""
        filepath = os.path.join(SQL_FOLDER, sql_filename)
        self.assertTrue(os.path.exists(filepath), f"SQL file missing: {filepath}")

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                sql_query = f.read()
        except Exception as e:
            self.fail(f"Can't read SQL file {filepath}: {e}")

        cursor = None
        try:
            cursor = self.conn.cursor()
            cursor.execute(sql_query)
            first_row = cursor.fetchone() # Try getting one row

            # Check 1: Did it return anything? (Only if expected)
            if expect_results:
                self.assertIsNotNone(first_row, f"Query {sql_filename}: expected results, got none.")
            
            # Check 2: Does it have the right columns?
            if cursor.description:
                 actual_cols = [desc[0] for desc in cursor.description]
                 expected_cols = EXPECTED_COLUMNS.get(sql_filename)
                 self.assertIsNotNone(expected_cols, f"No expected columns defined for {sql_filename} in test script.")
                 # Check if column names match (order matters with assertListEqual)
                 self.assertListEqual(actual_cols, expected_cols, 
                                      f"Column mismatch in {sql_filename}\nExp: {expected_cols}\nGot: {actual_cols}")
            elif first_row is not None:
                 # Should not happen: got data but no column info?
                 self.fail(f"Query {sql_filename}: got data but no column descriptions.")
            # else: No results and no description, might be ok if expect_results=False

        except sqlite3.Error as e:
            self.fail(f"SQL execution failed for {sql_filename}: {e}")
        except Exception as e:
             # Allow assertIsNotNone failure if we didn't expect results
             is_expected_empty_failure = (isinstance(e, AssertionError) and 
                                        not expect_results and 
                                        "unexpectedly None" in str(e))
             if not is_expected_empty_failure:
                 self.fail(f"Unexpected test error for {sql_filename}: {e}")
        finally:
            if cursor:
                cursor.close()

    # --- Individual Tests ---
    def test_nsclc_therapy_matching(self):
        """Check NSCLC matching query."""
        self._run_query_and_check("nsclc_therapy_matching.sql", expect_results=True)

    def test_crc_folfox_analysis(self):
        """Check CRC FOLFOX query."""
        self._run_query_and_check("crc_folfox_analysis.sql", expect_results=True)

    def test_ovarian_ca125_trends(self):
        """Check Ovarian CA-125 query."""
        # This one might be empty depending on data, so don't fail if no results
        self._run_query_and_check("ovarian_ca125_trends.sql", expect_results=False)

if __name__ == '__main__':
    # Run tests with verbosity if script is run directly
    suite = unittest.TestSuite()
    suite.addTest(unittest.makeSuite(TestSQLQueries))
    runner = unittest.TextTestRunner(verbosity=2)
    runner.run(suite) 