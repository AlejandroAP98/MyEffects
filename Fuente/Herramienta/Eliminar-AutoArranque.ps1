# Elimina las tareas de autoarranque de Temas RGB y cierra los residentes
Unregister-ScheduledTask -TaskName "Temas-RGB-Motor" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "Temas-RGB-Atajos" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "Temas-RGB-Vigilante" -Confirm:$false -ErrorAction SilentlyContinue

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'Temas-RGB\.ps1|Atajos-RGB\.ps1|Vigilante\.ps1' } |
    ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }

Write-Host "Tareas eliminadas y procesos cerrados"
