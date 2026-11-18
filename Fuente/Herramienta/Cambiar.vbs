' Lanzador invisible para cambiar temas (sin ventana de consola)
' Uso: wscript.exe Cambiar.vbs -Siguiente | -Anterior | -Numero 2 | -Azar | -Rotar | -Publicar | -Subir n | -Bajar n
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Temas-RGB.ps1")
args = ""
For Each a In WScript.Arguments
    args = args & " " & a
Next
comando = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""& '" & script & "'" & args & "; exit 0"""
sh.Run comando, 0, False
