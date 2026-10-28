<#
.SYNOPSIS
  Collects the Git Changes watcher diagnostics ([GCDiag] lines plus every warning/error) from the GrayMoon
  App and Worker log files into one time-sorted text file you can send back.

.PARAMETER Since
  Start of the window to collect (local time). Default: 6 hours ago.

.PARAMETER Until
  End of the window (local time). Default: now.

.PARAMETER LogDirectory
  Folder holding graymoon-app-*.log and graymoon-worker-*.log. Default: C:\ProgramData\GrayMoon\Logs

.PARAMETER OutFile
  Output file. Default: gcdiag-<yyyyMMdd-HHmmss>.txt in the current folder.

.EXAMPLE
  .\Collect-GitChangesDiagnostics.ps1 -Since "2026-10-27 09:00" -Until "2026-10-27 11:30"
#>
[CmdletBinding()]
param(
    [datetime]$Since = (Get-Date).AddHours(-6),
    [datetime]$Until = (Get-Date),
    [string]$LogDirectory = (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'GrayMoon\Logs'),
    [string]$OutFile = ("gcdiag-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
)

if (-not (Test-Path $LogDirectory)) {
    Write-Error "Log directory not found: $LogDirectory"
    exit 1
}

$files = Get-ChildItem -Path $LogDirectory -Filter 'graymoon-*.log' |
    Where-Object { $_.LastWriteTime -ge $Since.AddDays(-1) }

$pattern = '^(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} [+-]\d{2}:\d{2}) \[(?<lvl>\w{3})\] (?<msg>.*)$'
$rows = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $source = if ($file.Name -like 'graymoon-worker-*') { 'WORKER' } else { 'APP   ' }
    # Open with sharing so a running App/Worker (which holds the file open) can still be read.
    $stream = [System.IO.File]::Open($file.FullName, 'Open', 'Read', 'ReadWrite')
    $reader = New-Object System.IO.StreamReader($stream)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line -notmatch $pattern) { continue }
            $ts = [datetimeoffset]::ParseExact($Matches['ts'], 'yyyy-MM-dd HH:mm:ss.fff zzz', $null).LocalDateTime
            if ($ts -lt $Since -or $ts -gt $Until) { continue }
            $level = $Matches['lvl']
            if ($line -match '\[GCDiag\]' -or $level -in 'WRN', 'ERR', 'FTL') {
                $rows.Add([pscustomobject]@{ Time = $ts; Source = $source; Line = $line })
            }
        }
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

$rows | Sort-Object Time | ForEach-Object { '{0} {1}' -f $_.Source, $_.Line } | Set-Content -Path $OutFile -Encoding UTF8
Write-Host ("Wrote {0} lines ({1} to {2}) to {3}" -f $rows.Count, $Since, $Until, (Resolve-Path $OutFile))
