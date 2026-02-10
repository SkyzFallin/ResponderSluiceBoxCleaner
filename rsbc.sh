#!/bin/bash
#
# ResponderSluiceBoxCleaner (RSBC)
# Author: SkyzFallin
# Date: 2026-02-09
# Version: 1.0
#
# Project: ResponderSluiceBoxCleaner (RSBC)
#   Like panning for gold, RSBC sifts through the pile of Responder hash
#   captures, filters out the duplicates, and leaves you with clean nuggets
#   ready to crack.
#
# Description:
#   Extracts all captured hash files from Responder's log directory and
#   consolidates them into a single, deduplicated text file. Handles all
#   Responder hash file formats (NTLMv1, NTLMv2-SSP, HTTP, SMB, LDAP,
#   MSSQL, etc.). After extraction, processed hash files are moved into
#   a date-stamped archive folder within the Responder logs directory.
#
# Usage:
#   chmod +x rsbc.sh
#   ./rsbc.sh
#
# Output:
#   - responder_hashes.txt  : Created in the directory where the script is run.
#                             Contains one unique hash per line, sorted by username.
#   - Archive folder        : Created in /usr/share/responder/logs/ with the
#                             current date (YYYY-MM-DD). All processed .txt hash
#                             files are moved here after extraction.
#
# Deduplication Logic:
#   Hashes are deduplicated by username + hash type. If a user has both an
#   NTLMv1 and NTLMv2 capture, both are kept. Duplicate captures of the
#   same hash type for the same user are removed (only the first is kept).
#
# Notes:
#   - Session and config .log files are not touched.
#   - Only top-level .txt files in the logs directory are processed,
#     so previously archived folders will not be re-scanned.
#   - Running this script multiple times creates separate date-stamped
#     archive folders for easy history tracking.
#
# License: MIT
# Repository: https://github.com/SkyzFallin/ResponderSluiceBoxCleaner
#
# ===========================================================================

# ----- Configuration -----

# Path to Responder's log directory where captured hashes are stored
RESPONDER_LOGS="/usr/share/responder/logs"

# Output file will be created in whatever directory the user runs the script from
OUTPUT_FILE="$(pwd)/responder_hashes.txt"

# Temp file for building the hash list before final sort
TEMP_FILE=$(mktemp)

# Archive directory named with today's date (YYYY-MM-DD format)
ARCHIVE_DIR="${RESPONDER_LOGS}/$(date +%Y-%m-%d)"

# ----- Validation -----

# Verify the Responder logs directory exists before proceeding
if [ ! -d "$RESPONDER_LOGS" ]; then
    echo "[!] Responder logs directory not found: $RESPONDER_LOGS"
    exit 1
fi

# Find all .txt hash capture files at the top level only (maxdepth 1)
# This prevents re-processing files that were already archived into date folders
HASH_FILES=$(find "$RESPONDER_LOGS" -maxdepth 1 -type f -name "*.txt" 2>/dev/null)

# Exit if no hash files are found
if [ -z "$HASH_FILES" ]; then
    echo "[!] No hash files found in $RESPONDER_LOGS"
    echo "    (Only .txt hash capture files are processed; session .log files are skipped)"
    exit 1
fi

# ----- Hash Extraction -----

echo "[*] Scanning hash files in $RESPONDER_LOGS ..."

# Associative array to track which username+hash_type combos we've already seen
declare -A SEEN

# Counters for summary stats
COUNT_TOTAL=0
COUNT_UNIQUE=0

# Loop through each hash file found
while IFS= read -r file; do

    # Get the base filename without the .txt extension
    BASENAME=$(basename "$file" .txt)

    # Extract the hash type from the filename
    # Responder names files like: SMB-NTLMv2-SSP-10.0.0.1.txt, HTTP-NTLMv1-10.0.0.1.txt
    # We strip the trailing IP address to isolate the hash type (e.g., SMB-NTLMv2-SSP)
    HASH_TYPE=$(echo "$BASENAME" | sed -E 's/-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.*$//' | sed -E 's/-[0-9a-fA-F:]+$//')

    # Read each line (hash entry) from the current file
    while IFS= read -r line; do

        # Skip empty lines and any comment lines
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Increment total hash counter
        COUNT_TOTAL=$((COUNT_TOTAL + 1))

        # Extract the username from the hash line
        # Responder hash format: USERNAME::DOMAIN:challenge:response:...
        USERNAME=$(echo "$line" | cut -d':' -f1)

        # Build a deduplication key combining username and hash type
        # This ensures we keep one of each hash type per user
        DEDUP_KEY="${USERNAME}::${HASH_TYPE}"

        # Only write this hash if we haven't seen this username+type combo before
        if [ -z "${SEEN[$DEDUP_KEY]}" ]; then
            SEEN[$DEDUP_KEY]=1
            echo "$line" >> "$TEMP_FILE"
            COUNT_UNIQUE=$((COUNT_UNIQUE + 1))
        fi

    done < "$file"

done <<< "$HASH_FILES"

# ----- Output -----

# Sort the deduplicated hashes by username and write to the final output file
sort -t: -k1,1 "$TEMP_FILE" > "$OUTPUT_FILE"

# Clean up the temp file
rm -f "$TEMP_FILE"

# ----- Archive Processed Files -----

# Create the date-stamped archive directory
mkdir -p "$ARCHIVE_DIR"

# Move all processed hash files into the archive folder
MOVED=0
while IFS= read -r file; do
    mv "$file" "$ARCHIVE_DIR/"
    MOVED=$((MOVED + 1))
done <<< "$HASH_FILES"

# ----- Summary -----

echo "[*] Done!"
echo "    Total hashes found:  $COUNT_TOTAL"
echo "    Unique entries kept:  $COUNT_UNIQUE"
echo "    Output written to:    $OUTPUT_FILE"
echo "    Files archived to:    $ARCHIVE_DIR/ ($MOVED files moved)"
