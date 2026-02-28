# GitHub Audit & Improvement Plan (ResponderSluiceBoxCleaner)

## Security Improvements
- **Add a SECURITY.md policy** with disclosure guidance, expected response windows, and safe reporting channels.
- **Enable GitHub security features**: Dependabot alerts, secret scanning alerts, and push protection.
- **Use branch protection** on `main`: require PR reviews and passing checks before merge.
- **Sign releases and tags** (GPG or Sigstore/cosign) so users can verify authenticity.
- **Document safe handling of captured hashes** with explicit operational guidance (least privilege and file retention policy).

## Coding Quality Improvements
- **Add ShellCheck and shfmt CI** to catch shell pitfalls early.
- **Add Bats tests** for deduplication and archive behavior with fixture log files.
- **Refactor parsing into small functions** (`extract_hash_type`, `extract_username`, `archive_files`) to improve maintainability.
- **Add `--logs-dir` and `--output` CLI flags** so users do not need to edit script internals.
- **Support dry-run mode** for safer validation in engagements.

## Reliability / UX Improvements
- **Emit machine-readable summary** (`--json`) for downstream automation.
- **Add verbosity levels** (`--quiet`, `--verbose`) to improve operator experience.
- **Add collision-safe archive naming** (`YYYY-MM-DD_HHMMSS`) if script is executed multiple times per day.
- **Add optional backup rotation** for `responder_hashes.txt`.

## "Cooler" Project Suggestions
- **Add badges** (CI, ShellCheck, release, license) to make project status obvious.
- **Add demo GIF/asciinema** showing RSBC processing logs in seconds.
- **Publish a Homebrew/Nix package** for one-command install.
- **Provide Hashcat mode hints** per hash type in output docs.
- **Create a roadmap board** (`v1.4`, `v2.0`) to invite contributors.

## Suggested Immediate Next Steps
1. Add CI (`shellcheck`, `shfmt`, smoke test).
2. Add `SECURITY.md` and branch protection.
3. Add CLI flags for logs/output paths.
4. Add one end-to-end fixture test.
