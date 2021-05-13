Start-Transcript -Path C:\tmp\restore_db.log

Invoke-WebRequest "https://github.com/microsoft/azure_arc/raw/main/azure_arc_sqlsrv_jumpstart/gcp/winsrv/terraform/scripts/AdventureWorksLT2019.bak" -OutFile "C:\tmp\AdventureWorksLT2019.bak"
Start-Sleep -Seconds 3
Restore-SqlDatabase -ServerInstance $env:COMPUTERNAME -Database "AdventureWorksLT2019" -BackupFile "C:\tmp\AdventureWorksLT2019.bak" -AutoRelocateFile -PassThru -Verbose

Stop-Transcript