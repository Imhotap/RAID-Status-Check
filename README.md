# RAID Status Check

A Windows batch wrapper that gathers RAID and storage diagnostics and writes a text report to your Desktop.

## What it does

Running `RAID Status Check.bat` will:

1. Detect a local PowerShell executable (`powershell.exe` or `pwsh.exe`).
2. Extract an embedded PowerShell script from the batch file.
3. Relaunch that PowerShell script with elevated privileges.
4. Generate a timestamped report named `RAID_Report_YYYYMMDD_HHMMSS.txt` on the Desktop.
5. Capture storage and disk information, plus vendor-specific RAID CLI output when those tools are installed.
6. Add a brief inferred summary for common RAID types and health keywords found in the output.

## Requirements

- Windows PC
- PowerShell available on the system
- Run the script as **Administrator**

The script will prompt for elevation and will stop if it cannot find PowerShell.

## Output

The main output is a text file saved to your Desktop:

- `RAID_Report_YYYYMMDD_HHMMSS.txt`

The wrapper also creates temporary files in `%TEMP%` for debugging:

- `check_raid_embedded.ps1`
- `check_raid_wrapper.log`

## What is included in the report

The report includes:

- Physical disk and storage pool information when available
- Virtual disk information when available
- Disk and volume information
- Raw `diskpart` output
- Vendor RAID tool output when installed:
  - `storcli64`
  - `MegaCli64`
  - `omreport`
  - `ssacli`
  - `perccli`
- A simple RAID inference section based on the collected output
- Health keywords such as `Degraded`, `Failed`, `Offline`, `Critical`, `Rebuild`, and `Error`

## Notes

- This script is designed to work on more than one Windows machine by resolving PowerShell dynamically.
- If the system does not have the storage PowerShell cmdlets available, the script still runs and falls back to `diskpart` and any installed vendor tools.
- The script does **not** require any external dependencies beyond PowerShell and Windows itself.

## Usage

1. Download or clone the repository.
2. Double-click `RAID Status Check.bat`.
3. When prompted, choose **Yes** to run as Administrator.
4. Open the generated `RAID_Report_YYYYMMDD_HHMMSS.txt` file on your Desktop.

## Troubleshooting

If the script does not produce a report:

- Check `%TEMP%\check_raid_wrapper.log`
- Verify that PowerShell is installed
- Run the script again as Administrator

## Repository files

- `RAID Status Check.bat` - the self-contained batch script
- `README.md` - this documentation
