# ResponderSluiceBoxCleaner (RSBC)

Like panning for gold — RSBC sifts through the pile of Responder hash captures, filters out the duplicates, and leaves you with clean nuggets ready to crack.

**Author:** [SkyzFallin](https://github.com/SkyzFallin)

## What It Does

- Extracts all captured hash files from Responder's log directory
- Deduplicates by username + hash type (keeps one of each type per user)
- Outputs a single sorted `responder_hashes.txt` ready for Hashcat/John
- Archives processed files into a date-stamped folder for history tracking

## Quick Start

```bash
git clone https://github.com/SkyzFallin/ResponderSluiceBoxCleaner.git
cd ResponderSluiceBoxCleaner
chmod +x rsbc.sh
./rsbc.sh
```

## Output

| File/Folder | Location | Description |
|---|---|---|
| `responder_hashes.txt` | Current working directory | One unique hash per line, sorted by username |
| `YYYY-MM-DD/` | `/usr/share/responder/logs/` | Archive folder with processed hash files |

## Deduplication Logic

Hashes are deduplicated by **username + hash type**. If a user has both an NTLMv1 and NTLMv2 capture, both are kept. Duplicate captures of the same hash type for the same user are removed (only the first is kept).

## Supported Hash Types

Handles all Responder hash file formats:

- NTLMv1 / NTLMv2-SSP
- HTTP / SMB / LDAP / MSSQL
- Any other `.txt` hash captures in the Responder logs directory

## Notes

- Session and config `.log` files are never touched
- Only top-level `.txt` files in the logs directory are processed — previously archived folders won't be re-scanned
- Running multiple times creates separate date-stamped archive folders
- Default Responder logs path: `/usr/share/responder/logs`

## License

MIT
