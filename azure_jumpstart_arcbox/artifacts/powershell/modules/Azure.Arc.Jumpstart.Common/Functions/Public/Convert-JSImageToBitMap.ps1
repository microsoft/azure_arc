function Convert-JSImageToBitMap {
    param (
        $SourceFilePath,
        $DestinationFilePath
    )
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $file = Get-Item $SourceFilePath
    $convertfile = new-object System.Drawing.Bitmap($file.Fullname)
    $convertfile.Save($newfilname, "bmp")
}