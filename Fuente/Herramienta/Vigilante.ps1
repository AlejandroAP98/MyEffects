# Vigilante de Temas RGB: reviva el motor y los atajos si murieron
# Se ejecuta cada 5 min (tarea programada). Consumo minimo: un powershell breve.
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir 'temas.log'
function Log($m) {
    Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -ErrorAction SilentlyContinue
}
foreach ($tarea in @(@('Temas-RGB-Motor', 'Temas-RGB.ps1'), @('Temas-RGB-Atajos', 'Atajos-RGB.ps1'))) {
    $nombre = $tarea[0]
    $script = $tarea[1]
    $vivo = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -like "*$script*" -and $_.CommandLine -notlike '*Vigilante*' }
    if (-not $vivo) {
        Log "vigilante: '$nombre' no estaba corriendo -> relanzado"
        schtasks /Run /TN $nombre | Out-Null
    }
}
