function Invoke-JSSudoCommand {
    <#
    .SYNOPSIS
    Invokes sudo command in a remote session to Linux
    #>
        param (
            [Parameter(Mandatory=$true)]
            $Session,

            [Parameter(Mandatory=$true)]
            [String]
            $Command
        )
        Invoke-Command -Session $Session {
            $errFile = "/tmp/$($(New-Guid).Guid).err"
            Invoke-Expression "sudo ${using:Command} 2>${errFile}"
            $err = Get-Content $errFile -ErrorAction SilentlyContinue
            Remove-Item $errFile -ErrorAction SilentlyContinue
            If (-Not $null -eq $err)
            {
                $err | Out-String | Write-Warning
            }
        }
    }