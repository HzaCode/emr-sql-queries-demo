import sqlite3
import os
import sys
import argparse
import csv

# --- Config ---
DB_FILE = "oncology_data.db"
SQL_FOLDER = "projects"
DEFAULT_QUERY_FILES = [
    "nsclc_therapy_matching.sql",
    "crc_folfox_analysis.sql",
    "ovarian_ca125_trends.sql"
]
RESULTS_FOLDER = "results"

def execute_query(cursor, filepath, limit=None, output_csv=False):
    """Runs a single SQL query file, prints results or saves to CSV."""
    filename = os.path.basename(filepath)
    print(f"--- Running {filename} ---")

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            sql_query = f.read()
        cursor.execute(sql_query)
        
        # Get column names if the query returned anything
        column_names = [desc[0] for desc in cursor.description] if cursor.description else []

        if output_csv:
            # Save results to CSV
            if not os.path.exists(RESULTS_FOLDER):
                os.makedirs(RESULTS_FOLDER) # Create results dir if needed
            csv_filename = os.path.splitext(filename)[0] + ".csv"
            csv_filepath = os.path.join(RESULTS_FOLDER, csv_filename)
            
            with open(csv_filepath, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.writer(csvfile)
                if column_names:
                    writer.writerow(column_names) # Write header
                fetched_count = 0
                while True:
                    rows = cursor.fetchmany(1000) # Fetch in chunks, good for large results
                    if not rows:
                        break # No more data
                    writer.writerows(rows)
                    fetched_count += len(rows)
                print(f"Saved to {csv_filepath} ({fetched_count} rows)")

        else: # Output to console
            # Fetch results - apply limit if specified
            results = cursor.fetchmany(limit) if limit is not None and limit > 0 else cursor.fetchall()
            
            if not results:
                print("(No results returned or limit=0)")
            else:
                # Print header
                if column_names:
                    print(", ".join(column_names))
                    print("-" * (len(", ".join(column_names)) + 4))
                # Print rows
                for row in results:
                    print(", ".join(map(str, row)))
                
                # Check if output was cut short by limit
                if limit is not None and limit > 0 and len(results) == limit:
                     # Try fetching one more row to see if there was more
                     if cursor.fetchone():
                         # Just indicate more rows exist, getting exact count might be slow
                         print("... (output limited)") 
                     # else: fetched exactly the limit

            print(f"--- Done: {filename} ---\n")
        return True # Success

    except sqlite3.Error as e:
        print(f"!! SQL Error in {filepath}: {e}")
        return False # Failed
    except FileNotFoundError:
        print(f"!! File not found: {filepath}")
        return False # Failed
    except IOError as e:
        print(f"!! Error writing CSV {csv_filepath}: {e}")
        return False # Failed
    except Exception as e:
        print(f"!! Unexpected error with {filepath}: {e}")
        return False # Failed

def main():
    """Main logic: connect to DB, parse args, run queries."""
    # --- Argument Parsing ---
    parser = argparse.ArgumentParser(description="Run SQL analysis queries on the oncology DB.")
    parser.add_argument(
        "sql_file", 
        nargs='?', # Makes it optional
        default=None, 
        help=f"Optional: Run only this SQL file (name) from '{SQL_FOLDER}/'. Default: run all."
    )
    parser.add_argument(
        "-l", "--limit", 
        type=int, 
        default=None, 
        help="Limit console output rows per query. No effect on CSV."
    )
    parser.add_argument(
        "-c", "--csv", 
        action="store_true", # Flag, doesn't take a value
        help=f"Save results to CSV files in '{RESULTS_FOLDER}/' instead of console."
    )
    args = parser.parse_args()

    # --- DB and File Checks ---
    if not os.path.exists(DB_FILE):
        print(f"!! Error: DB file '{DB_FILE}' not found here.")
        sys.exit(1)

    # Decide which SQL files to run
    query_files_to_run = []
    if args.sql_file:
        # User specified a single file
        filename_only = os.path.basename(args.sql_file) 
        filepath = os.path.join(SQL_FOLDER, filename_only)
        if not os.path.exists(filepath):
             print(f"!! Error: File '{filename_only}' not found in '{SQL_FOLDER}/'.")
             sys.exit(1)
        query_files_to_run.append(filename_only)
    else:
        # Default: run all predefined files
        query_files_to_run = DEFAULT_QUERY_FILES
        
    # --- Run Queries ---
    conn = None
    all_successful = True
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        print(f"Connected to {DB_FILE}\n")

        for filename in query_files_to_run:
            filepath = os.path.join(SQL_FOLDER, filename)
            # Check again? Might be redundant if list is default, but safer.
            if not os.path.exists(filepath):
                 print(f"?? Warning: SQL file '{filepath}' missing? Skipping.")
                 all_successful = False
                 continue
            # Execute the query, handle output based on args
            if not execute_query(cursor, filepath, limit=args.limit, output_csv=args.csv):
                all_successful = False
                # Keep going even if one fails

        # --- Wrap up ---
        print("-"*30)
        if all_successful:
            print("Script finished.")
        else:
            print("Script finished, but with errors/warnings.")
            # Maybe exit with error code? sys.exit(1) 

    except sqlite3.Error as e:
        print(f"!! DB connection error: {e}")
        all_successful = False # Ensure we note the failure
        # sys.exit(1) # Exit immediately on connection error
    except Exception as e:
        print(f"!! Unexpected error in main: {e}")
        all_successful = False
        # sys.exit(1)
    finally:
        # Always try to close the connection
        if conn:
            conn.close()
            print("\nDB connection closed.")
        
        # Optional: Exit with non-zero code if anything failed
        # if not all_successful:
        #     sys.exit(1)

if __name__ == "__main__":
    main() 