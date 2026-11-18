' Lanzador invisible para el oyente de atajos (sin ventana de consola)
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Atajos-RGB.ps1")
comando = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""& '" & script & "'; exit 0"""
sh.Run comando, 0, False
