# Temas RGB: motor + comandos para el widget (SignalRGB, sin Pro)
# Uso:
#   Residente (publica lista + rotacion):  powershell -File Temas-RGB.ps1 -Motor
#   Siguiente / anterior:                  ... -Siguiente | -Anterior
#   Tema por numero (desplegable):         ... -Numero 2
#   Tema aleatorio:                        ... -Azar
#   Ciclar rotacion automatica:            ... -Rotar   (NO, 30m, 60m, 180m, 360m, 720m)
#   Subir / bajar un tema en la lista:     ... -Subir 2 | -Bajar 2
#   Publicar la lista en el registro:      ... -Publicar
param(
    [switch]$Motor,
    [switch]$Siguiente,
    [switch]$Anterior,
    [int]$Numero = -1,
    [int]$Subir = -1,
    [int]$Bajar = -1,
    [int]$Ocultar = -1,
    [switch]$Publicar,
    [switch]$Azar,
    [switch]$Rotar
)

$dir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$temasFile = Join-Path $dir 'temas.txt'
$estado    = Join-Path $dir 'estado.txt'
$log       = Join-Path $dir 'temas.log'
$launcher  = Join-Path $env:LOCALAPPDATA 'VortxEngine\SignalRgbLauncher.exe'
$regKey    = 'HKCU:\Software\TemasRGB'
$regRoot   = 'HKCU:\Software\WhirlwindFX\SignalRgb'

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

function Escribir-Reg($nombre, $valor, $tipo = $null) {
    # helper: asegura la clave y escribe un valor (texto por defecto)
    try {
        if (-not (Test-Path $regKey)) { New-Item -Path $regKey | Out-Null }
        if ($tipo) { Set-ItemProperty -Path $regKey -Name $nombre -Value $valor -Type $tipo }
        else       { Set-ItemProperty -Path $regKey -Name $nombre -Value $valor }
    } catch {}
}

function Bloquear {
    # bloqueo simple contra escrituras simultaneas (clics rapidos en el widget)
    $p = Join-Path $dir 'bloqueo.tmp'
    $fin = (Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $fin) {
        try { return [IO.File]::Open($p, 'Create', 'ReadWrite', 'None') } catch { Start-Sleep -Milliseconds 100 }
    }
    return $null
}

function Leer-Temas {
    # auto-recuperacion: si el usuario borro temas.txt, se recrea con la lista por defecto
    if (-not (Test-Path $temasFile)) {
        $defecto = @(
            "# Temas RGB (archivo recreado automaticamente)"
            "# Un efecto por linea (nombre EXACTO en SignalRGB)"
            "# Usa el boton Actualizar del widget para sincronizar con SignalRGB"
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
        $nombre = $l
        $efecto = $l
        # prefijo "HH:MM ; Efecto" (viejo): solo el nombre
        # prefijo "<ID> ; Efecto" (efectos remotos de SignalRGB): se aplica por ID
        if ($l -match '^([^;]+?)\s*;\s*(.+)$') {
            $nombre = $Matches[2].Trim()
            $pref = $Matches[1].Trim()
            if ($pref -match '^\d{1,2}:\d{2}$') { $efecto = $nombre }
            elseif ($pref -match '^[\w-]{10,}$') { $efecto = $pref }
            else { $efecto = $nombre }  # prefijo raro (texto libre): aplicar por nombre
        }
        $out += [PSCustomObject]@{ Nombre = $nombre; Efecto = $efecto; Linea = $l }
    }
    return $out
}

function Publicar-Lista {
    # publica la lista completa de temas en el registro (para el desplegable del widget)
    $temas = Leer-Temas
    Escribir-Reg 'NTemas' ([Math]::Min($temas.Count, 20))
    $i = 0
    foreach ($t in $temas) {
        if ($i -ge 20) { break }
        $i++
        Escribir-Reg ("T{0}" -f $i) $t.Nombre
    }
    # limpiar filas viejas si la lista se acorto
    for ($k = $temas.Count + 1; $k -le 20; $k++) {
        Escribir-Reg ("T{0}" -f $k) ''
    }
    # posicion del tema activo en la lista + siguiente en el ciclo (para el widget)
    $idx = [array]::IndexOf(($temas | ForEach-Object { $_.Nombre }), (Tema-Actual))
    Escribir-Reg 'Activo' ($idx + 1)
    if ($idx -ge 0) { Escribir-Reg 'SiguienteCiclo' $temas[(($idx + 1) % $temas.Count)].Nombre }
    elseif ($temas.Count -gt 0) { Escribir-Reg 'SiguienteCiclo' $temas[0].Nombre }
}

function Aplicar-Efecto($efecto) {
    if (-not (Test-Path $launcher)) { Log "ERROR: no existe SignalRgbLauncher.exe"; return $false }
    # enfriamiento: la app procesa los efectos en cola con retraso;
    # dos cambios seguidos muy rapidos se atropellan -> esperar minimo 6 s
    $marca = Join-Path $dir 'ultimo.txt'
    if (Test-Path $marca) {
        $ult = Get-Item $marca | Select-Object -ExpandProperty LastWriteTime
        $resta = 6 - ((Get-Date) - $ult).TotalSeconds
        if ($resta -gt 0) { Start-Sleep -Seconds ([Math]::Ceiling($resta)) }
    }
    $enc = [uri]::EscapeDataString($efecto)
    $urlArg = "--url=effect/apply/${enc}?-silentlaunch-"
    try {
        Start-Process -FilePath $launcher -ArgumentList $urlArg -WindowStyle Hidden
        Set-Content -Path $marca -Value (Get-Date) -ErrorAction SilentlyContinue
        return $true
    } catch {
        Log ("ERROR al aplicar '{0}': {1}" -f $efecto, $_.Exception.Message)
        return $false
    }
}

function Marcar-Tema($nombre) {
    # guarda el tema aplicado en estado.txt y en el registro (para el widget)
    Set-Content -Path $estado -Value $nombre -ErrorAction SilentlyContinue
    Escribir-Reg 'Tema' $nombre
    # posicion en la lista + siguiente en el ciclo (para el punto y el "siguiente")
    $lista = Leer-Temas
    $idx = [array]::IndexOf(($lista | ForEach-Object { $_.Nombre }), $nombre)
    if ($idx -ge 0) {
        Escribir-Reg 'Activo' ($idx + 1)
        Escribir-Reg 'SiguienteCiclo' $lista[(($idx + 1) % $lista.Count)].Nombre
    } elseif ($lista.Count -gt 0) {
        # el activo no esta en la lista (ocultado): sugerir el primero visible
        Escribir-Reg 'Activo' 0
        Escribir-Reg 'SiguienteCiclo' $lista[0].Nombre
    }
}

function Tema-Actual {
    if (Test-Path $estado) { return (Get-Content $estado -ErrorAction SilentlyContinue) }
    return ''
}

function Cambiar-ATema($t, $motivo) {
    if (Aplicar-Efecto $t.Efecto) {
        Marcar-Tema $t.Nombre
        Log ("{0} -> '{1}' ({2})" -f $motivo, $t.Nombre, $t.Efecto)
        return $true
    }
    return $false
}

# ---- Modo comandos one-shot ----
if ($Azar) {
    $temas = Leer-Temas
    if ($temas.Count -gt 0) {
        $candidatos = @($temas | Where-Object { $_.Nombre -ne (Tema-Actual) })
        if ($candidatos.Count -eq 0) { $candidatos = $temas }
        [void](Cambiar-ATema ($candidatos | Get-Random) 'azar')
    }
    exit 0
}

if ($Rotar) {
    # cicla el intervalo de rotacion: NO -> 30m -> 60m -> 180m -> 360m -> 720m -> NO
    $pasos = @(0, 30, 60, 180, 360, 720)
    $actualR = 0
    try { $actualR = [int]((Get-ItemProperty $regKey -EA SilentlyContinue).RotacionMin) } catch {}
    $idxR = [array]::IndexOf($pasos, $actualR)
    if ($idxR -lt 0) { $idxR = 0 }
    $nuevoR = $pasos[($idxR + 1) % $pasos.Count]
    $txtR = if ($nuevoR -eq 0) { 'NO' } else { "$nuevoR m" }
    $colR = if ($nuevoR -eq 0) { '242,242,242' } else { '190,120,255' }
    Escribir-Reg 'RotacionMin' "$nuevoR" 'String'
    Escribir-Reg 'RotacionTxt' $txtR 'String'
    Escribir-Reg 'RotacionColor' $colR 'String'
    Escribir-Reg 'UltimaRot' ([DateTimeOffset]::Now.ToUnixTimeSeconds()) 'QWord'
    # barra superior: progresiva cuando hay rotacion, completa cuando NO
    Escribir-Reg 'RotacionProg' $(if ($nuevoR -eq 0) { 100 } else { 0 })
    Escribir-Reg 'RotacionResta' $(if ($nuevoR -eq 0) { 0 } else { $nuevoR })
    Log ("rotacion automatica: cada $txtR")
    exit 0
}

if ($Publicar) {
    Publicar-Lista
    exit 0
}

if ($Ocultar -ge 1) {
    # ocultar el tema N de la lista: lo convierte en comentario en temas.txt
    # (no se pierde: vuelve a la lista con el boton Actualizar o editando el archivo)
    $fs = Bloquear
    try {
        $lineas = @(Get-Content $temasFile -EA SilentlyContinue)
        $visibles = 0
        for ($i = 0; $i -lt $lineas.Count; $i++) {
            $t = $lineas[$i].Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $visibles++
            if ($visibles -eq $Ocultar) {
                $lineas[$i] = '# ' + $t
                Set-Content -Path $temasFile -Value $lineas -ErrorAction SilentlyContinue
                Log ("ocultado de la lista: '{0}' (vuelve con Actualizar)" -f $t)
                Publicar-Lista
                break
            }
        }
    } finally { if ($fs) { $fs.Close() } }
    exit 0
}

if ($Subir -ge 1 -or $Bajar -ge 1) {
    $fs = Bloquear
    try {
        $temas = Leer-Temas
        $delta = if ($Subir -ge 1) { -1 } else { 1 }
        $idx = if ($Subir -ge 1) { $Subir - 1 } else { $Bajar - 1 }
        $j = $idx + $delta
        if ($idx -ge 0 -and $idx -lt $temas.Count -and $j -ge 0 -and $j -lt $temas.Count) {
            $cab = @(Get-Content $temasFile -EA SilentlyContinue | Where-Object { $_.Trim() -eq '' -or $_.Trim().StartsWith('#') })
            $arr = @($temas | ForEach-Object { $_.Linea })
            $tmp = $arr[$idx]; $arr[$idx] = $arr[$j]; $arr[$j] = $tmp
            Set-Content -Path $temasFile -Value (@($cab) + $arr) -ErrorAction SilentlyContinue
            Log ("orden cambiado: '{0}' -> posicion {1}" -f $temas[$idx].Nombre, ($j + 1))
            Publicar-Lista
        }
    } finally { if ($fs) { $fs.Close() } }
    exit 0
}

if ($Siguiente -or $Anterior -or $Numero -ge 1) {
    $temas = Leer-Temas
    if (-not $temas) { Write-Host "No hay temas en temas.txt"; exit 1 }
    $idx = [array]::IndexOf(($temas | ForEach-Object { $_.Nombre }), (Tema-Actual))
    if ($idx -lt 0) { $idx = 0 }
    if ($Siguiente)      { $nuevo = ($idx + 1) % $temas.Count }
    elseif ($Anterior)   { $nuevo = ($idx - 1 + $temas.Count) % $temas.Count }
    else                 { $nuevo = [Math]::Min($Numero - 1, $temas.Count - 1) }
    [void](Cambiar-ATema $temas[$nuevo] 'cambio manual')
    if (-not $Motor) { Write-Host ("  [OK]   Tema '{0}' aplicado" -f $temas[$nuevo].Nombre) }
    exit 0
}

# ---- Modo daemon (publicador + rotacion) ----
# Cada minuto: publica la lista en el registro y aplica la rotacion
# automatica si esta activa (cambia al siguiente tema cada N minutos).
# una sola instancia: si ya hay otro motor vivo, salir en silencio
$ya = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like "*Temas-RGB.ps1*-Motor*" })
if ($ya.Count -gt 0) { Log "motor duplicado ignorado"; exit 0 }
Log "publicador de temas iniciado"
while ($true) {
    try {
        Publicar-Lista
        $rot = 0
        try { $rot = [int]((Get-ItemProperty $regKey -EA SilentlyContinue).RotacionMin) } catch {}
        if ($rot -gt 0) {
            $ahora = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $ultima = [int64]0
            try { $ultima = [int64]((Get-ItemProperty $regKey -EA SilentlyContinue).UltimaRot) } catch {}
            if ($ultima -eq 0) {
                Escribir-Reg 'UltimaRot' $ahora
                Escribir-Reg 'RotacionProg' 0
            } else {
                # progreso y tiempo restante para la barra superior y la etiqueta
                $prog = [Math]::Min(100, [Math]::Max(0, [int](100 * ($ahora - $ultima) / ($rot * 60))))
                Escribir-Reg 'RotacionProg' $prog
                $resta = [Math]::Max(0, [int]([Math]::Ceiling((($rot * 60) - ($ahora - $ultima)) / 60)))
                Escribir-Reg 'RotacionResta' $resta
            }
            if ($ahora - $ultima -ge ($rot * 60)) {
                $temas = Leer-Temas
                if ($temas.Count -gt 1) {
                    $idx = [array]::IndexOf(($temas | ForEach-Object { $_.Nombre }), (Tema-Actual))
                    if ($idx -lt 0) { $idx = 0 }
                    [void](Cambiar-ATema $temas[(($idx + 1) % $temas.Count)] ("rotacion ($rot min)"))
                    Escribir-Reg 'UltimaRot' $ahora
                }
            }
        } else {
            # rotacion en NO: barra completa, sin cuenta regresiva; completa el estado si el registro esta vacio
            Escribir-Reg 'RotacionProg' 100
            Escribir-Reg 'RotacionResta' 0
            Escribir-Reg 'RotacionMin' '0' 'String'
            Escribir-Reg 'RotacionTxt' 'NO' 'String'
            Escribir-Reg 'RotacionColor' '242,242,242' 'String'
        }
    } catch {
        # nunca morir en silencio: registrar y seguir
        Log ("ERROR en el ciclo del publicador: {0}" -f $_.Exception.Message)
    }
    Start-Sleep -Seconds 60
}
