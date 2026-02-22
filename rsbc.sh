#!/bin/bash
#
# ResponderSluiceBoxCleaner (RSBC)
# Author: SkyzFallin
# Date: 2026-02-09
# Version: 1.2
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
#   Computer account hashes (usernames ending in $) are explicitly preserved
#   and treated identically to user hashes — they are deduplicated, labeled,
#   and archived alongside all other captures.
#
# Usage:
#   chmod +x rsbc.sh
#   ./rsbc.sh
#
# Output:
#   - responder_hashes.txt  : Created (or appended to) in the directory where the
#                             script is run. If the file already exists, previously
#                             seen username+hash_type combos are loaded first so
#                             re-running never produces duplicates. Each line is
#                             prefixed with [HASH_TYPE] so you can immediately
#                             identify NTLMv1 vs NTLMv2-SSP, etc.
#                             Sorted by username, computer accounts ($) included.
#   - Archive folder        : Created in /usr/share/responder/logs/ with the
#                             current date (YYYY-MM-DD). All processed .txt hash
#                             files are moved here after extraction.
#
# Deduplication Logic:
#   Hashes are deduplicated by username + hash type. If a user has both an
#   NTLMv1 and NTLMv2 capture, both are kept. Duplicate captures of the
#   same hash type for the same user are removed (only the first is kept).
#   Computer accounts (e.g., WORKSTATION$) follow the same logic and are
#   never filtered or discarded.
#
# Notes:
#   - Session and config .log files are not touched.
#   - Only top-level .txt files in the logs directory are processed,
#     so previously archived folders will not be re-scanned.
#   - Running this script multiple times creates separate date-stamped
#     archive folders for easy history tracking.
#
# Changelog:
#   v1.2 - Append mode: if responder_hashes.txt already exists, existing
#          username+hash_type combos are pre-loaded into SEEN so re-runs
#          accumulate new captures without ever duplicating old ones.
#          Output file is fully re-sorted after each run.
#   v1.1 - Explicitly preserve computer account hashes (usernames ending in $).
#          Added [HASH_TYPE] prefix to each output line for clear identification
#          of NTLMv1, NTLMv2-SSP, etc. without needing to trace back to source files.
#
# License: GPL-3.0
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
COUNT_COMPUTER=0
COUNT_NEW=0      # hashes that are genuinely new vs what was already in the output file

# ----- Pre-load existing output file into SEEN (append/dedup mode) -----

# If responder_hashes.txt already exists, parse every line to reconstruct the
# SEEN keys so we never write a duplicate on subsequent runs.
# Line format: [HASH_TYPE] USERNAME::DOMAIN:...
# We extract the hash type from the bracket prefix and the username from field 1
# of the hash itself, then rebuild the same DEDUP_KEY used during extraction.
if [ -f "$OUTPUT_FILE" ]; then
    echo "[*] Existing output file found — pre-loading seen hashes to prevent duplicates ..."
    PRELOAD_COUNT=0
    while IFS= read -r existing_line; do
        [[ -z "$existing_line" || "$existing_line" =~ ^# ]] && continue

        # Extract hash type from the [HASH_TYPE] prefix
        EXISTING_HASH_TYPE=$(echo "$existing_line" | grep -oP '(?<=^\[)[^\]]+')
        # Extract the raw hash portion (everything after "[HASH_TYPE] ")
        EXISTING_HASH=$(echo "$existing_line" | sed -E 's/^\[[^]]+\] //')
        # Extract username from the raw hash
        EXISTING_USERNAME=$(echo "$EXISTING_HASH" | cut -d':' -f1)

        EXISTING_KEY="${EXISTING_USERNAME}::${EXISTING_HASH_TYPE}"
        SEEN[$EXISTING_KEY]=1
        PRELOAD_COUNT=$((PRELOAD_COUNT + 1))
    done < "$OUTPUT_FILE"
    echo "[*] Pre-loaded $PRELOAD_COUNT existing entries."
fi

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
        # Computer accounts appear as HOSTNAME$::DOMAIN:... and are kept as-is
        USERNAME=$(echo "$line" | cut -d':' -f1)

        # Track computer account captures separately for summary reporting
        # Computer accounts have usernames ending in $ (e.g., WORKSTATION$)
        if [[ "$USERNAME" == *'$' ]]; then
            IS_COMPUTER=1
        else
            IS_COMPUTER=0
        fi

        # Build a deduplication key combining username and hash type
        # This ensures we keep one of each hash type per user (or computer account)
        DEDUP_KEY="${USERNAME}::${HASH_TYPE}"

        # Only write this hash if we haven't seen this username+type combo before
        # Computer account hashes are never skipped — the $ suffix is part of the key
        if [ -z "${SEEN[$DEDUP_KEY]}" ]; then
            SEEN[$DEDUP_KEY]=1

            # Prefix each output line with the hash type in brackets for easy identification.
            # Example: [SMB-NTLMv2-SSP] JSMITH::CORP:aabbccdd:...
            #          [HTTP-NTLMv1]    FILESERVER$::CORP:aabbccdd:...
            echo "[${HASH_TYPE}] ${line}" >> "$TEMP_FILE"

            COUNT_UNIQUE=$((COUNT_UNIQUE + 1))
            COUNT_NEW=$((COUNT_NEW + 1))
            [[ $IS_COMPUTER -eq 1 ]] && COUNT_COMPUTER=$((COUNT_COMPUTER + 1))
        fi

    done < "$file"

done <<< "$HASH_FILES"

# ----- Output -----

# Merge existing output (if any) with the new entries collected in TEMP_FILE,
# then sort the combined set by username (field 2, after the [HASH_TYPE] prefix)
# and overwrite the output file. This produces a single fully-sorted master list.
if [ -f "$OUTPUT_FILE" ]; then
    cat "$OUTPUT_FILE" "$TEMP_FILE" | sort -k2,2 > "${OUTPUT_FILE}.new"
else
    sort -k2,2 "$TEMP_FILE" > "${OUTPUT_FILE}.new"
fi
mv "${OUTPUT_FILE}.new" "$OUTPUT_FILE"

# Clean up the temp file
rm -f "$TEMP_FILE"

# ----- Archive Processed Files -----

# Create the date-stamped archive directory
mkdir -p "$ARCHIVE_DIR"

# Move all processed hash files into the archive folder
# Both user and computer account hash files are moved here — nothing is discarded
MOVED=0
while IFS= read -r file; do
    mv "$file" "$ARCHIVE_DIR/"
    MOVED=$((MOVED + 1))
done <<< "$HASH_FILES"

# ----- Summary -----

echo "[*] Done!"
echo "    Total hashes found:       $COUNT_TOTAL"
echo "    New entries added:        $COUNT_NEW"
echo "      (incl. computer accts): $COUNT_COMPUTER"
echo "    Output written to:        $OUTPUT_FILE"
echo "    Files archived to:        $ARCHIVE_DIR/ ($MOVED files moved)"
