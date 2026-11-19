# Sincroniza la lista de temas con los efectos INSTALADOS en SignalRGB
# Fuentes:
#   - Efectos incluidos con la app: VortxEngine\...\Effects\Static y Dynamic (*.html)
#   - Efectos descargados: WhirlwindFX\SignalRgb\cache\effects\<id>\effect.html (nombre en <title>)
# Reescribe temas.txt y publica la lista en el registro para el widget.
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir 'temas.log'
$temasFile = Join-Path $dir 'temas.txt'
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

$nombres = @()

# 1) efectos incluidos con la app
foreach ($sub in @('Static', 'Dynamic')) {
    $ruta = Join-Path $env:LOCALAPPDATA "VortxEngine\app-2.5.86\Signal-x64\Effects\$sub"
    Get-ChildItem $ruta -Filter '*.html' -EA SilentlyContinue | ForEach-Object {
        $nombres += [IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}

# 2) efectos descargados (cache): nombre en el <title> del effect.html
$cache = Join-Path $env:LOCALAPPDATA 'WhirlwindFX\SignalRgb\cache\effects'
Get-ChildItem $cache -Directory -EA SilentlyContinue | ForEach-Object {
    $ef = Join-Path $_.FullName 'effect.html'
    if (Test-Path $ef) {
        $c = Get-Content $ef -Raw -EA SilentlyContinue
        if ($c) {
            $t = [regex]::Match($c, '<title>([^<]+)</title>')
            if ($t.Success -and $t.Groups[1].Value.Trim()) { $nombres += $t.Groups[1].Value.Trim() }
        }
    }
}

# 3) efectos remotos (SignalRGB nuevo los carga desde la nube sin guardarlos
#    como archivo): nombres e IDs se extraen del uso reciente en los logs
$mapa = @{}
$descubiertos = @()
$pend = ''
Get-ChildItem (Join-Path $env:LOCALAPPDATA 'WhirlwindFX\SignalRgb\Logs') -Filter 'SignalRGB_*.log' -EA SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-3) } |
    Sort-Object LastWriteTime |
    ForEach-Object {
        Get-Content $_.FullName -EA SilentlyContinue | ForEach-Object {
            if ($_ -match "New effect requested: '([^']+)'") { $pend = $Matches[1] }
            elseif ($_ -match "EffectFinding: Searching for '([^']+)'") { $pend = $Matches[1] }
            elseif ($_ -match "EffectFinding: Found '([^']+)'") {
                $n = $Matches[1].Trim()
                if ($n) { if ($pend) { $mapa[$pend] = $n }; $descubiertos += $n; $pend = '' }
            }
            elseif ($_ -match "EffectLoading: Loaded '([^']+)'") {
                $n = $Matches[1].Trim()
                if ($n) { if ($pend) { $mapa[$pend] = $n }; $descubiertos += $n; $pend = '' }
            }
        }
    }
$descubiertos = @($descubiertos | Sort-Object -Unique)
$nombres = @(($nombres + $descubiertos) | Sort-Object -Unique)

$nombres = @($nombres | Where-Object { $_ } | Sort-Object -Unique)
if ($nombres.Count -eq 0) {
    Log "sincronizar: no se encontraron efectos instalados (lista sin cambios)"
    exit 1
}

# conservar el ORDEN personalizado: los temas ocultos (#) vuelven a su posicion
# original con el refresco; los efectos con "<ID>; Nombre" (remotos) se conservan
# siempre porque no hay forma local de saber si siguen instalados
$deNombre = @{}
foreach ($k in $mapa.Keys) { if (-not $deNombre.ContainsKey($mapa[$k])) { $deNombre[$mapa[$k]] = $k } }

$enArchivo = @()
Get-Content $temasFile -EA SilentlyContinue | ForEach-Object {
    $l = $_.Trim()
    $oculto = $l.StartsWith('#')
    if ($oculto) { $l = $l.Substring(1).Trim() }
    if ($l -eq '') { return }
    $nombre = $l
    $efecto = $l
    if ($l -match '^([^;]+?)\s*;\s*(.+)$') {
        $nombre = $Matches[2].Trim()
        $pref = $Matches[1].Trim()
        $efecto = if ($pref -match '^\d{1,2}:\d{2}$') { $nombre } else { $pref }
    }
    if (-not $nombre) { return }
    $enArchivo += [PSCustomObject]@{ Nombre = $nombre; Efecto = $efecto }
}

# dedupe por nombre conservando orden
$vistos = @()
$enOrden = @()
foreach ($e in $enArchivo) {
    if ($vistos -notcontains $e.Nombre) { $vistos += $e.Nombre; $enOrden += $e }
}
$mantenidos = @($enOrden | Where-Object { ($nombres -contains $_.Nombre) -or ($_.Efecto -ne $_.Nombre) })
$nombresEnLista = @($mantenidos | ForEach-Object { $_.Nombre })
$nuevos = @($nombres | Where-Object { $nombresEnLista -notcontains $_ })
$listaFinal = @($mantenidos)
foreach ($n in $nuevos) {
    $ef = if ($deNombre.ContainsKey($n)) { $deNombre[$n] } else { $n }
    $listaFinal += [PSCustomObject]@{ Nombre = $n; Efecto = $ef }
}

$listaLineas = @($listaFinal | ForEach-Object {
    if ($_.Efecto -ne $_.Nombre) { "$($_.Efecto); $($_.Nombre)" } else { $_.Nombre }
})

$contenido = @(
    "# Temas RGB: lista sincronizada desde SignalRGB (boton Actualizar del widget)"
    "# Un efecto por linea (nombre EXACTO). El orden personalizado se conserva;"
    "# los efectos nuevos se agregan al final."
    "# Los efectos remotos de SignalRGB van como '<ID>; Nombre' y el widget los"
    "# aplica por su ID (solo aparecen tras usarlos una vez en SignalRGB)."
    ""
) + $listaLineas
Set-Content -Path $temasFile -Value $contenido -ErrorAction SilentlyContinue
Log ("sincronizado: {0} efectos ({1})" -f $listaFinal.Count, (($listaFinal | ForEach-Object { $_.Nombre }) -join ', '))

# publicar en el registro para el widget
try {
    if (-not (Test-Path 'HKCU:\Software\TemasRGB')) { New-Item -Path 'HKCU:\Software\TemasRGB' | Out-Null }
    Set-ItemProperty -Path 'HKCU:\Software\TemasRGB' -Name 'NTemas' -Value ([Math]::Min($listaFinal.Count, 20))
    for ($i = 1; $i -le 20; $i++) {
        $v = if ($i -le $listaFinal.Count) { $listaFinal[$i - 1].Nombre } else { '' }
        Set-ItemProperty -Path 'HKCU:\Software\TemasRGB' -Name ("T{0}" -f $i) -Value $v
    }
} catch {}

# sincronizar el TEMA ACTUAL con lo que SignalRGB esta reproduciendo de verdad
try {
    $sel = Get-ItemProperty 'HKCU:\Software\WhirlwindFX\SignalRgb\effects\selected' -EA SilentlyContinue
    if ($sel -and $sel.name) {
        $actualWidget = ''
        try { $actualWidget = (Get-ItemProperty 'HKCU:\Software\TemasRGB' -EA SilentlyContinue).Tema } catch {}
        if ($actualWidget -cne $sel.name) {
            Set-ItemProperty -Path 'HKCU:\Software\TemasRGB' -Name 'Tema' -Value $sel.name
            Set-Content -Path (Join-Path $dir 'estado.txt') -Value $sel.name -ErrorAction SilentlyContinue
            Log ("tema actual re-sincronizado: widget='{0}' -> SignalRGB='{1}'" -f $actualWidget, $sel.name)
        }
    }
} catch {}
