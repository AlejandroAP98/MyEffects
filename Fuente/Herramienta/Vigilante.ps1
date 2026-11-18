# Vigilante de Temas RGB: reviva el motor y los atajos si murieron
# Se ejecuta cada 5 min (tarea programada). Consumo minimo: un powershell breve.
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir 'temas.log'
# aplica auto-recorte a un archivo de log: si pasa de 200 KB conserva solo las ultimas 100 lineas
function Recortar-Log($ruta) {
    if ((Get-Item $ruta -ErrorAction SilentlyContinue).Length -gt 200KB) {
        $ultimas = @(Get-Content $ruta -Tail 100 -ErrorAction SilentlyContinue)
        Set-Content -Path $ruta -Value $ultimas -ErrorAction SilentlyContinue
    }
}

function Log($m) {
    Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -ErrorAction SilentlyContinue
    Recortar-Log $log
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
