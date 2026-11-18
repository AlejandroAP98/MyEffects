' Lanzador invisible para sincronizar la lista con SignalRGB
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Sincronizar.ps1")
comando = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""& '" & script & "'; exit 0"""
sh.Run comando, 0, False
