
# Server Space Utilization Reporting (SAS)

An automated SAS solution that scans Unix/Linux server directories, calculates storage consumption by department, year, folder, and file type, and emails a formatted HTML summary report to stakeholders — built to support proactive server space management in a BFSI environment.

## Overview

This script combines **SAS macro logic**, **shell-level file scanning (`find` + `du`)**, **PROC SQL aggregation**, and **ODS HTML email reporting** to answer a recurring operational question: *"Where is our server space actually going?"*

It scans a set of department-owned paths (and a broader backup directory), classifies disk usage by department, year, folder category, and file extension, and distributes the results as a single email with multiple ready-to-read tables — including a "Top 10 largest files" list and a direct download link + pre-filled mail-to-IT link for space cleanup requests.

## Key Features

- **Multi-department scanning** — Loops through a configurable list of departments and their server paths using a SAS macro and the `X` statement to shell out to `find`/`du`.
- **Size normalization** — Parses human-readable sizes (`G`/`M`/`K`) into a consistent KB/GB basis for accurate aggregation.
- **Multiple summary views**:
  - Department-wise usage by year (transposed into a wide, dashboard-style table)
  - Year-over-year total usage
  - Folder-category usage (`BACKUPS`, `DATA_SETS`, `OUTPUTS`, `PVT_JOBS`, `Others`)
  - File-extension usage (CSV, XLSX, SAS7BDAT, ZIP, LOG, PDF, etc.)
  - Top 10 largest files on the server
- **Full file inventory export** — Dumps the complete scanned file list to Excel (`PROC EXPORT` to `.xlsx`) for deeper drill-down.
- **Automated HTML email report** — Uses `ODS HTML` with a `FILENAME ... EMAIL` destination to send a styled, multi-table report directly to the team's inbox, including a download link for the full file dump and a pre-addressed `mailto:` link to request space cleanup.

## How It Works

1. **Department list setup** — An inline dataset (`extraction`) maps department codes (`PBG`, `QDESK`, `NRI`, `IBG`) to their server paths.
2. **Dynamic macro variables** — `PROC SQL` loads department names/paths into macro variables; a `%macro loop` iterates through each department.
3. **Shell-level scan** — For each department path, `find ... -exec du --time -Sh {} +` lists every file with size and last-modified date, sorted largest-first, written to a `.txt` file.
4. **Load & parse** — Each text file is read into SAS, sizes are converted to KB, and dates are parsed into a `year` field.
5. **Aggregation** — `PROC SQL` rolls usage up by department, year, and unit; `PROC TRANSPOSE` reshapes it into a department-by-year summary matrix.
6. **Server-wide scan** — A second, broader scan covers the full `/BACKUPS` directory tree (independent of department), feeding the extension, folder, and year-wise summaries plus the Top 10 largest files list.
7. **Excel export** — The complete file inventory is exported to `.xlsx` for anyone who needs the raw detail.
8. **Email dispatch** — `ODS HTML` (email destination) renders all summary tables plus a footnote disclaimer and sends the report via `FILENAME ... EMAIL`.

## Tech Stack

- **SAS Base** — Macro language, `PROC SQL`, `PROC TRANSPOSE`, `PROC REPORT`, `PROC EXPORT`
- **ODS HTML (email destination)** — for the automated email report
- **Shell utilities** — `find`, `du`, `sort` (invoked via SAS `X` statement)
- **Output formats** — HTML email, XLSX export

## Prerequisites

- SAS 9.4+ (or SAS Viya with Base SAS) running on a Unix/Linux server with shell command access (`X` statement / `XCMD` enabled)
- Read access to the target department directories
- An outbound mail relay configured for SAS `FILENAME ... EMAIL` access
- `PROC EXPORT` XLSX engine (SAS/ACCESS or native XLSX engine)

## Configuration

Before running, update the following for your environment:

| Item | Location | Notes |
|---|---|---|
| Department codes & paths | `extraction` dataset (top of script) | Add/remove departments as `dept~path` pairs |
| Loop count | `%do i=1 %to 4` inside `%macro loop` | Must match the number of departments in `extraction` |
| Scan output directory | `/path/BACKUPS/VISHWA/...txt` | Where intermediate `find`/`du` text dumps are written |
| Broader scan path | `%let path=/PATH/BACKUPS;` | Root directory for the server-wide scan |
| Excel export path | `PROC EXPORT ... OUTFILE=` | Destination for the full file-list workbook |
| Email recipients/sender | `FILENAME kvb EMAIL FROM=... TO=...` | Update with actual sender/recipient addresses |
| Cleanup request link | `DUMP` dataset `URL` field | `mailto:` link prefilled with subject/body for raising a cleanup request |

## Output

Running the script produces:

- An **HTML email** containing six report sections:
  1. Department-wise summary (GB by department and year)
  2. Year-wise total summary
  3. Folder-category summary
  4. File-extension summary
  5. Top 10 largest files
  6. Download link + cleanup request link, with a usage disclaimer
- An **Excel workbook** with the complete scanned file inventory (filename, size, last modified date)
- Intermediate `.txt` dumps from the shell-level scan (one per department, plus one server-wide)

## Notes & Limitations

- Designed for on-prem Unix/Linux SAS servers where shelling out via the `X` statement is permitted; will not work as-is on locked-down or cloud-restricted SAS environments without shell access.
- Department list and loop count are currently hardcoded together (`&cnt.` is computed but the loop uses a fixed `4`) — worth syncing dynamically if the department count changes often.
- Paths, email addresses, and recipient names in this version are placeholders and should be replaced with real values before deployment.

## Disclaimer

This report is intended for **internal server-space monitoring only**. Always review file-level detail carefully before deleting or archiving anything, and confirm that no critical files or system dependencies are removed during cleanup.

## Author

**Vishwa Bharath** — Senior SAS Developer & Data Analyst
[LinkedIn](https://linkedin.com/in/vishwa-bharath-87b1bb104) · [GitHub](https://github.com/vishwadata)
