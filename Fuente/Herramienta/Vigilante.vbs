' Lanzador invisible para el vigilante (relanza motor y atajos si murieron)
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Vigilante.ps1")
comando = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""& '" & script & "'; exit 0"""
sh.Run comando, 0, False
