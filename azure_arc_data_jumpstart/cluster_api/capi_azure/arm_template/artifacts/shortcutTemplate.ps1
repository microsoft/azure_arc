$new_object = New-Object -ComObject WScript.Shell
$destination = $new_object.SpecialFolders.Item("AllUsersDesktop")
$source_path = Join-Path -Path $destination -ChildPath "\\stagingName.url"
$source = $new_object.CreateShortcut($source_path)
$source.TargetPath = "https://stagingURL"
$source.Save()