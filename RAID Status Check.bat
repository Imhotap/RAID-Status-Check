@echo off
setlocal enabledelayedexpansion

rem -------------------------
rem check_raid.bat - self-contained RAID report generator
rem Save this file as check_raid.bat and Run as administrator.
rem -------------------------

set "PS1=%TEMP%\check_raid_embedded.ps1"
set "WRAPPER_LOG=%TEMP%\check_raid_wrapper.log"

rem cleanup previous artifacts
if exist "%PS1%" del /f /q "%PS1%" >nul 2>&1
if exist "%WRAPPER_LOG%" del /f /q "%WRAPPER_LOG%" >nul 2>&1

rem Resolve a PowerShell executable that exists on this Windows PC
set "PWR_EXE="
for /f "delims=" %%I in ('where powershell.exe 2^>nul') do (
  set "PWR_EXE=%%I"
  goto :powershell_found
)
for /f "delims=" %%I in ('where pwsh.exe 2^>nul') do (
  set "PWR_EXE=%%I"
  goto :powershell_found
)
:powerShell_found
if not defined PWR_EXE (
  echo ERROR: PowerShell was not found on this system. See %WRAPPER_LOG% for details. > "%WRAPPER_LOG%"
  echo PowerShell is required. Exiting.
  pause
  exit /b 1
)

rem Extract embedded PS1 lines (prefix ::PS1::) into temp PS1
for /f "usebackq delims=" %%A in ("%~f0") do (
  set "line=%%A"
  if "!line:~0,7!"=="::PS1::" (
    >>"%PS1%" echo(!line:~7!
  )
)

rem Verify PS1 was created and is non-empty
if not exist "%PS1%" (
  echo ERROR: Failed to create "%PS1%". > "%WRAPPER_LOG%"
  echo The batch could not extract the embedded PowerShell script. See %WRAPPER_LOG%.
  pause
  exit /b 1
)
for %%I in ("%PS1%") do if %%~zI EQU 0 (
  echo ERROR: "%PS1%" is empty. > "%WRAPPER_LOG%"
  echo The embedded script appears empty or corrupted. See %WRAPPER_LOG%.
  pause
  exit /b 1
)

rem Run the embedded PowerShell script elevated and wait
"%PWR_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%PWR_EXE%' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%PS1%' -Verb RunAs -Wait" 2>>"%WRAPPER_LOG%"

rem Inform user and point to logs
echo.
echo If successful, the report is on your Desktop as RAID_Report_YYYYMMDD_HHMMSS.txt
echo If nothing appears, inspect:
echo   - %WRAPPER_LOG%   (wrapper errors)
echo   - %PS1%           (the generated PowerShell script for manual run/inspection)
echo To run the PS1 manually from an elevated PowerShell:
echo   "%PWR_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
pause
endlocal
exit /b 0

::PS1::# Embedded PowerShell script - generates a detailed RAID TXT report on the Desktop
::PS1::[CmdletBinding()]
::PS1::param()
::PS1::
::PS1::function AppendTxt {
::PS1::    param($Path, $Lines)
::PS1::    if ($Lines -is [System.Array]) { $Lines | Out-File -FilePath $Path -Append -Encoding UTF8 } else { $Lines | Out-File -FilePath $Path -Append -Encoding UTF8 }
::PS1::}
::PS1::
::PS1::function Capture {
::PS1::    param($Label, $ScriptBlock, $ReportPath, $ErrLog)
::PS1::    AppendTxt $ReportPath "=== $Label ==="
::PS1::    try {
::PS1::        $out = & $ScriptBlock 2>&1
::PS1::        if ($null -ne $out -and $out.Count -gt 0) { $out | ForEach-Object { AppendTxt $ReportPath $_ } } else { AppendTxt $ReportPath "<no output>" }
::PS1::    } catch {
::PS1::        $msg = "ERROR running $Label : $($_.Exception.Message)"
::PS1::        AppendTxt $ReportPath $msg
::PS1::        $msg | Out-File -FilePath $ErrLog -Append -Encoding UTF8
::PS1::    }
::PS1::    AppendTxt $ReportPath ""
::PS1::}
::PS1::
::PS1::# Require elevation
::PS1::$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
::PS1::if (-not $isAdmin) {
::PS1::    Write-Error "This script must be run as Administrator. Re-run the batch as Administrator."
::PS1::    exit 1
::PS1::}
::PS1::
::PS1::$ts = (Get-Date).ToString('yyyyMMdd_HHmmss')
::PS1::$desktop = [Environment]::GetFolderPath('Desktop')
::PS1::if (-not (Test-Path $desktop)) { $desktop = "$env:USERPROFILE\Desktop" }
::PS1::$report = Join-Path $desktop "RAID_Report_$ts.txt"
::PS1::$errlog = Join-Path $env:TEMP "raid_check_error_$ts.log"
::PS1::
::PS1::if (Test-Path $errlog) { Remove-Item $errlog -Force -ErrorAction SilentlyContinue }
::PS1::
::PS1::"RAID status report" | Out-File -FilePath $report -Encoding UTF8
::PS1::"Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $report -Append -Encoding UTF8
::PS1::"" | Out-File -FilePath $report -Append -Encoding UTF8
::PS1::"Host: $env:COMPUTERNAME    User: $env:USERNAME" | Out-File -FilePath $report -Append -Encoding UTF8
::PS1::"" | Out-File -FilePath $report -Append -Encoding UTF8
::PS1::
::PS1::# 1) Storage module (Storage Spaces / virtual disks)
::PS1::if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
::PS1::    Capture "Get-PhysicalDisk" { Get-PhysicalDisk | Select FriendlyName,SerialNumber,Size,MediaType,OperationalStatus,HealthStatus | Format-List | Out-String } $report $errlog
::PS1::    Capture "Get-StoragePool" { Get-StoragePool -ErrorAction SilentlyContinue | Select FriendlyName,HealthStatus,Size,AllocatedSize | Format-List | Out-String } $report $errlog
::PS1::    Capture "Get-VirtualDisk" { Get-VirtualDisk -ErrorAction SilentlyContinue | Select FriendlyName,ResiliencySettingName,HealthStatus,Size | Format-List | Out-String } $report $errlog
::PS1::} else {
::PS1::    AppendTxt $report 'Storage module cmdlets not available on this system.'
::PS1::    AppendTxt $report ''
::PS1::}
::PS1::
::PS1::# 2) Disk and volume information
::PS1::Capture "Get-Disk" { Get-Disk | Select Number,FriendlyName,Model,Size,PartitionStyle,OperationalStatus | Format-List | Out-String } $report $errlog
::PS1::Capture "Get-Volume" { Get-Volume | Select DriveLetter,FileSystem,HealthStatus,Size | Format-List | Out-String } $report $errlog
::PS1::
::PS1::# 3) diskpart fallback: list disk + detail for detected disks
::PS1::Capture "diskpart list disk (raw)" { cmd.exe /c "echo list disk | diskpart" } $report $errlog
::PS1::$dpRaw = cmd.exe /c "echo list disk | diskpart" 2>&1
::PS1::$diskNums = @()
::PS1::foreach ($line in $dpRaw) {
::PS1::    if ($line -match 'Disk\s+([0-9]+)') { $diskNums += [int]$matches[1] }
::PS1::}
::PS1::if ($diskNums.Count -eq 0) { $diskNums = 0..3 }
::PS1::foreach ($d in $diskNums) {
::PS1::    Capture "diskpart detail disk $d" { cmd.exe /c "echo select disk $d & echo detail disk | diskpart" } $report $errlog
::PS1::}
::PS1::
::PS1::# 4) Vendor CLI outputs (append only if present)
::PS1::AppendTxt $report '=== Vendor CLI outputs (if present) ==='
::PS1::$vendorCmds = @{
::PS1::    'storcli64' = { & storcli64 /c0 /vall show all J 2>&1 }
::PS1::    'MegaCli64' = { & MegaCli64 -AdpAllInfo -aALL 2>&1 }
::PS1::    'omreport'  = { & omreport storage controller 2>&1 }
::PS1::    'ssacli'    = { & ssacli ctrl all show config 2>&1 }
::PS1::    'perccli'   = { & perccli /c0 /vall show 2>&1 }
::PS1::}
::PS1::foreach ($cmd in $vendorCmds.Keys) {
::PS1::    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
::PS1::        AppendTxt $report ("--- {0} output ---" -f $cmd)
::PS1::        try {
::PS1::            $out = & $vendorCmds[$cmd]
::PS1::            if ($null -ne $out -and $out.Count -gt 0) { $out | ForEach-Object { AppendTxt $report $_ } } else { AppendTxt $report '<no output>' }
::PS1::        } catch {
::PS1::            $err = "Failed to run $cmd : $($_.Exception.Message)"
::PS1::            AppendTxt $report $err
::PS1::            $err | Out-File -FilePath $errlog -Append -Encoding UTF8
::PS1::        }
::PS1::    } else {
::PS1::        AppendTxt $report ("{0} not found" -f $cmd)
::PS1::    }
::PS1::    AppendTxt $report ""
::PS1::}
::PS1::
::PS1::# 5) Inference: search for RAID keywords and health indicators
::PS1::AppendTxt $report '=== Parsed summary and RAID inference ==='
::PS1::$full = Get-Content $report -Raw
::PS1::$keywords = @{
::PS1::    'RAID0' = 'RAID 0|RAID0|Striping|Stripe'
::PS1::    'RAID1' = 'RAID 1|RAID1|Mirror|Mirroring'
::PS1::    'RAID5' = 'RAID 5|RAID5|Single Parity|Parity'
::PS1::    'RAID6' = 'RAID 6|RAID6|Dual Parity|Dual-parity'
::PS1::    'RAID10'= 'RAID 10|RAID10|RAID1\+0|Mirrored Stripes'
::PS1::    'RAID50'= 'RAID 50|RAID50|RAID5\+0'
::PS1::    'RAID60'= 'RAID 60|RAID60|RAID6\+0'
::PS1::    'JBOD'  = 'JBOD|Just a Bunch of Disks'
::PS1::}
::PS1::$foundAny = $false
::PS1::foreach ($k in $keywords.Keys) {
::PS1::    if ($full -match $keywords[$k]) {
::PS1::        AppendTxt $report ("Detected possible RAID type: {0}" -f $k)
::PS1::        $foundAny = $true
::PS1::    }
::PS1::}
::PS1::if (-not $foundAny) { AppendTxt $report 'No explicit RAID level keywords found in captured output.' }
::PS1::
::PS1::$healthTerms = 'Degraded|Failed|Offline|Critical|Predictive|Rebuild|Resync|Error'
::PS1::$matches = Select-String -InputObject $full -Pattern $healthTerms -AllMatches
::PS1::if ($matches) {
::PS1::    AppendTxt $report 'Health/alert lines found:'
::PS1::    $matches | ForEach-Object { AppendTxt $report $_.Line }
::PS1::} else {
::PS1::    AppendTxt $report 'No obvious health/alert keywords found.'
::PS1::}
::PS1::
::PS1::AppendTxt $report ''
::PS1::AppendTxt $report '=== Guidance ==='
::PS1::AppendTxt $report ' - Vendor CLI outputs (StorCLI/MegaCli/OMSA/ssacli/perccli) are authoritative for hardware RAID.'
::PS1::AppendTxt $report ' - Storage Spaces output (Get-PhysicalDisk/Get-VirtualDisk) is authoritative for Windows-managed resiliency.'
::PS1::AppendTxt $report ''
::PS1::AppendTxt $report "Report saved to: $report"
::PS1::AppendTxt $report "Debug log (errors) saved to: $errlog (if created)"
::PS1::Write-Output "Report saved to: $report"
::PS1::exit 0
