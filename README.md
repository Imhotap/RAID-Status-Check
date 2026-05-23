# RAID Status Check

This repository contains a portable RAID status reporting utility for Windows.

## Files

- `check_raid_status_report.py` - Python script that gathers RAID/storage information using `diskpart` and Windows PowerShell commands, then writes a printable report to the desktop.
- `check_raid_status_report.bat` - Windows batch wrapper that launches the Python script with either `python` or `py`.
- `.gitignore` - ignores Python cache files.

## Usage

1. Run `check_raid_status_report.bat` on a Windows machine.
2. The script will generate a report on the desktop named `RAID_Status_Report_<timestamp>.txt`.
3. For best results, run with administrative privileges.

## Notes

- Hardware RAID controllers may require vendor-specific tools for full status reporting.
- This script focuses on Windows-detectable RAID and storage information.
