# Oyente de atajos globales para temas RGB (residente, invisible, minimo consumo)
# Atajos:
#   Ctrl + Alt + ->   siguiente tema
#   Ctrl + Alt + <-   tema anterior
#   Ctrl + Alt + P    apagar luces (Solid Color como sustituto de pausa)
$dir       = Split-Path -Parent $MyInvocation.MyCommand.Path
# una sola instancia: si ya hay otro oyente vivo, salir en silencio
$ya = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*Atajos-RGB.ps1*" })
if ($ya.Count -gt 0) { exit 0 }
$launcher  = Join-Path $env:LOCALAPPDATA 'VortxEngine\SignalRgbLauncher.exe'
$temasFile = Join-Path $dir 'temas.txt'
$estado    = Join-Path $dir 'estado.txt'
$log       = Join-Path $dir 'temas.log'
$regKey    = 'HKCU:\Software\TemasRGB'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Teclas {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
'@

function Log($m) {
    Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -ErrorAction SilentlyContinue
}

function TeclaPulsada($vk) { ([Teclas]::GetAsyncKeyState($vk) -band 0x8000) -ne 0 }

function Leer-Temas {
    # auto-recuperacion: si el usuario borro temas.txt, se recrea con la lista por defecto
    if (-not (Test-Path $temasFile)) {
        $defecto = @(
            "# Temas RGB (archivo recreado automaticamente)"
            "# Un efecto por linea (nombre EXACTO en SignalRGB)"
            ""
            "Neon Shift"
            "Rainbow"
            "Neon Storm"
            "Solid Color"
        )
        Set-Content -Path $temasFile -Value $defecto -ErrorAction SilentlyContinue
        Log "temas.txt no existia -> recreado con la lista por defecto"
    }
    $out = @()
    foreach ($l in (Get-Content $temasFile -ErrorAction SilentlyContinue)) {
        $l = $l.Trim()
        if ($l -eq '' -or $l.StartsWith('#')) { continue }
        # compatibilidad: si la linea trae "HH:MM ; Efecto" se ignora la hora
        if ($l -match '^\d{1,2}:\d{2}\s*;\s*(.+)$') { $l = $Matches[1].Trim() }
        $out += [PSCustomObject]@{ Nombre = $l; Efecto = $l }
    }
    return $out
}

function Cambiar($offset) {
    $temas = Leer-Temas
    if ($temas.Count -eq 0) { return }
    # enfriamiento: la app procesa los efectos con retraso; dos cambios
    # seguidos muy rapidos se atropellan -> ignorar si hace menos de 6 s
    $marca = Join-Path $dir 'ultimo.txt'
    if (Test-Path $marca) {
        $ult = Get-Item $marca | Select-Object -ExpandProperty LastWriteTime
        if (((Get-Date) - $ult).TotalSeconds -lt 6) { Log "cambio ignorado (enfriamiento 6 s)"; return }
    }
    $actual = ''
    if (Test-Path $estado) { $actual = (Get-Content $estado -ErrorAction SilentlyContinue) }
    $idx = [array]::IndexOf(($temas | ForEach-Object { $_.Nombre }), $actual)
    if ($idx -lt 0) { $idx = 0 }
    $nuevo = ($idx + $offset + $temas.Count) % $temas.Count
    $t = $temas[$nuevo]
    $enc = [uri]::EscapeDataString($t.Efecto)
    Start-Process -FilePath $launcher -ArgumentList "--url=effect/apply/${enc}?-silentlaunch-" -WindowStyle Hidden
    Set-Content -Path $marca -Value (Get-Date) -ErrorAction SilentlyContinue
    Set-Content -Path $estado -Value $t.Nombre -ErrorAction SilentlyContinue
    try {
        if (-not (Test-Path $regKey)) { New-Item -Path $regKey | Out-Null }
        Set-ItemProperty -Path $regKey -Name 'Tema' -Value $t.Nombre
    } catch {}
    Log ("atajo -> '{0}' ({1})" -f $t.Nombre, $t.Efecto)
}

function Pausa-Luces {
    # apaga las luces aplicando Solid Color (sustituto de pausa)
    $marca = Join-Path $dir 'ultimo.txt'
    if (Test-Path $marca) {
        $ult = Get-Item $marca | Select-Object -ExpandProperty LastWriteTime
        if (((Get-Date) - $ult).TotalSeconds -lt 6) { return }
    }
    Start-Process -FilePath $launcher -ArgumentList "--url=effect/apply/Solid%20Color?-silentlaunch-" -WindowStyle Hidden
    Set-Content -Path $marca -Value (Get-Date) -ErrorAction SilentlyContinue
    Log "atajo de pausa -> Solid Color (sustituto de pausa)"
}

# espera soltar teclas para no disparar doble
function Esperar-Soltar($vk) {
    while (TeclaPulsada $vk) { Start-Sleep -Milliseconds 80 }
}

Log "oyente de atajos iniciado"
while ($true) {
    try {
        if (TeclaPulsada 0x11 -and TeclaPulsada 0x12) {          # Ctrl + Alt
            if (TeclaPulsada 0x27) { Cambiar 1;  Esperar-Soltar 0x27 }
            elseif (TeclaPulsada 0x25) { Cambiar -1; Esperar-Soltar 0x25 }
            elseif (TeclaPulsada 0x50) { Pausa-Luces; Esperar-Soltar 0x50 }
        }
    } catch {
        # nunca morir en silencio: registrar y seguir
        Log ("ERROR en el oyente de atajos: {0}" -f $_.Exception.Message)
    }
    Start-Sleep -Milliseconds 100
}
