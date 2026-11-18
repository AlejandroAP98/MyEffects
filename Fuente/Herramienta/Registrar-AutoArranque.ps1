# Registra las tareas de autoarranque de Temas RGB (NO requiere administrador)
# - Temas-RGB-Motor     : motor que aplica temas por hora (invisible, via VBS)
# - Temas-RGB-Atajos    : oyente de atajos de teclado (invisible, via VBS)
# - Temas-RGB-Vigilante : cada 5 min, relanza motor/atajos si murieron (via VBS)
# Todas usan lanzadores VBS (wscript) para que NUNCA aparezca una consola.
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mov = Join-Path $dir 'Motor.vbs'
$atv = Join-Path $dir 'Atajos.vbs'
$vgv = Join-Path $dir 'Vigilante.vbs'

$ajustes = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

$a1 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument """$mov"""
$a2 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument """$atv"""

$t1 = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$t2 = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

Register-ScheduledTask -TaskName "Temas-RGB-Motor"  -Action $a1 -Trigger $t1 -Principal $p -Settings $ajustes -Force | Out-Null
Register-ScheduledTask -TaskName "Temas-RGB-Atajos" -Action $a2 -Trigger $t2 -Principal $p -Settings $ajustes -Force | Out-Null

# vigilante: cada 5 min para siempre, sin limites
$a3 = New-ScheduledTaskAction -Execute "wscript.exe" -Argument """$vgv"""
$t3 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName "Temas-RGB-Vigilante" -Action $a3 -Trigger $t3 -Principal $p -Settings $ajustes -Force | Out-Null

Write-Host "Tareas registradas: Temas-RGB-Motor, Temas-RGB-Atajos y Temas-RGB-Vigilante (via VBS, sin flashes de consola)"
