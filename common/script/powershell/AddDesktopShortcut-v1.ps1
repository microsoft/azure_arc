#requires -version 2

<#
.SYNOPSIS
  Create desktop shortcut
.EXAMPLE
  Add-Desktop-Shortcut -shortcutName "CAPI Bookstore" -iconLocation "bookstore" -targetPath "powershell.exe" -arguments "-ExecutionPolicy Bypass -File $Env:ArcBoxDir\BookStoreLaunch.ps1" -windowsStyle 7
#>
function Add-Desktop-Shortcut {
    param(
        [string] $icon,
        [string] $shortcutName,
        [string] $targetPath,
        [string] $arguments,
        [string] $windowsStyle = 3,
        [string] $username
    )
    #If WindowStyle is 1, then the application window will be set to its default location and size. If this property has a value of 3, the application will be launched in a maximized window, and if it has a value of 7, it will be launched in a minimized window.
    Write-Output "`n"
    Write-Output "Creating $shortcutName Desktop shortcut"
    Write-Output "`n"
    if ( -not $username) {
        $shortcutLocation = "$Env:Public\Desktop\$shortcutName.lnk"
    }
    else {
        $shortcutLocation = "C:\Users\$username\Desktop\$shortcutName.lnk"
    }
    $wScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $wScriptShell.CreateShortcut($shortcutLocation)
    $shortcut.TargetPath = $targetPath
    if ($arguments) {
        $shortcut.Arguments = $arguments
    }
    if ($icon) {
        $shortcut.IconLocation = "${Env:ArcBoxIconDir}\$icon.ico, 0"
    }
    $shortcut.WindowStyle = $windowsStyle
    $shortcut.Save()
}