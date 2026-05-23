import ctypes
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def is_admin() -> bool:
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def get_desktop_path() -> Path:
    desktop = os.environ.get("USERPROFILE")
    if desktop:
        desktop_path = Path(desktop) / "Desktop"
        if desktop_path.exists():
            return desktop_path
    desktop_path = Path.home() / "Desktop"
    if desktop_path.exists():
        return desktop_path
    return Path.cwd()


def run_command(command, shell=False, encoding="cp1252") -> str:
    try:
        result = subprocess.run(
            command,
            shell=shell,
            capture_output=True,
            text=True,
            encoding=encoding,
            errors="replace",
            check=False,
        )
        output = result.stdout.strip()
        error = result.stderr.strip()
        if error:
            output += f"\n\n[ERROR]\n{error}"
        return output
    except FileNotFoundError:
        return f"Command not found: {command}"
    except Exception as exc:
        return f"Failed to run {command}: {exc}"


def run_diskpart() -> str:
    diskpart_script = "list disk\nlist volume\nlist vdisk\n"
    try:
        proc = subprocess.run(
            ["diskpart"],
            input=diskpart_script,
            capture_output=True,
            text=True,
            encoding="cp1252",
            errors="replace",
        )
        output = proc.stdout.strip()
        if proc.stderr:
            output += f"\n\n[DISKPART STDERR]\n{proc.stderr.strip()}"
        return output
    except FileNotFoundError:
        return "diskpart not found on this system."
    except Exception as exc:
        return f"diskpart execution failed: {exc}"


def run_powershell(cmd: str) -> str:
    powershell_executables = ["powershell", "pwsh"]
    for exe in powershell_executables:
        try:
            result = subprocess.run(
                [exe, "-NoProfile", "-Command", cmd],
                capture_output=True,
                text=True,
                encoding="cp1252",
                errors="replace",
                check=False,
            )
            output = result.stdout.strip()
            if result.stderr.strip():
                output += f"\n\n[ERROR]\n{result.stderr.strip()}"
            return output
        except FileNotFoundError:
            continue
    return "PowerShell is not available on this system."


def main() -> int:
    desktop_path = get_desktop_path()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = desktop_path / f"RAID_Status_Report_{timestamp}.txt"

    sections = []

    sections.append("RAID Status Report")
    sections.append("Generated: {}".format(datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
    sections.append("Machine: {}".format(os.environ.get("COMPUTERNAME", "Unknown")))
    sections.append("Report file: {}".format(report_path))
    sections.append("Administrator: {}".format("Yes" if is_admin() else "No"))
    sections.append("")

    sections.append("=== DiskPart Summary ===")
    sections.append(run_diskpart())
    sections.append("")

    sections.append("=== Windows Storage Status ===")
    storage_commands = [
        (
            "Get-PhysicalDisk",
            "Get-PhysicalDisk | Select-Object FriendlyName,DeviceId,MediaType,OperationalStatus,HealthStatus,CanPool,Size | Format-Table -AutoSize | Out-String -Width 4096",
        ),
        (
            "Get-Disk",
            "Get-Disk | Select-Object Number,FriendlyName,OperationalStatus,HealthStatus,BusType,PartitionStyle,IsBoot,IsSystem,Size | Format-Table -AutoSize | Out-String -Width 4096",
        ),
        (
            "Get-Partition",
            "Get-Partition | Select-Object DiskNumber,PartitionNumber,Type,Size,IsActive,IsBoot,IsSystem | Format-Table -AutoSize | Out-String -Width 4096",
        ),
        (
            "Get-Volume",
            "Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,SizeRemaining,Size | Format-Table -AutoSize | Out-String -Width 4096",
        ),
        (
            "Get-StoragePool",
            "Get-StoragePool | Select-Object FriendlyName,HealthStatus,OperationalStatus,Size,AllocatedSpace | Format-Table -AutoSize | Out-String -Width 4096",
        ),
        (
            "Get-VirtualDisk",
            "Get-VirtualDisk | Select-Object FriendlyName,HealthStatus,OperationalStatus,ResiliencySettingName,Size | Format-Table -AutoSize | Out-String -Width 4096",
        ),
        (
            "Get-StorageJob",
            "Get-StorageJob | Format-Table -AutoSize | Out-String -Width 4096",
        ),
    ]

    for title, cmd in storage_commands:
        sections.append(f"--- {title} ---")
        sections.append(run_powershell(cmd))
        sections.append("")

    sections.append("=== RAID / Software Storage Notes ===")
    sections.append(
        "This report uses DiskPart and Windows Storage PowerShell commands."
    )
    sections.append(
        "Hardware RAID controllers may report only through vendor tools, so"
    )
    sections.append(
        "some RAID levels may not appear in this generic Windows report."
    )
    sections.append("")

    report_text = "\n".join(sections)
    report_path.write_text(report_text, encoding="utf-8")

    print(f"Report written to: {report_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
