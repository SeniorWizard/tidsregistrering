# MTime-helper 

$DaysBack = 35   # hvor langt tilbage vi henter events
$da = [System.Globalization.CultureInfo]::GetCultureInfo('da-DK')
$start = (Get-Date).Date.AddDays(-$DaysBack)

# Helpers

function Format-Min([int]$m) {
    if ($null -eq $m) { return $null }
    "{0:00}:{1:00}" -f [math]::Floor($m/60), ($m % 60)
}

function Format-Duration([int]$m) {
    if ($null -eq $m -or $m -lt 0) { return $null }
    # afrund til hele minutter
    "{0:00}:{1:00}" -f [math]::Floor($m/60), ($m % 60)
}

function Event-Type([int]$id) {
    switch ($id) {
        4624 { 'Logon' }
        4634 { 'Logoff' }
        4800 { 'Lock' }
        4801 { 'Unlock' }

        41   { 'Uventet nedlukning' }                  # Kernel-Power
        42   { 'Sleep' }                               # Kernel-Power
        107  { 'Resume' }                              # Kernel-Power
        109  { 'Shutdown (Kernel-Power)' }             # Kernel-Power
        1074 { 'Planlagt shutdown/restart' }           # User32
        6005 { 'Eventlog start (typisk boot)' }        # EventLog
        6006 { 'Eventlog stop (typisk shutdown)' }     # EventLog
        12   { 'System boot (Kernel-General)' }        # Kernel-General
        1    { 'Wake (Power-Troubleshooter)' }         # Power-Troubleshooter
        20   { 'Windows update' }                      # Startup
        27   { 'Network link' }                        # Startup
        13   { 'WinInit' }                      # Shutdown
	

        default { "EventID $id" }
    }
}

# events der indikerer start/stop, power, link, logon/off
# $sysIds = 1,12,41,42,107,109,1074,6005,6006

$sysIds = 1,26,6005,6006,20,27,13,109,41,1001,1073,1076
$secIds = 4624,4634,4800,4801

$sys = Get-WinEvent -FilterHashtable @{ LogName='System';   Id=$sysIds; StartTime=$start }   -ErrorAction SilentlyContinue
$sec = Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=$secIds; StartTime=$start }   -ErrorAction SilentlyContinue

$all = @()
if ($sys) { $all += $sys }
if ($sec) { $all += $sec }

# Formatering
$MT = $all | Select-Object TimeCreated, ProviderName, Id, Message |
    ForEach-Object {
        $dt = $_.TimeCreated
        [pscustomobject]@{
            Dato    = $dt.ToString('yyyy-MM-dd')
            Ugedag  = $dt.ToString('dddd', $da)
            Tid     = $dt.ToString('HH:mm')
            Minut   = [int][Math]::Floor($dt.TimeOfDay.TotalMinutes)
            Type    = Event-Type $_.Id
            Id      = $_.Id
            Kilde   = $_.ProviderName
            Tekst   = ($_.Message -replace '\s+',' ').Trim()
            Raw     = $dt
        }
    }

# Debug
# $MT | Sort-Object Raw | Format-Table -Auto

# --- Sammendrag pr. dag ---
$Dagligt = $MT |
    Group-Object Dato |
    ForEach-Object {
        $g = $_.Group | Sort-Object Minut, Raw

        # Første/sidste efter Minut (min/max)
        $first = $g | Select-Object -First 1
        $last  = $g | Select-Object -Last 1

        $min = $first.Minut
        $max = $last.Minut

        # Arbejdstid i minutter (samme dags antagelse)
        $dur = if ($g.Count -ge 2) { $max - $min } else { $null }

        [pscustomobject]@{
            Dato         = $_.Name
            Dag          = $first.Ugedag.Substring(0,3)
            Ind          = Format-Min $min
            Ud           = Format-Min $max
            Ialt         = Format-Duration $dur
            # Logs         = $g.Count
            # StartEvent   = "{0} (ID {1})" -f $first.Type, $first.Id
            # SlutEvent    = "{0} (ID {1})" -f $last.Type,  $last.Id
        }
    } | Sort-Object Dato

# Vi oversigt
$Dagligt | Format-Table -Auto

# CSV - export?
# $Dagligt | Export-Csv -Path "$env:USERPROFILE\arbejdstid_events.csv" -NoTypeInformation -Encoding UTF8
