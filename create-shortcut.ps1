# Create Desktop Shortcut for GuijiAPI

$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $DesktopPath "GuijiAPI Install.lnk"
$ScriptDir = "D:\04 Projects\GuijiAPI"
$TargetScript = Join-Path $ScriptDir "quick-install.ps1"

$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$TargetScript`""
$Shortcut.WorkingDirectory = $ScriptDir
$Shortcut.Description = "GuijiAPI Claude Code Quick Install"
$Shortcut.Save()

Write-Host ""
Write-Host "Desktop shortcut created!" -ForegroundColor Green
Write-Host "Location: $ShortcutPath" -ForegroundColor White
Write-Host ""
