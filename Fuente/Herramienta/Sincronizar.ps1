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

$nombres = @($nombres | Where-Object { $_ } | Sort-Object -Unique)
if ($nombres.Count -eq 0) {
    Log "sincronizar: no se encontraron efectos instalados (lista sin cambios)"
    exit 1
}

# conservar el ORDEN personalizado: mantener los temas ya en el archivo
# (en su orden actual), quitar los desinstalados y agregar los nuevos al final
$existentes = @()
Get-Content $temasFile -EA SilentlyContinue | ForEach-Object {
    $l = $_.Trim()
    if ($l -eq '' -or $l.StartsWith('#')) { return }
    if ($l -match '^\d{1,2}:\d{2}\s*;\s*(.+)$') { $l = $Matches[1].Trim() }
    if ($l) { $existentes += $l }
}
$mantenidos = @($existentes | Where-Object { $nombres -contains $_ })
$nuevos = @($nombres | Where-Object { $existentes -notcontains $_ })
$listaFinal = @($mantenidos) + $nuevos

$contenido = @(
    "# Temas RGB: lista sincronizada desde SignalRGB (boton Actualizar del widget)"
    "# Un efecto por linea (nombre EXACTO). El orden personalizado se conserva;"
    "# los efectos nuevos se agregan al final."
    ""
) + $listaFinal
Set-Content -Path $temasFile -Value $contenido -ErrorAction SilentlyContinue
Log ("sincronizado: {0} efectos ({1})" -f $listaFinal.Count, ($listaFinal -join ', '))

# publicar en el registro para el widget
try {
    if (-not (Test-Path 'HKCU:\Software\TemasRGB')) { New-Item -Path 'HKCU:\Software\TemasRGB' | Out-Null }
    Set-ItemProperty -Path 'HKCU:\Software\TemasRGB' -Name 'NTemas' -Value ([Math]::Min($listaFinal.Count, 20))
    for ($i = 1; $i -le 20; $i++) {
        $v = if ($i -le $listaFinal.Count) { $listaFinal[$i - 1] } else { '' }
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
