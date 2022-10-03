
param(
    [string]
    $NCIP = "restserver",
    [object]
    $NCCredential=  [System.Management.Automation.PSCredential]::Empty,
    [bool]
    $EnableMultiWindow = $true,
    [bool]
    $IsModule = $false
)

function GenerateMainForm { 

param(
        [Parameter(mandatory=$true)]
        [object[]] $DataArr
    )

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = “SDN Explorer NC:$NCIP” 
    $ExplorerForm.Name = “SDN Explorer NC:$NCIP” 
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    # panel to have scroll bar
    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = [System.Drawing.Color]::Silver
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $panel.Location = New-Object System.Drawing.Point (5,5)


    $System_Drawing_Point = New-Object System.Drawing.Point 
    $System_Drawing_Point.X = 80 
    $System_Drawing_Point.Y = 20 
    for ($it = 0; $it -lt $DataArr.Count ;$it++)
    {
        $button = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 240 
        $System_Drawing_SizeButton.Height = 23 
        $button.TabIndex = 0 
        $button.Name = “UnlockAccountButton” 
        $button.Size = $System_Drawing_SizeButton 
        $button.UseVisualStyleBackColor = $True
        $button.Text = $DataArr[$it].Name
        $button.Location = $System_Drawing_Point 
        $button.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock = $DataArr[$it].Value[0]
        $button.add_Click($scriptBlock)
        $panel.Controls.Add($button)


        $putButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 60 
        $System_Drawing_SizeButton.Height = 23 
        $putButton.TabIndex = 0 
        $putButton.Name = "Put” 
        $putButton.Size = $System_Drawing_SizeButton 
        $putButton.UseVisualStyleBackColor = $True
        $putButton.Text = "Put"
        $putButton.Location = New-Object System.Drawing.Size(340,$System_Drawing_Point.Y)  
        $putButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        if($DataArr[$it].Value.Count -gt 1)
        {
            $scriptBlock = $DataArr[$it].Value[1]
        }
        else
        {
            $putButton.Enabled = $false
        }
        $putButton.add_Click($scriptBlock)
        $panel.Controls.Add($putButton)


        $DeleteButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 60 
        $System_Drawing_SizeButton.Height = 23 
        $DeleteButton.TabIndex = 0 
        $DeleteButton.Name = "Delete” 
        $DeleteButton.Size = $System_Drawing_SizeButton 
        $DeleteButton.UseVisualStyleBackColor = $True
        $DeleteButton.Text = "Delete"
        $DeleteButton.Location = New-Object System.Drawing.Size(420,$System_Drawing_Point.Y)  
        $DeleteButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        if($DataArr[$it].Value.Count -gt 2)
        {
            $scriptBlock = $DataArr[$it].Value[2]
        }
        else
        {
            $DeleteButton.Enabled = $false
        }
        $DeleteButton.add_Click($scriptBlock)
        $panel.Controls.Add($DeleteButton)


        $System_Drawing_Point.Y += 33
    }


    if($System_Drawing_Point.Y -ge 700)
    {
        $yPoint = 700
    }
    else
    {
        $yPoint = $System_Drawing_Point.Y + 50
    }

    $System_Drawing_Size = New-Object System.Drawing.Size 
    $System_Drawing_Size.Width = 560
    $System_Drawing_Size.Height = $yPoint
    $ExplorerForm.ClientSize = $System_Drawing_Size

    $System_Drawing_Size.Width -= 10
    $System_Drawing_Size.Height -= 10
    $panel.Size = $System_Drawing_Size
    $panel.AutoScroll = $true
    $ExplorerForm.Controls.Add($panel)

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 
    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null

}

function GenerateArrayForm { 

param(
        [Parameter(mandatory=$true)]
        [string] $HandlerFunc,

        [Parameter(mandatory=$true)]
        [string] $RemoveFunc,

        [Parameter(mandatory=$true)]
        [string] $NCIP,

        [Parameter(mandatory=$false)]
        [object]
        $NCCredential=  [System.Management.Automation.PSCredential]::Empty,
		
		[Parameter(mandatory=$true)]        
		[bool]
		$EnableMultiWindow=$true
    )

    if ($HandlerFunc -eq "Get-NCConnectivityCheckResult" -and $script:ncVMCredentials -eq [System.Management.Automation.PSCredential]::Empty)
    {
        $script:ncVMCredentials = Get-Credential -Message "Please give administrator credential of NC" -UserName "Administrator"
    }


    if($EnableMultiWindow)
    {
        $progress = [powershell]::create()

        $progressScript = {	
            param(
            [string] $HandlerFunc,            
            [string] $RemoveFunc,
            [string] $NCIP,
            [object] $NCCredential=  [System.Management.Automation.PSCredential]::Empty,
		    [bool]   $EnableMultiWindow=$true,
            [string] $CurWorDir,
            [object] $NCVMCredential=  [System.Management.Automation.PSCredential]::Empty
            )

            try{
                
                Set-Location $CurWorDir
                Import-Module .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true
                GenerateArrayFormHelper -HandlerFunc $HandlerFunc -RemoveFunc $RemoveFunc -NCIP $NCIP -NCCredential $NCCredential -EnableMultiWindow $EnableMultiWindow -NCVMCredential $NCVMCredential                                                 
            }
            catch
            {
                 [System.Windows.Forms.MessageBox]::Show($_) 
            }
	    }

        $parameters = @{}
        $parameters.HandlerFunc = $HandlerFunc
        $parameters.RemoveFunc = $RemoveFunc
        $parameters.NCIP = $NCIP
        $parameters.NCCredential = $NCCredential
        $parameters.EnableMultiWindow = $EnableMultiWindow
        $parameters.CurWorDir = $pwd
        $parameters.NCVMCredential = $script:ncVMCredentials
        
        $progress.AddScript($progressScript)	
        $progress.AddParameters($parameters)      
        $progress.BeginInvoke()                      		                                               
	    
    }       
    else{
        GenerateArrayFormHelper -HandlerFunc $HandlerFunc -RemoveFunc $RemoveFunc -NCIP $NCIP -NCCredential $NCCredential -EnableMultiWindow $EnableMultiWindow -NCVMCredential $script:ncVMCredentials
    }

}

function GenerateArrayFormHelper { 

param(
        [Parameter(mandatory=$true)]
        [string] $HandlerFunc,

        [Parameter(mandatory=$true)]
        [string] $RemoveFunc,

        [Parameter(mandatory=$true)]
        [string] $NCIP,

        [Parameter(mandatory=$false)]
        [object]
        $NCCredential=  [System.Management.Automation.PSCredential]::Empty,
		
		[Parameter(mandatory=$true)]        
		[bool]
		$EnableMultiWindow=$true,

        [Parameter(mandatory=$false)]
        [object]
        $NCVMCredential=  [System.Management.Automation.PSCredential]::Empty
    )

    . .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = “$HandlerFunc NC:$NCIP” 
    $ExplorerForm.Name = “$HandlerFunc NC:$NCIP” 
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    # panel to have scroll bar
    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = [System.Drawing.Color]::Silver
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $panel.Location = New-Object System.Drawing.Point (5,5)

    $extraSpace = 0

    $dataArr = @()
    $dataArr += &$HandlerFunc

    $failed = $false
    foreach ($data in $dataArr)
    {
        if ($data.PSobject.Properties.name -match "nextLink")
        {
            $failed = $true
            break;
        }
    }

    $System_Drawing_Point = New-Object System.Drawing.Point 
    $System_Drawing_Point.X = 80
    $System_Drawing_Point.Y = 20

    if ($HandlerFunc -eq "Get-NCConnectivityCheckResult")
    {
        $diagButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 240 
        $System_Drawing_SizeButton.Height = 23 
        $diagButton.TabIndex = 0 
        $diagButton.Name = $data.resourceRef
        $diagButton.Size = $System_Drawing_SizeButton 
        $diagButton.UseVisualStyleBackColor = $True
        $diagButton.Text = "PUT=>/diagnostics/networkcontrollerstate"
        $diagButton.Location = $System_Drawing_Point 
        $diagButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        $diagButton_add = $diagButton.add_Click
        $diagButton_add.Invoke({

            try
            {
                $verify = VerifyUserAction -String "Do you want to Put networkcontrollerstate?"

                if ($verify -eq $true)
                {                
                    $object = @{}
                    $object.properties = @{}
                    JSONPost -path "/diagnostics/networkcontrollerstate" -bodyObject $object
                    [System.Windows.Forms.MessageBox]::Show("Posted!!!") 
                }
            }
            catch
            {
                [System.Windows.Forms.MessageBox]::Show($_) 
            }
            })
        $panel.Controls.Add($diagButton)
        $System_Drawing_Point.Y += 33

        
        # Adding network controller statistics button
        $ncStatsButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 240 
        $System_Drawing_SizeButton.Height = 23 
        $ncStatsButton.TabIndex = 1 
        $ncStatsButton.Name = $data.resourceRef
        $ncStatsButton.Size = $System_Drawing_SizeButton 
        $ncStatsButton.UseVisualStyleBackColor = $True
        $ncStatsButton.Text = "GET=>/monitoring/networkcontrollerstatistics"
        $ncStatsButton.Location = $System_Drawing_Point 
        $ncStatsButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        $ncStatsButton_add = $ncStatsButton.add_Click
        $ncStatsButton_add.Invoke({
                param([object]$sender)

                if($EnableMultiWindow)
                {
                	$ps = [powershell]::create()

                    $script = {	
                        param(
                        [string] $ResourceRef,

                        [string] $NCIP,

                        [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty,

                        [string]$CurWorDir,

                        [bool]$EnableMultiWindow

                        )	
                            try{
                            
                                Set-Location $CurWorDir
                                Import-Module -Force -Name .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true
                                JsonForm -ResourceRef $ResourceRef -NCIP $NCIP -NCCredential $NCCredential -EnableMultiWindow $true
                            }
                            catch{
                                [System.Windows.Forms.MessageBox]::Show($_)                             
                            }
			            }
                        $parameters = @{}
                        $parameters.ResourceRef = "/monitoring/networkcontrollerstatistics"
                        $parameters.NCIP = $NCIP
                        $parameters.NCCredential = $NCCredential
                        $parameters.CurWorDir = $pwd
                        $parameters.EnableMultiWindow = $EnableMultiWindow

	    	            $ps.AddScript(
			                $script
		                )		
                    $ps.AddParameters($parameters)
		            $ps.BeginInvoke()
                }
                else
                {
                    JsonForm -ResourceRef $sender.Text -NCIP $NCIP -NCCredential $NCCredential
                }
                
              })
        $panel.Controls.Add($ncStatsButton)
        $System_Drawing_Point.Y += 33

        $debugSFNSButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 240 
        $System_Drawing_SizeButton.Height = 23 
        $debugSFNSButton.TabIndex = 0 
        $debugSFNSButton.Name = "Debug-ServiceFabricNodeStatus"
        $debugSFNSButton.Size = $System_Drawing_SizeButton 
        $debugSFNSButton.UseVisualStyleBackColor = $True
        $debugSFNSButton.Text = "Debug-ServiceFabricNodeStatus"
        $debugSFNSButton.Location = $System_Drawing_Point 
        $debugSFNSButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        $debugSFNSButton_add = $debugSFNSButton.add_Click
        $debugSFNSButton.Enabled = $false
        $debugSFNSButton_add.Invoke({

            if ($EnableMultiWindow)
            {
                $ps = [powershell]::create()

                $script = {	
                    param(                   

                    [string]$Cmdlet,

                    [object]$NCVMCredential=  [System.Management.Automation.PSCredential]::Empty,

                    [string] $NCIP,

                    [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty,

                    [string]$CurWorDir,

                    [bool]$EnableMultiWindow
                    )	

                    try{
                            Set-Location $CurWorDir
                            Import-Module .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true                            
                            RunNCCMDLet -CmdLet $Cmdlet -NCVMCred $NCVMCredential -NCIP $NCIP                                                                      
                    }
                        catch{
                            [System.Windows.Forms.MessageBox]::Show($_) 
                        }
			        }
                    $parameters = @{}
                    $parameters.Cmdlet = "Debug-ServiceFabricNodeStatus"
                    $parameters.NCVMCredential = $NCVMCredential
                    $parameters.NCIP = $NCIP
                    $parameters.NCCredential = $NCCredential
                    $parameters.CurWorDir = $pwd
                    $parameters.EnableMultiWindow = $EnableMultiWindow
	    	        $ps.AddScript(
			            $script
		            )		
                $ps.AddParameters($parameters)
		        $ps.BeginInvoke()                
            }
            else
            {
                RunNCCMDLet -CmdLet "Debug-ServiceFabricNodeStatus" -NCVMCred $NCVMCredential -NCIP $NCIP   
            }
        })
        $panel.Controls.Add($debugSFNSButton)
        $System_Drawing_Point.Y += 33

        $debugNCCSButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 240 
        $System_Drawing_SizeButton.Height = 23 
        $debugNCCSButton.TabIndex = 0 
        $debugNCCSButton.Name = "Debug-NetworkControllerConfigurationState"
        $debugNCCSButton.Size = $System_Drawing_SizeButton 
        $debugNCCSButton.UseVisualStyleBackColor = $True
        $debugNCCSButton.Text = "Debug-NetworkControllerConfigurationState"
        $debugNCCSButton.Location = $System_Drawing_Point 
        $debugNCCSButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        $debugNCCSButton_add = $debugNCCSButton.add_Click
        $debugNCCSButton_add.Invoke({

            if ($EnableMultiWindow)
            {
                $ps = [powershell]::create()

                $script = {	
                    param(                   

                    [string]$Cmdlet,

                    [object]$NCVMCredential=  [System.Management.Automation.PSCredential]::Empty,

                    [string] $NCIP,

                    [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty,

                    [string]$CurWorDir,

                    [bool]$EnableMultiWindow
                    )	

                    try{
                            Set-Location $CurWorDir
                            Import-Module .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true                            
                            RunNCCMDLet -CmdLet $Cmdlet -NCVMCred $NCVMCredential -NCIP $NCIP                                                                    
                    }
                        catch{
                            [System.Windows.Forms.MessageBox]::Show($_) 
                        }
			        }
                    $parameters = @{}
                    $parameters.Cmdlet = "Debug-NetworkControllerConfigurationState"
                    $parameters.NCVMCredential = $NCVMCredential
                    $parameters.NCIP = $NCIP
                    $parameters.NCCredential = $NCCredential
                    $parameters.CurWorDir = $pwd
                    $parameters.EnableMultiWindow = $EnableMultiWindow
	    	        $ps.AddScript(
			            $script
		            )		
                $ps.AddParameters($parameters)
		        $ps.BeginInvoke()                
            }
            else
            {
                RunNCCMDLet -CmdLet "Debug-NetworkControllerConfigurationState" -NCVMCred $NCVMCredential -NCIP $NCIP   
            }
        })
        $panel.Controls.Add($debugNCCSButton)
        $System_Drawing_Point.Y += 33

        $debugNCButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 240 
        $System_Drawing_SizeButton.Height = 23 
        $debugNCButton.TabIndex = 0 
        $debugNCButton.Name = "Debug-NetworkController"
        $debugNCButton.Size = $System_Drawing_SizeButton 
        $debugNCButton.UseVisualStyleBackColor = $True
        $debugNCButton.Text = "Debug-NetworkController"
        $debugNCButton.Location = $System_Drawing_Point 
        $debugNCButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        $debugNCButton_add = $debugNCButton.add_Click
        $debugNCButton_add.Invoke({

            if ($EnableMultiWindow)
            {
                $ps = [powershell]::create()

                $script = {	
                    param(                   

                    [string]$Cmdlet,

                    [object]$NCVMCredential=  [System.Management.Automation.PSCredential]::Empty,

                    [string] $NCIP,

                    [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty,

                    [string]$CurWorDir,

                    [bool]$EnableMultiWindow
                    )	

                    try{
                            Set-Location $CurWorDir
                            Import-Module .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true                            
                            RunNCCMDLet -CmdLet $Cmdlet -NCVMCred $NCVMCredential -NCIP $NCIP                                                                         
                    }
                        catch{
                            [System.Windows.Forms.MessageBox]::Show($_) 
                        }
			        }
                    $parameters = @{}
                    $parameters.Cmdlet = "Debug-NetworkController"
                    $parameters.NCVMCredential = $NCVMCredential
                    $parameters.NCIP = $NCIP
                    $parameters.NCCredential = $NCCredential
                    $parameters.CurWorDir = $pwd
                    $parameters.EnableMultiWindow = $EnableMultiWindow
	    	        $ps.AddScript(
			            $script
		            )		
                $ps.AddParameters($parameters)
		        $ps.BeginInvoke()                
            }
            else
            {
                RunNCCMDLet -CmdLet "Debug-NetworkController" -NCVMCred $NCVMCredential -NCIP $NCIP   
            }

            [System.Windows.Forms.MessageBox]::Show("Started your request in background!!") 
        })
        $panel.Controls.Add($debugNCButton)
        $System_Drawing_Point.Y += 33
        
    }
    elseif ($HandlerFunc -eq "Get-NCServer")
    {
        $runButton = New-Object System.Windows.Forms.Button 
        $System_Drawing_SizeButton = New-Object System.Drawing.Size 
        $System_Drawing_SizeButton.Width = 280 
        $System_Drawing_SizeButton.Height = 23 
        $runButton.TabIndex = 0 
        $runButton.Name = $data.resourceRef
        $runButton.Size = $System_Drawing_SizeButton 
        $runButton.UseVisualStyleBackColor = $True
        $runButton.Text = "--Run Script Block--"
        $locationY = $System_Drawing_Point.Y + 1
        $runButton.Location = New-Object System.Drawing.Size(10,$locationY)  
        $runButton.DataBindings.DefaultDataSourceUpdateMode = 0 
        $runButton_add = $runButton.add_Click
        $runButton_add.Invoke({
            if ($EnableMultiWindow)
            {
                $ps = [powershell]::create()

                $script = {	
                    param(                   

                    [object[]]$jsonObject,

                    [string]$CurWorDir,

                    [bool]$EnableMultiWindow
                    )	

                    try{
                            Set-Location $CurWorDir
                            Import-Module .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true                            
                            RunScriptForm -Servers $jsonObject                                                                         
                    }
                        catch{
                            [System.Windows.Forms.MessageBox]::Show($_) 
                        }
			        }
                    $parameters = @{}
                    $parameters.jsonObject = $dataArr
                    $parameters.CurWorDir = $pwd
                    $parameters.EnableMultiWindow = $EnableMultiWindow
	    	        $ps.AddScript(
			            $script
		            )		
                $ps.AddParameters($parameters)
		        $ps.BeginInvoke()                
            }
            else
            {
                RunScriptForm -Servers $dataArr
            }
        })
        $panel.Controls.Add($runButton)
        $System_Drawing_Point.Y += 33
    }


    if ($dataArr.Count -gt 0 -and $failed -eq $false)
    {
        if ($dataArr.Count -ge 1)
        { 
            if ($DataArr[0].resourceRef.Contains("networkInterfaces") -or $DataArr[0].resourceRef.Contains("loadBalancers"))
            {
                $extraSpace = 40
            }
        }

        foreach ($data in $dataArr)
        {
            $System_Drawing_Point.X = 10
            $button = New-Object System.Windows.Forms.Button 
            $button.TabIndex = 0 
            $button.Name = $data.resourceRef
            $button.Size = New-Object System.Drawing.Size(280,23)
            $button.UseVisualStyleBackColor = $True
            $button.Text = $data.resourceRef
            $locationY = $System_Drawing_Point.Y + 1
            $button.Location = New-Object System.Drawing.Size(10,$locationY)  
            $button.DataBindings.DefaultDataSourceUpdateMode = 0 
            $button_add = $button.add_Click
            $button_add.Invoke({

                param([object]$sender,[string]$message)

                if($EnableMultiWindow)
                {
                	$ps = [powershell]::create()

                    $script = {	
                        param(
                        [string] $ResourceRef,

                        [string] $NCIP,

                        [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty,

                        [string]$CurWorDir,

                        [bool]$EnableMultiWindow

                        )	
                            try{
                            
                                Set-Location $CurWorDir
                                Import-Module -Force -Name .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true
                                JsonForm -ResourceRef $ResourceRef -NCIP $NCIP -NCCredential $NCCredential -EnableMultiWindow $true
                            }
                            catch{
                                [System.Windows.Forms.MessageBox]::Show($_)                             
                            }
			            }
                        $parameters = @{}
                        $parameters.ResourceRef = $sender.Text
                        $parameters.NCIP = $NCIP
                        $parameters.NCCredential = $NCCredential
                        $parameters.CurWorDir = $pwd
                        $parameters.EnableMultiWindow = $EnableMultiWindow

	    	            $ps.AddScript(
			                $script
		                )		
                    $ps.AddParameters($parameters)
		            $ps.BeginInvoke()
                }
                else
                {
                    JsonForm -ResourceRef $sender.Text -NCIP $NCIP -NCCredential $NCCredential
                }
                
              })
            $panel.Controls.Add($button)
            $System_Drawing_Point.X += 285

            if ($data.resourceRef.Contains("networkInterfaces"))
            {
                $ipBox = New-Object System.Windows.Forms.TextBox 
                $locationY = $System_Drawing_Point.Y + 1
                $locationX = $System_Drawing_Point.X + 1
                $ipBox.Location = New-Object System.Drawing.Size($locationX,$locationY)  
                $ipBox.Multiline = $false 
                $ipBox.WordWrap = $false
                $ipBox.Size = New-Object System.Drawing.Size(80,23) 

                try
                {
                    $ipBox.Text = $data.properties.ipConfigurations[0].properties.privateIPAddress
                }
                catch
                {
                    $ipBox.Text = "NULL"
                }
                $ipBox.Enabled = $false
                $panel.Controls.Add($ipBox) 
                $System_Drawing_Point.X += 85
            }
            elseif ($data.resourceRef.Contains("loadBalancers"))
            {
                $ipBox = New-Object System.Windows.Forms.TextBox 
                $locationY = $System_Drawing_Point.Y + 1
                $locationX = $System_Drawing_Point.X + 1
                $ipBox.Location = New-Object System.Drawing.Size($locationX,$locationY)  
                $ipBox.Multiline = $false 
                $ipBox.WordWrap = $false
                $ipBox.Size = New-Object System.Drawing.Size(80,23) 

                try
                {
                    $ipBox.Text = $data.properties.frontendIPConfigurations[0].properties.privateIPAddress
                }
                catch
                {
                    $ipBox.Text = "NULL"
                }
                $ipBox.Enabled = $false
                $panel.Controls.Add($ipBox) 
                $System_Drawing_Point.X += 85
            }

            $instanceidbox = New-Object System.Windows.Forms.TextBox 
            $locationY = $System_Drawing_Point.Y + 1
            $locationX = $System_Drawing_Point.X + 1
            $instanceidbox.Location = New-Object System.Drawing.Size($locationX,$locationY)  
            $instanceidbox.Multiline = $false 
            $instanceidbox.WordWrap = $false
            $instanceidbox.Size = New-Object System.Drawing.Size(210,23) 
            $instanceidbox.Text = $data.instanceid
            $instanceidbox.Enabled = $false
            $panel.Controls.Add($instanceidbox) 
            $System_Drawing_Point.X += 215
            $extraSpace = 100

            $ProvisioningStateLabel = New-Object System.Windows.Forms.Label
            $System_Drawing_SizeButton = New-Object System.Drawing.Size 
            $System_Drawing_SizeButton.Width = 80
            $System_Drawing_SizeButton.Height = 21
            $ProvisioningStateLabel.TabIndex = 0
            $ProvisioningStateLabel.Name = "Provisioning State"
            $ProvisioningStateLabel.Size = $System_Drawing_SizeButton
            $ProvisioningStateLabel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

            $provisioningState = ""
            if ($data.resourceRef.Contains("connectivityCheckResults"))
            {
                $provisioningState = $data.properties.result.status
                switch($data.properties.result.status)
                {
                    "Success" { $ProvisioningStateLabel.ForeColor = [System.Drawing.Color]::Green }
                    "Failure" { $ProvisioningStateLabel.ForeColor = [System.Drawing.Color]::Red }
                    default { $ProvisioningStateLabel.ForeColor = [System.Drawing.Color]::Yellow }
                }
            }
            else
            {
                $provisioningState = $data.properties.provisioningState
                switch($data.properties.provisioningState)
                {
                    "Succeeded" { $ProvisioningStateLabel.ForeColor = [System.Drawing.Color]::Green }
                    "Failed" { $ProvisioningStateLabel.ForeColor = [System.Drawing.Color]::Red }
                    default { $ProvisioningStateLabel.ForeColor = [System.Drawing.Color]::Yellow }
                }
            }
            $ProvisioningStateLabel.BackColor = [System.Drawing.Color]::Silver;
            $ProvisioningStateLabel.Text = $provisioningState
            $ProvisioningStateLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $locationX = $System_Drawing_Point.X + 5
            $ProvisioningStateLabel.Location = New-Object System.Drawing.Size($locationX,($System_Drawing_Point.Y + 1))  
            $ProvisioningStateLabel.DataBindings.DefaultDataSourceUpdateMode = 0 
            $panel.Controls.Add($ProvisioningStateLabel)
            $System_Drawing_Point.X += 85

            $DeleteButton = New-Object System.Windows.Forms.Button 
            $System_Drawing_SizeButton = New-Object System.Drawing.Size 
            $System_Drawing_SizeButton.Width = 60 
            $System_Drawing_SizeButton.Height = 23 
            $DeleteButton.TabIndex = 0 
            $DeleteButton.Name = $data.resourceId
            $DeleteButton.Size = $System_Drawing_SizeButton 
            $DeleteButton.UseVisualStyleBackColor = $True
            $DeleteButton.Text = "Delete"
            $locationX = $System_Drawing_Point.X + 5
            $DeleteButton.Location = New-Object System.Drawing.Size($locationX,$System_Drawing_Point.Y)  
            $DeleteButton.DataBindings.DefaultDataSourceUpdateMode = 0 
            
            $DeleteButton_add = $DeleteButton.add_Click
            $DeleteButton_add.Invoke({
                param([object]$sender,[string]$message)

                $verify = VerifyUserAction 

                if ($verify -eq $true)
                {                
                    &$RemoveFunc -ResourceIDs $sender.Name 
                    $ExplorerForm.Close()
                }
              })
            $panel.Controls.Add($DeleteButton)
            $System_Drawing_Point.Y += 33
        }
    }
    elseif ($HandlerFunc -ne "Get-NCConnectivityCheckResult")
    {
        [System.Windows.Forms.MessageBox]::Show("Not Configured!!!!") 
        return;
    }

    if($System_Drawing_Point.Y -ge 700)
    {
        $yPoint = 700
    }
    else
    {
        $yPoint = $System_Drawing_Point.Y + 50
    }

    $System_Drawing_Size = New-Object System.Drawing.Size 
    $System_Drawing_Size.Width = 600 + ( 2 * $extraSpace)
    $System_Drawing_Size.Height = $yPoint
    $ExplorerForm.ClientSize = $System_Drawing_Size

    $System_Drawing_Size.Width -= 10
    $System_Drawing_Size.Height -= 10
    $panel.Size = $System_Drawing_Size
    $panel.AutoScroll = $true
    $ExplorerForm.Controls.Add($panel)

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 
    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null

}

function RemoveObjForm { 

param(
        [Parameter(mandatory=$true)]
        [string] $HandlerFunc,

        [Parameter(mandatory=$true)]
        [string] $GetFunc,

        [Parameter(mandatory=$true)]
        [string] $NCIP,

        [Parameter(mandatory=$false)]
        [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty
    )

    . .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential

    try
    {
        $Allobjects = &$GetFunc

        $resourceIds = @()
        $resourceIds += "None"
        foreach ($obj in $Allobjects)
        {
            $resourceIds += $obj.resourceId
        }

        $selectedResource = RadioForm -Name "$HandlerFunc" -Values $resourceIds

        if ($selectedResource -ne "None")
        {
            &$HandlerFunc -ResourceIDs $selectedResource
        }

    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show($_) 
    }

} 

function PutNetworkInterface { 

param(
        [Parameter(mandatory=$true)]
        [string] $HandlerFunc,

        [Parameter(mandatory=$true)]
        [string] $NCIP,

        [Parameter(mandatory=$false)]
        [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty
    )

    . .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential


    try{
        $value = RadioForm -Name "Network type" -Values "Logical Network","Virtual Network"

        if ($value -eq "Logical Network")
        {
            $networks = Get-NCLogicalNetwork
        }
        else
        {
            $networks = Get-NCVirtualNetwork
        }

        $networkRefArray = @()
        foreach ($network in $networks)
        {
            $networkRefArray += $network.resourceId
        }

        $selectedNetworkId = RadioForm -Name "Network" -Values $networkRefArray

        if ($value -eq "Logical Network")
        {
            $network = Get-NCLogicalNetwork -ResourceID $selectedNetworkId
        }
        else
        {
            $network = Get-NCVirtualNetwork -resourceID $selectedNetworkId
        }

        $subnets = @()
        foreach ($subnet in $network.properties.subnets)
        {
            $subnets += $subnet.resourceId
        }

        $selectedSubnetId = RadioForm -Name "Subnet" -Values $subnets

        foreach ($snet in $network.properties.subnets)
        {
            if($snet.resourceId -eq $selectedSubnetId)
            {
                $subnet = $snet
                #break
            }
        }

        $ip = GetValueForm -Name "IP Address"
        if ([string]::IsNullOrEmpty($ip))
        {
            throw "Missing IP!!!!"
        }

        $mac = GetValueForm -Name "Mac Address"
        if ([string]::IsNullOrEmpty($mac))
        {
            throw "Missing Mac!!!!"
        }
    
        $DNSServer = GetValueForm -Name "DNS Server"

        $acls = Get-NCAccessControlList

        $aclRes = @()
        $aclRes += "None"
        foreach ( $aclObj in $acls)
        {
            $aclRes += $aclObj.resourceId
        }
        $selectedAclId = RadioForm -Name "Acl" -Values $aclRes

        $acl = $null
        foreach ( $aclObj in $acls)
        {
            if ($aclObj.resourceId -eq $selectedAclId)
            {
                $acl = $aclObj
            }
        }

        $resId = [system.guid]::NewGuid()
        if ($value -eq "Logical Network")
        {
            $networkInterface = New-NCNetworkInterface -Subnet $subnet -IPAddress $ip -MACAddress $mac -DNSServers $DNSServer -acl $acl -resourceID $resId
        }
        else
        {
            $networkInterface = New-NCNetworkInterface -VirtualSubnet $subnet -IPAddress $ip -MACAddress $mac -DNSServers $DNSServer -acl $acl -resourceID $resId
        }

        [System.Windows.Forms.MessageBox]::Show("Done!!!") 
    
        JsonForm -ResourceRef $networkInterface.resourceRef  -NCIP $NCIP -NCCredential $NCCredential

    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show($_) 
    }

} 

function PutLoadBalancer { 

param(
        [Parameter(mandatory=$true)]
        [string] $HandlerFunc,

        [Parameter(mandatory=$true)]
        [string] $NCIP,

        [Parameter(mandatory=$false)]
        [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty
    )

    Import-Module .\NetworkControllerWorkloadHelpers.psm1 -Force
    . .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential


    try{

        $vip = GetValueForm -Name "VIP Address"
        if ([string]::IsNullOrEmpty($vip))
        {
            throw "Missing VIP!!!!"
        }

        $protocol = RadioForm -Name "Protocol" -Values "Tcp","Udp"

        $frontendPort = [int](GetValueForm -Name "Front End Port")

        $backendPort = [int](GetValueForm -Name "Front End Port")
        
        $enableOutboundNatstr = RadioForm -Name "Enable Outbound Nat" -Values "true","false"

        $enableOutboundNat = $false
        if ($enableOutboundNatstr -eq "true")
        {
            $enableOutboundNat = $true
        }

        #just to load all dependencies
        $slbm = get-ncloadbalancermanager 

        if ($slbm.properties.vipippools.count -lt 1) {
            throw "New-LoadBalancerVIP requires at least one VIP pool in the NC Load balancer manager."
        }

        $vipPools = $slbm.properties.vipippools
    
        # check if the input VIP is within range of one of the VIP pools
        foreach ($vippool in $vipPools) {
            # IP pool's resourceRef is in this format: 
            # /logicalnetworks/f8f67956-3906-4303-94c5-09cf91e7e311/subnets/aaf28340-30fe-4f27-8be4-40eca97b052d/ipPools/ed48962b-2789-41bf-aa7b-3e6d5b247384
            $sp = $vippool.resourceRef.split("/")
        
            $ln = Get-NCLogicalNetwork -resourceId $sp[2] #LN resourceid is always the first ID (after /logicalnetwork/)
            if (-not $ln) {
                throw "Can't find logical network with resourceId $($sp[2]) from NC."
            }

            $subnet = $ln.properties.subnets | ? {$_.resourceId -eq $sp[4]}
            if (-not $subnet) {
                throw "can't find subnet with resourceId $($sp[4]) from NC."
            }
        
            $pool = $subnet.properties.ipPools | ? {$_.resourceId -eq $sp[6]}
            if (-not $pool) {
                throw "can't find IP pool with resourceId $($sp[6]) from NC."
            }
        
            $startIp = $pool.properties.startIpAddress
            $endIp = $pool.properties.endIpAddress
            if (IsIpWithinPoolRange -targetIp $vip -startIp $startIp -endIp $endIp) {
                $isPoolPublic = $subnet.properties.isPublic
                $vipLn = $ln
                break;
            }
        }
    
        if (-not $vipLn) {
            throw "$vip is not within range of any of the VIP pools managed by SLB manager."
        }
         
        $lbfe = @(New-NCLoadBalancerFrontEndIPConfiguration -PrivateIPAddress $vip -Subnet ($vipLn.properties.Subnets[0]))
    
        $ips = @()

        $lbbe = @(New-NCLoadBalancerBackendAddressPool -IPConfigurations $ips)
        $rules = @(New-NCLoadBalancerLoadBalancingRule -protocol $protocol -frontendPort $frontendPort -backendport $backendPort -enableFloatingIP $False -frontEndIPConfigurations $lbfe -backendAddressPool $lbbe)

        $LoadBalancerResourceID = [system.guid]::NewGuid()

        if ($enableOutboundNat) {
            $onats = @(New-NCLoadBalancerOutboundNatRule -frontendipconfigurations $lbfe -backendaddresspool $lbbe)
            $lb = New-NCLoadBalancer -ResourceID $LoadBalancerResourceID -frontendipconfigurations $lbfe -backendaddresspools $lbbe -loadbalancingrules $rules -outboundnatrules $onats
        } else {
            $lb = New-NCLoadBalancer -ResourceID $LoadBalancerResourceID -frontendipconfigurations $lbfe -backendaddresspools $lbbe -loadbalancingrules $rules
        }

        [System.Windows.Forms.MessageBox]::Show("Done!!!") 
    
        JsonForm -ResourceRef $lb.resourceRef  -NCIP $NCIP -NCCredential $NCCredential

    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show($_) 
    }

} 

function RadioForm { 

[OutputType([string])]
param(
        [string] $Name,
        [string[]] $Values
    )


    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = “Please select $Name” 
    $ExplorerForm.Name = “$Name” 
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    # panel to have scroll bar
    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = [System.Drawing.Color]::Silver
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $panel.Location = New-Object System.Drawing.Point (5,5)

    $System_Drawing_Point = New-Object System.Drawing.Point 
    $System_Drawing_Point.X = 80 
    $System_Drawing_Point.Y = 20 
    $radioButtons = @()

    for ($it = 0; $it -lt $Values.Count ;$it++)
    {
        $radioButton = New-Object System.Windows.Forms.RadioButton
        $radioButton.Location = $System_Drawing_Point
        $radioButton.Name = $Values[$it]
        $radioButton.TabIndex = 5
        $radioButton.Text = $Values[$it]
        $radioButton.Size = New-Object System.Drawing.Size(500, 20)
        $radioButtons += $radioButton

        if ([string]::IsNullOrEmpty($selectedValue))
        {
            $selectedValue = $Values[$it]
            $radioButton.Checked = $true
        }

        $System_Drawing_Point.Y += 33
    }
 
    $groupBox1 = New-Object System.Windows.Forms.GroupBox
    $groupBox1.Location = New-Object System.Drawing.Point(60, 10)
    $groupBox1.Name = "groupBox1 $Name"
    $groupBox1.Size = New-Object System.Drawing.Size(500, $System_Drawing_Point.Y)
    $groupBox1.TabIndex = 0
    $groupBox1.TabStop = $false
    $groupBox1.Text = "Select $Name"
    $groupBox1.Controls.AddRange($radioButtons)
    $panel.Controls.Add($groupBox1)
    $System_Drawing_Point.Y += 33

    $button = New-Object System.Windows.Forms.Button 
    $System_Drawing_SizeButton = New-Object System.Drawing.Size 
    $System_Drawing_SizeButton.Width = 240 
    $System_Drawing_SizeButton.Height = 23 
    $button.TabIndex = 0 
    $button.Name = “Select” 
    $button.Size = $System_Drawing_SizeButton 
    $button.UseVisualStyleBackColor = $True
    $button.Text = "Select $Name"
    $button.Location = $System_Drawing_Point 
    $button.DataBindings.DefaultDataSourceUpdateMode = 0 
    #$scriptBlock = $DataArr[$it].Value


    $button.add_Click(
    {
        $ExplorerForm.Close()
    })
    $panel.Controls.Add($button)

    $System_Drawing_Point.Y += 33

    if($System_Drawing_Point.Y -ge 700)
    {
        $yPoint = 700
    }
    else
    {
        $yPoint = $System_Drawing_Point.Y + 50
    }

    $System_Drawing_Size = New-Object System.Drawing.Size 
    $System_Drawing_Size.Width = 600
    $System_Drawing_Size.Height = $yPoint
    $ExplorerForm.ClientSize = $System_Drawing_Size

    $System_Drawing_Size.Width -= 10
    $System_Drawing_Size.Height -= 10
    $panel.Size = $System_Drawing_Size
    $panel.AutoScroll = $true
    $ExplorerForm.Controls.Add($panel)
 
    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 
    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null

    foreach ($radioButton in $radioButtons)
    {
        if ($radioButton.Checked)
        {
            $selectedValue = $radioButton.Text
        }
    }  

  return $selectedValue

} #End Function RadioForm

function GetValueForm { 

param(
        [string] $Name
    )

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    $selectedValue = $null
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = “Please select $Name” 
    $ExplorerForm.Name = “$Name” 
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    $System_Drawing_Point = New-Object System.Drawing.Point 
    $System_Drawing_Point.X = 80 
    $System_Drawing_Point.Y = 20 


    $getBox = New-Object System.Windows.Forms.TextBox 
    $getBox.Location = $System_Drawing_Point
    $getBox.Multiline = $false 
    $getBox.WordWrap = $false
    $getBox.Size = New-Object System.Drawing.Size(240,23) 
    $getBox.Text = ""
    $ExplorerForm.Controls.Add($getBox) 

    $System_Drawing_Point.Y += 33

    $button = New-Object System.Windows.Forms.Button 
    $System_Drawing_SizeButton = New-Object System.Drawing.Size 
    $System_Drawing_SizeButton.Width = 240 
    $System_Drawing_SizeButton.Height = 23 
    $button.TabIndex = 0 
    $button.Name = “Select” 
    $button.Size = $System_Drawing_SizeButton 
    $button.UseVisualStyleBackColor = $True
    $button.Text = "Select $Name"
    $button.Location = $System_Drawing_Point 
    $button.DataBindings.DefaultDataSourceUpdateMode = 0 
    $scriptBlock = $DataArr[$it].Value
    $button.add_Click(
    {
        $ExplorerForm.Close()
    })
    $ExplorerForm.Controls.Add($button)

    $System_Drawing_Point.Y += 33

    $System_Drawing_Size = New-Object System.Drawing.Size 
    $System_Drawing_Size.Width = 600
    $System_Drawing_Size.Height = $System_Drawing_Point.Y + 50
    $ExplorerForm.ClientSize = $System_Drawing_Size

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 
    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null

    return $getBox.Text

} #End Function GetValueForm

function VerifyUserAction { 
    param(
        [string] $String
    )

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    $ret = $false
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    if ([string]::IsNullOrEmpty($String))
    {
        $String = “DO YOU WANT TO CONTINUE???” 
    }
    $ExplorerForm.Text = $String
    $ExplorerForm.Name = “Verify!!!” 
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    $System_Drawing_Point = New-Object System.Drawing.Point 
    $System_Drawing_Point.X = 80 
    $System_Drawing_Point.Y = 20 

    $Stop = New-Object System.Windows.Forms.Button 
    $System_Drawing_SizeButton = New-Object System.Drawing.Size 
    $System_Drawing_SizeButton.Width = 200 
    $System_Drawing_SizeButton.Height = 23 
    $Stop.TabIndex = 0 
    $Stop.Name = “Stop” 
    $Stop.Size = $System_Drawing_SizeButton 
    $Stop.UseVisualStyleBackColor = $True
    $Stop.Text = "Stop"
    $Stop.Location = $System_Drawing_Point 
    $Stop.DataBindings.DefaultDataSourceUpdateMode = 0 
    $Stop.add_Click(
    {
        $ret = $false
        $ExplorerForm.Close()
    })
    $ExplorerForm.Controls.Add($Stop)

    $System_Drawing_Point.X += 210

    $Continue = New-Object System.Windows.Forms.Button 
    $System_Drawing_SizeButton = New-Object System.Drawing.Size 
    $System_Drawing_SizeButton.Width = 200 
    $System_Drawing_SizeButton.Height = 23 
    $Continue.TabIndex = 0 
    $Continue.Name = “Continue” 
    $Continue.Size = $System_Drawing_SizeButton 
    $Continue.UseVisualStyleBackColor = $True
    $Continue.Text = "Continue"
    $Continue.Location = $System_Drawing_Point 
    $Continue.DataBindings.DefaultDataSourceUpdateMode = 0 
    $Continue.add_Click(
    {
        $Continue.Text = "true"
        $ExplorerForm.Close()
    })
    $ExplorerForm.Controls.Add($Continue)

    $System_Drawing_Point.Y += 33

    $System_Drawing_Size = New-Object System.Drawing.Size 
    $System_Drawing_Size.Width = 570
    $System_Drawing_Size.Height = $System_Drawing_Point.Y + 50
    $ExplorerForm.ClientSize = $System_Drawing_Size

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 
    #Show the Form 

    $ExplorerForm.ShowDialog()| Out-Null

    if ($Continue.Text -eq "true")
    {
        $ret = $True
    }

    return $ret

} #End Function VerifyUserAction

function JsonForm { 

param(
        [Parameter(mandatory=$true)]
        [string] $ResourceRef,

        [Parameter(mandatory=$true)]
        [string] $NCIP,

        [Parameter(mandatory=$true)]
        [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty,

        [Parameter(mandatory=$false)]
        [bool] $EnableMultiWindow=$true
    )

    . .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    $objTextBoxVFP = $null
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
        $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = “$ResourceRef NC:$NCIP $pwd” 
    $ExplorerForm.Name = “$ResourceRef NC:$NCIP” 
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    $ExplorerForm.ClientSize = New-Object System.Drawing.Size(700,800) 

    $jsonObject = JSONGet -NetworkControllerRestIP $NCIP -path $ResourceRef -credential $NCCredential

    $getBox = New-Object System.Windows.Forms.TextBox 
    $getBox.Location = New-Object System.Drawing.Size(40,20) 
    $getBox.Multiline = $true 
    $getBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    
    $getBox.WordWrap = $false
    $getBox.Size = New-Object System.Drawing.Size(250,60) 
    $getBox.Text = "Any Resource reference"
    $ExplorerForm.Controls.Add($getBox) 


    $button1 = New-Object System.Windows.Forms.Button 
    $button1.TabIndex = 0 
    $button1.Name = “Get” 
    $button1.Size = New-Object System.Drawing.Size(80,60)
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "Get"
    $button1.Location = New-Object System.Drawing.Size(310,20)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0 
    
    $scriptBlock = {

        if ($EnableMultiWindow)
        {
			$ps = [powershell]::create()

            $script = {	
                param(
                [string] $ResourceRef,

                [string] $NCIP,

                [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty,

                [string]$CurWorDir,

                [bool]$EnableMultiWindow
                )	
                    try{                    
                        Set-Location $CurWorDir
                        Import-Module -Force -Name .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true
                        JsonForm -ResourceRef $ResourceRef -NCIP $NCIP -NCCredential $NCCredential -EnableMultiWindow $true
                    }
                    catch{
                        [System.Windows.Forms.MessageBox]::Show($_) 
                    }
			    }
                $parameters = @{}
                $parameters.ResourceRef = $getBox.Text
                $parameters.NCIP = $NCIP
                $parameters.NCCredential = $NCCredential
                $parameters.CurWorDir = $pwd
                $parameters.EnableMultiWindow = $EnableMultiWindow
	    	    $ps.AddScript(
			        $script
		        )		
            $ps.AddParameters($parameters)
		    $ps.BeginInvoke()
        }
        else
        {
            JsonForm -ResourceRef $getBox.Text -NCIP $NCIP -NCCredential $NCCredential
        }
    }

    $button1.add_Click($scriptBlock)
    $ExplorerForm.Controls.Add($button1)

    $button2 = New-Object System.Windows.Forms.Button 
    $button2.TabIndex = 0 
    $button2.Name = “Enable Editing” 
    $button2.Size = New-Object System.Drawing.Size(80,60)
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "Enable Editing"
    $button2.Location = New-Object System.Drawing.Size(410,20)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0 
    $scriptBlockEnable = {
        $objTextBox.Enabled = $true
        $ExplorerForm.Controls.Remove($button2)
        $ExplorerForm.Controls.Add($buttonPost)
        $objTextBox.ReadOnly = $false

    }
    $button2.add_Click($scriptBlockEnable)
    $ExplorerForm.Controls.Add($button2)

    $buttonPost = New-Object System.Windows.Forms.Button 
    $buttonPost.TabIndex = 0 
    $buttonPost.Name = “Post” 
    $buttonPost.Size = New-Object System.Drawing.Size(80,60)
    $buttonPost.UseVisualStyleBackColor = $True
    $buttonPost.Text = "Post"
    $buttonPost.Location = New-Object System.Drawing.Size(410,20)
    $buttonPost.DataBindings.DefaultDataSourceUpdateMode = 0 
    $scriptBlockPost = {
        $body = ConvertFrom-Json $objTextBox.Text
        $parse = $ResourceRef.Split("/")
        $rid = ""

        for($it = 0 ;$it -lt $parse.Count -1; $it++)
        {
            if( -not [string]::IsNullOrEmpty($parse[$it]))
            {
                $rid += "/"
                $rid += $parse[$it]
            }
        }

        try
	    {
            JSONPost -path $rid -bodyObject $body
            [System.Windows.Forms.MessageBox]::Show("Done!!!!") 
        }
        catch
        {
            [System.Windows.Forms.MessageBox]::Show("Post Failed!!!!") 
        }
    }
    $buttonPost.add_Click($scriptBlockPost)
    


    $objTextBox = New-Object System.Windows.Forms.RichTextBox
    $objTextBox.Location = New-Object System.Drawing.Size(40,120) 
    $objTextBox.Multiline = $true 
    $objTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    
    $objTextBox.WordWrap = $false
    $objTextBox.Size = New-Object System.Drawing.Size(600,630) 
    $objTextBox.Text = $jsonObject | ConvertTo-Json -Depth 20
    $objTextBox.ReadOnly = $true
    $ExplorerForm.Controls.Add($objTextBox) 


    $SearchBox1 = New-Object System.Windows.Forms.RichTextBox 
    $SearchBox1.Location = New-Object System.Drawing.Size(40,100) 
    $SearchBox1.Multiline = $false
    
    $SearchBox1.WordWrap = $false
    $SearchBox1.Size = New-Object System.Drawing.Size(500,20) 
    $SearchBox1.Text = "Enter Text to search here..."
    $SearchBox1.ForeColor = [Drawing.Color]::Gray
    $SearchBox1.add_KeyPress({ 

    #Event Argument: $_ = [System.Windows.Forms.KeyEventArgs]
	    if($_.KeyChar -eq 13)
	    {
		    &$scriptBlockfindButton
	    }
        elseif ($SearchBox1.Text -eq "Enter Text to search here...")
        {
            $SearchBox1.Text = ""
        }
    })
    $ExplorerForm.Controls.Add($SearchBox1) 

    $findButton = New-Object System.Windows.Forms.Button 
    $findButton.TabIndex = 0 
    $findButton.Name = “Find” 
    $findButton.Size = New-Object System.Drawing.Size(100,20)
    $findButton.UseVisualStyleBackColor = $True
    $findButton.Text = "Find"
    $findButton.Location = New-Object System.Drawing.Size(540,100)
    $findButton.DataBindings.DefaultDataSourceUpdateMode = 0 
    $scriptBlockfindButton = {
        $textBoxes = @()
        $textBoxes += $objTextBox

        if ($objTextBoxVFP -ne $null)
        {
            $textBoxes += $objTextBoxVFP
        }
        $searchStr = $SearchBox1.Text
        $found = $false
        foreach ( $textBox in $textBoxes)
        {
            $i = 0
            $textBox.Text -Split '\n' | % { 
            $textBox.SelectionStart = $i
            $line = $_
            $textBox.SelectionLength = $line.Length
            if (Select-String -Pattern $searchStr -InputObject $line) 
            { 
                $textBox.SelectionColor = [Drawing.Color]::DarkGreen
                $textBox.SelectionBackColor = [Drawing.Color]::White

                if (-not $found)
                {
                    $textBox.ScrollToCaret()
                    $found = $true
                }
            } 
            else 
            { 
                $textBox.SelectionColor = [Drawing.Color]::Black
                $textBox.SelectionBackColor = [System.Drawing.Color]::FromArgb(240,240,240) 
            } 
            $i += $line.Length + 1
            }
        }

        $searchBox1.ForeColor = [Drawing.Color]::Black

        if ($found)
        {
            $SearchBox1.ForeColor = [Drawing.Color]::DarkGreen
        }
        else
        {
            $SearchBox1.ForeColor = [Drawing.Color]::Red
            $SearchBox1.Text += " <-- NOT FOUND"
        }

    }
    $findButton.add_Click($scriptBlockfindButton)
    $ExplorerForm.Controls.Add($findButton)

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 

    
    if ($ResourceRef.Contains("virtualServers"))
    {
        $runCommand = New-Object System.Windows.Forms.Button 
        $runCommand.TabIndex = 0 
        $runCommand.Name = “Run Command” 
        $runCommand.Size = New-Object System.Drawing.Size(80,60)
        $runCommand.UseVisualStyleBackColor = $True
        $runCommand.Text = "Run Command"
        $runCommand.Location = New-Object System.Drawing.Size(510,20)
        $runCommand.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock = {

            foreach ($address in $jsonObject.properties.connections[0].managementAddresses)
            {
                try
                {
                    [ipaddress]$address

                    try
                    {
                        $ServerName = ([System.Net.Dns]::GetHostByAddress($address)).hostname
                    }
                    catch
                    {
                        [System.Windows.Forms.MessageBox]::Show("GetHostByAddress failed!!!!") 
                        return
                    }
                }
                catch
                {
                    $ServerName = $address
                    break;
                }
            }

            if([string]::IsNullOrEmpty($ServerName))
            {
                [System.Windows.Forms.MessageBox]::Show("Server Name Missing!!!!") 
                return
            }

            start-process -FilePath powershell -ArgumentList @('-NoExit',"-command etsn $ServerName -Credential Get-Credential")
        }
        $runCommand.add_Click($scriptBlock)
        $ExplorerForm.Controls.Add($runCommand)
    }
    elseif ($ResourceRef.Contains("server"))
    {
        $ExplorerForm.ClientSize = New-Object System.Drawing.Size(900,800) 

        $ovsdb = New-Object System.Windows.Forms.Button 
        $ovsdb.TabIndex = 0 
        $ovsdb.Name = “OVSDB Policies” 
        $ovsdb.Size = New-Object System.Drawing.Size(100,40)
        $ovsdb.UseVisualStyleBackColor = $True
        $ovsdb.Text = "OVSDB Policies"
        $ovsdb.Location = New-Object System.Drawing.Size(700,100)
        $ovsdb.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock1 = {

            if ($EnableMultiWindow)
            {
                $ps = [powershell]::create()

                $script = {	
                    param(                   

                    [object]$jsonObject,

                    [string]$CurWorDir,

                    [bool]$EnableMultiWindow
                    )	

                    try{
                            Set-Location $CurWorDir
                            Import-Module .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true                            
                            OvsdbForm -Server $jsonObject -EnableMultiWindow $true                                                                                  
                    }
                        catch{
                            [System.Windows.Forms.MessageBox]::Show($_) 
                        }
			        }
                    $parameters = @{}
                    $parameters.jsonObject = $jsonObject
                    $parameters.CurWorDir = $pwd
                    $parameters.EnableMultiWindow = $EnableMultiWindow
	    	        $ps.AddScript(
			            $script
		            )		
                $ps.AddParameters($parameters)
		        $ps.BeginInvoke()                
            }
            else
            {
                OvsdbForm -Server $jsonObject
            }
        }
        $ovsdb.add_Click($scriptBlock1)
        $ExplorerForm.Controls.Add($ovsdb)

        $vfp = New-Object System.Windows.Forms.Button 
        $vfp.TabIndex = 0 
        $vfp.Name = “VFP Policies” 
        $vfp.Size = New-Object System.Drawing.Size(100,40)
        $vfp.UseVisualStyleBackColor = $True
        $vfp.Text = "VFP Policies"
        $vfp.Location = New-Object System.Drawing.Size(700,160)

        $vfp.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock2 = {
            if ($EnableMultiWindow)
            {
                $ps = [powershell]::create()

                $script = {	
                    param(                   

                    [object]$jsonObject,

                    [string]$CurWorDir
                    )	

                    try{
                            Set-Location $CurWorDir
                            Import-Module .\SDNExplorer.ps1 -ArgumentList $NCIP,$NCCredential,$true,$true
                            GetAllVFPPolices -Server $jsonObject -EnableMultiWindow $true
                        }
                        catch{
                            [System.Windows.Forms.MessageBox]::Show($_) 
                        }
			        }
                    $parameters = @{}
                    $parameters.jsonObject = $jsonObject
                    $parameters.CurWorDir = $pwd
	    	        $ps.AddScript(
			            $script
		            )		
                $ps.AddParameters($parameters)
		        $ps.BeginInvoke()        
            }
            else
            {
                GetAllVFPPolices -Server $jsonObject
            }
        }
        $vfp.add_Click($scriptBlock2)
        $ExplorerForm.Controls.Add($vfp)

        $runCommand = New-Object System.Windows.Forms.Button 
        $runCommand.TabIndex = 0 
        $runCommand.Name = “Run Command” 
        $runCommand.Size = New-Object System.Drawing.Size(100,40)
        $runCommand.UseVisualStyleBackColor = $True
        $runCommand.Text = "Run Command"
        $runCommand.Location = New-Object System.Drawing.Size(700,220)
        $runCommand.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock3 = {

            foreach ($address in $jsonObject.properties.connections[0].managementAddresses)
            {
                try
                {
                    [ipaddress]$address
                }
                catch
                {
                    $ServerName = $address
                    break;
                }
            }

            if([string]::IsNullOrEmpty($ServerName))
            {
                [System.Windows.Forms.MessageBox]::Show("Server Name Missing!!!!") 
                return
            }

            start-process -FilePath powershell -ArgumentList @('-NoExit',"-command etsn $ServerName")
        }
        $runCommand.add_Click($scriptBlock3)
        $ExplorerForm.Controls.Add($runCommand)


        $RDMA = New-Object System.Windows.Forms.Button 
        $RDMA.TabIndex = 0 
        $RDMA.Name = “Verify RDMA” 
        $RDMA.Size = New-Object System.Drawing.Size(100,40)
        $RDMA.UseVisualStyleBackColor = $True
        $RDMA.Text = "Verify RDMA"
        $RDMA.Location = New-Object System.Drawing.Size(700,280)
        $RDMA.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock4 = {

          
            foreach ($address in $jsonObject.properties.connections[0].managementAddresses)
            {
                try
                {
                    [ipaddress]$address
                }
                catch
                {
                    $ServerName = $address
                    break;
                }
            }
          

            RDMAValidation -ServerName $ServerName 
        }
        $RDMA.add_Click($scriptBlock4)
        $ExplorerForm.Controls.Add($RDMA)

        $Cert = New-Object System.Windows.Forms.Button 
        $Cert.TabIndex = 0 
        $Cert.Name = “Verify Certs” 
        $Cert.Size = New-Object System.Drawing.Size(100,40)
        $Cert.UseVisualStyleBackColor = $True
        $Cert.Text = "Verify Certs"
        $Cert.Location = New-Object System.Drawing.Size(700,340)
        $Cert.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock5 = {

            foreach ($address in $jsonObject.properties.connections[0].managementAddresses)
            {
                try
                {
                    [ipaddress]$address
                }
                catch
                {
                    $ServerName = $address
                    break;
                }
            }

            VerifyCerts -NCIP $NCIP -ServerName $ServerName -ServerObject $jsonObject -NCCredential $NCCredential
        }
        $Cert.add_Click($scriptBlock5)
        $ExplorerForm.Controls.Add($Cert)

        $jumboPkt = New-Object System.Windows.Forms.Button 
        $jumboPkt.TabIndex = 0 
        $jumboPkt.Name = “Verify Jumbo pkt” 
        $jumboPkt.Size = New-Object System.Drawing.Size(100,40)
        $jumboPkt.UseVisualStyleBackColor = $True
        $jumboPkt.Text = "Verify Jumbo pkt"
        $jumboPkt.Location = New-Object System.Drawing.Size(700,400)
        $jumboPkt.DataBindings.DefaultDataSourceUpdateMode = 0 
        $scriptBlock6 = {

            foreach ($address in $jsonObject.properties.connections[0].managementAddresses)
            {
                try
                {
                    [ipaddress]$address
                }
                catch
                {
                    $ServerName = $address
                    break;
                }
            }

            VerifyJumboPkt -ServerName $ServerName -NCCredential $NCCredential
        }
        $jumboPkt.add_Click($scriptBlock6)
        $ExplorerForm.Controls.Add($jumboPkt)
    }
    elseif($ResourceRef.Contains("networkInterfaces"))
    {
        $ExplorerForm.ClientSize = New-Object System.Drawing.Size(1400,800) 

        $scriptBlockVfpRules = {

            $objTextBoxVFP.text = "Extracting VFP Rules..."

            $ServerResource = $jsonObject.properties.server.resourceRef

            if(-not [string]::IsNullOrEmpty($ServerResource))
            {
                $server = JSONGet -NetworkControllerRestIP $NCIP -path $ServerResource -credential $NCCredential 

                foreach ($address in $server.properties.connections[0].managementAddresses)
                {
                    try
                    {
                        [ipaddress]$address
                    }
                    catch
                    {
                        $ServerName = $address
                        break;
                    }
                }

                if(-not [string]::IsNullOrEmpty($ServerName))
                {

                    $mac = $jsonObject.properties.privateMacAddress
                    $mac = $mac -replace "-"
                    $mac = $mac -replace ":"

                    $scriptBlockVFP = {

                        param(
                            [Parameter(mandatory=$true)]
                            [string] $Mac
                        )
                        $vms = gwmi -na root\virtualization\v2 msvm_computersystem  | Where Description -Match "Virtual"
                        $port = $null
                        $vms | foreach {
                            $vm=$_; $vm.GetRelated("Msvm_SyntheticEthernetPort") |  foreach { 
                                $vma = $_;
                                if($vma.PermanentAddress -eq $Mac)
                                {
                                    $port = $vma.GetRelated("Msvm_SyntheticEthernetPortSettingData").GetRelated("Msvm_EthernetPortAllocationSettingData").GetRelated("Msvm_EthernetSwitchPort");
                                }
                            }
                         }

                        $portGuid = $port.Name
                        $vfpCtrlExe = "vfpctrl.exe"
                        echo "Policy for port : " $portGuid
                        & $vfpCtrlExe /list-space  /port $portGuid
                        & $vfpCtrlExe /list-mapping  /port $portGuid
                        & $vfpCtrlExe /list-rule  /port $portGuid
                        & $vfpCtrlExe /port $portGuid /get-port-state
                    }

                    $text = @()
                    $text = RunServerCommand -ServerName $ServerName -scriptBlock $scriptBlockVFP -argumentList $mac

                    $objTextBoxVFP.Enabled = $true
                    
                    $objTextBoxVFP.text = ""
                    
                    foreach ($line in $text) {
		                $objTextBoxVFP.Appendtext($line)
                        $objTextBoxVFP.AppendText("`n")
	                }           
                }
                else
                {
                    [System.Windows.Forms.MessageBox]::Show("Server Name Missing!!!!") 
                }
            }
            else
            {
                [System.Windows.Forms.MessageBox]::Show("Server Resource Missing!!!!") 
            }
        }

        $buttonVfpRule = New-Object System.Windows.Forms.Button 
        $buttonVfpRule.TabIndex = 0 
        $buttonVfpRule.Name = “VFP Rules” 
        $buttonVfpRule.Size = New-Object System.Drawing.Size(80,60)
        $buttonVfpRule.UseVisualStyleBackColor = $True
        $buttonVfpRule.Text = “VFP Rules” 
        $buttonVfpRule.Location = New-Object System.Drawing.Size(800,20)
        $buttonVfpRule.DataBindings.DefaultDataSourceUpdateMode = 0 
        $buttonVfpRule.add_Click($scriptBlockVfpRules)
        $ExplorerForm.Controls.Add($buttonVfpRule)

        $buttonVfpRule = New-Object System.Windows.Forms.Button 
        $buttonVfpRule.TabIndex = 0 
        $buttonVfpRule.Name = “Start-CAPing” 
        $buttonVfpRule.Size = New-Object System.Drawing.Size(80,60)
        $buttonVfpRule.UseVisualStyleBackColor = $True
        $buttonVfpRule.Text = “Start-CAPing” 
        $buttonVfpRule.Location = New-Object System.Drawing.Size(700,20)
        $buttonVfpRule.DataBindings.DefaultDataSourceUpdateMode = 0 
        $buttonVfpRule.add_Click(
        {
            CAPing -NCIP $NCIP -Source $jsonObject -NCCredential $NCCredential
        })
        $ExplorerForm.Controls.Add($buttonVfpRule)

        $objTextBoxVFP = New-Object System.Windows.Forms.RichTextBox 
        $objTextBoxVFP.Location = New-Object System.Drawing.Size(700,100) 
        $objTextBoxVFP.Multiline = $true 
        $objTextBoxVFP.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    
        $objTextBoxVFP.WordWrap = $false
        $objTextBoxVFP.Size = New-Object System.Drawing.Size(600,650) 
        $objTextBoxVFP.font = "lucida console"
        $objTextBoxVFP.Enabled = $false
        $objTextBoxVFP.ReadOnly = $true
        $ExplorerForm.Controls.Add($objTextBoxVFP) 

    }
        

    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null

} #End Function JsonForm

function RunNCCMDLet { 

param(
        [Parameter(mandatory=$true)]
        [string] $Cmdlet,
        [Parameter(mandatory=$true)]
        [object] $NCVMCred,
        [Parameter(mandatory=$true)]
        [string] $NCIP
    )
    try
    {
        # Generate Random names for prefix
        $rand = New-Object System.Random
        $prefixLen = 8
        [string]$namingPrefix = ''
        for($i = 0; $i -lt $prefixLen; $i++)
        {
            $namingPrefix += [char]$rand.Next(65,90)
        }


        if ($Cmdlet -eq "Debug-NetworkController")
        {
            if ($NCIP -eq "restserver")
            {
                $ip = ([System.Net.Dns]::GetHostAddresses("restserver"))[0].IPAddressToString
            }
            else
            {
                $ip = $NCIP
            }
            $copyfolder = "Debug-NetworkController_$namingPrefix"
            $cmdstring += "$Cmdlet -NetworkController $ip -OutputDirectory c:\temp\Debug-NetworkController_$namingPrefix" 
        }
        elseif ($Cmdlet -eq "Debug-NetworkControllerConfigurationState")
        {
            if ($Script:NCIP -eq "restserver")
            {
                $cmdstring += " echo `"`n`r192.14.0.22 restserver`"  > C:\Windows\System32\drivers\etc\hosts;"
            }

            $cmdstring += "$Cmdlet -NetworkController $NCIP"
        }

        $scriptBlock = ([scriptblock]::Create($cmdstring))

        $result = Invoke-Command -ComputerName $NCIP -ScriptBlock $scriptBlock -Credential $NCVMCred

        if ($copyfolder)
        {
            $psDriver = New-PSDrive -Name Y -PSProvider filesystem -Root \\$ip\c$\temp -Credential $NCVMCred

            Copy-Item Y:\$copyfolder .\$copyfolder -Recurse
        }

        [System.Windows.Forms.MessageBox]::Show("$Cmdlet completed") 

        if ($copyfolder)
        {
            start .\$copyfolder
        }
        else
        {
            DisplayTextForm -FormName $Cmdlet -Text $result
        }

    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show($_) 
    }
    finally
    {
        if ($psDriver)
        {
            Remove-PSDrive -Name Y
        }
    }

}

function OvsdbForm { 

param(
        [Parameter(mandatory=$true)]
        [object] $Server,
        [Parameter(mandatory=$false)]
        [bool] $EnableMultiWindow=$true
    )

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    if($EnableMultiWindow)
    {
        $progress = [powershell]::create()

        $progressScript = {	
                [System.Windows.Forms.MessageBox]::Show("Fetching Policies, it will take a few seconds to complete")                                    
	    }
        $progress.AddScript($progressScript)	
                            		                                               
	    $progressObj = $progress.BeginInvoke()                                                     
    }
   
    foreach ($address in $Server.properties.connections[0].managementAddresses)
    {
        try
        {
            [ipaddress]$address
        }
        catch
        {
            $ServerName = $address
            break;
        }
    }

    if([string]::IsNullOrEmpty($ServerName))
    {
        [System.Windows.Forms.MessageBox]::Show("Server Name Missing!!!!") 
        return
    }

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = $ServerName
    $ExplorerForm.Name = $ServerName
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    $ExplorerForm.ClientSize = New-Object System.Drawing.Size(900,800) 

    $vtep = @()
    $vtep = GetOvsDBVtep -ServerName $ServerName 
    
    $firewall = @()
    $firewall = GetOvsDBfirewall -ServerName $ServerName 


    $objTextBoxVtep = New-Object System.Windows.Forms.RichTextBox 
    $objTextBoxVtep.Location = New-Object System.Drawing.Size(40,100) 
    $objTextBoxVtep.Multiline = $true 
    $objTextBoxVtep.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    
    $objTextBoxVtep.WordWrap = $false
    $objTextBoxVtep.Size = New-Object System.Drawing.Size(390,650) 
    $objTextBoxVtep.font = "lucida console"
    foreach ($line in $vtep) {
		$objTextBoxVtep.Appendtext($line)
        $objTextBoxVtep.AppendText("`n")
	}
    $ExplorerForm.Controls.Add($objTextBoxVtep) 

    $objTextBoxFirewall = New-Object System.Windows.Forms.TextBox 
    $objTextBoxFirewall.Location = New-Object System.Drawing.Size(470,100) 
    $objTextBoxFirewall.Multiline = $true 
    $objTextBoxFirewall.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    
    $objTextBoxFirewall.WordWrap = $false
    $objTextBoxFirewall.Size = New-Object System.Drawing.Size(390,650) 
    foreach ($line in $firewall) {
		$objTextBoxFirewall.Appendtext($line)
        $objTextBoxFirewall.AppendText("`n")
	}
    $ExplorerForm.Controls.Add($objTextBoxFirewall) 

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 

    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null
    if($EnableMultiWindow)
    {
        $progress.Dispose()
    }

} #End Function OvsdbForm

function RunScriptForm { 

param(
        [Parameter(mandatory=$false)]
        [object[]] $Servers
    )

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = "Run Script Block on all Servers"
    $ExplorerForm.Name = $ServerName
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    $ExplorerForm.ClientSize = New-Object System.Drawing.Size(900,800) 


    $runScript = New-Object System.Windows.Forms.Button 
    $System_Drawing_SizeButton = New-Object System.Drawing.Size 
    $System_Drawing_SizeButton.Width = 240 
    $System_Drawing_SizeButton.Height = 23 
    $runScript.TabIndex = 0 
    $runScript.Name = “Select” 
    $runScript.Size = $System_Drawing_SizeButton 
    $runScript.UseVisualStyleBackColor = $True
    $runScript.Text = "--Run Script Block--"
    $runScript.Location = New-Object System.Drawing.Size(50,50)
    $runScript.DataBindings.DefaultDataSourceUpdateMode = 0 
    $scriptBlock = {
        $objTextBoxOutPut.text = ""
        $objTextInput.ReadOnly = $true

            foreach ($server in $Servers)
            {
                try
                {
                    foreach ($address in $server.properties.connections[0].managementAddresses)
                    {
                        try
                        {
                            [ipaddress]$address
                        }
                        catch
                        {
                            $ServerName = $address
                            break;
                        }
                    }

                    $line = "==============================`n"
                    $objTextBoxOutPut.text += $line   
                    $line = "Running Command on $ServerName `n"
                    $objTextBoxOutPut.text += $line   
                    $line = "==============================`n"
                    $objTextBoxOutPut.text += $line      

                    $command = "try{"
                    $command += $objTextInput.text
                    $command += "}catch {return `$_}"

                    $data = RunServerCommand -ServerName $ServerName -scriptBlock $command

                    foreach ($line in $data) {
                        if ($line.Length -ne 0)
                        {
                            $formattedData =  $line | Format-Table
                            $formattedData = $formattedData | Out-String
                            $objTextBoxOutPut.Appendtext($formattedData)
                            $objTextBoxOutPut.ScrollToCaret()
                        }
	                }
                }
                catch
                {
                    [System.Windows.Forms.MessageBox]::Show($_) 
                }
            }

            $i = 0
            $objTextBoxOutPut.Text -Split '\n' | % { 
            $objTextBoxOutPut.SelectionStart = $i
            $line = $_
            $searchStr1 = "Running Command on "
            $searchStr2 = "===================="
            $objTextBoxOutPut.SelectionLength = $line.Length
            if (Select-String -Pattern $searchStr1 -InputObject $line) 
            { 
                $objTextBoxOutPut.SelectionColor = [Drawing.Color]::Blue
            }
            elseif (Select-String -Pattern $searchStr2 -InputObject $line) 
            { 
                $objTextBoxOutPut.SelectionColor = [Drawing.Color]::DarkBlue
            }  
            else 
            { 
                $objTextBoxOutPut.SelectionColor = [Drawing.Color]::Black
            } 
            $i += $line.Length + 1
            }

        $objTextInput.ReadOnly = $false
    }
    $runScript.add_Click($scriptBlock)
    $ExplorerForm.Controls.Add($runScript)

    $objTextInput = New-Object System.Windows.Forms.RichTextBox 
    $objTextInput.Location = New-Object System.Drawing.Size(50,100) 
    $objTextInput.Multiline = $true 
    $objTextInput.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    
    $objTextInput.WordWrap = $false
    $objTextInput.Size = New-Object System.Drawing.Size(800,300) 
    $objTextInput.font = "lucida console"
    foreach ($line in $vtep) {
		$objTextInput.Appendtext($line)
        $objTextInput.AppendText("`n")
	}
    $ExplorerForm.Controls.Add($objTextInput) 

    $objTextBoxOutPut = New-Object System.Windows.Forms.RichTextBox 
    $objTextBoxOutPut.Location = New-Object System.Drawing.Size(50,450) 
    $objTextBoxOutPut.Multiline = $true 
    $objTextBoxOutPut.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $objTextBoxOutPut.ReadOnly = $true
    
    $objTextBoxOutPut.WordWrap = $false
    $objTextBoxOutPut.Size = New-Object System.Drawing.Size(800,300) 
    foreach ($line in $firewall) {
		$objTextBoxOutPut.Appendtext($line)
        $objTextBoxOutPut.AppendText("`n")
	}
    $ExplorerForm.Controls.Add($objTextBoxOutPut) 

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 

    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null

} #End Function RunScriptForm

function GetOvsDBVtep { 

param(
        [Parameter(mandatory=$true)]
        [string] $ServerName
    )


    return RunServerCommand -ServerName $ServerName -scriptBlock {C:\windows\system32\ovsdb-client.exe dump tcp:127.0.0.1:6641 ms_vtep}

} #End Function GetOvsDBVtep

function GetOvsDBfirewall { 

param(
        [Parameter(mandatory=$true)]
        [string] $ServerName
    )

    return RunServerCommand -ServerName $ServerName -scriptBlock {C:\windows\system32\ovsdb-client.exe dump tcp:127.0.0.1:6641 ms_firewall}

} #End Function GetOvsDBfirewall

function GetAllVFPPolices {

param(
        [Parameter(mandatory=$true)]
        [object] $Server,
        [Parameter(mandatory=$false)]
        [object] $EnableMultiWindow=$true


    )

    if($EnableMultiWindow)
    {
        $progress = [powershell]::create()

        $progressScript = {	
                [System.Windows.Forms.MessageBox]::Show("Fetching Policies, it will take a few seconds to complete")                                    
	    }
        $progress.AddScript($progressScript)	
                            		                                               
	    $progressObj = $progress.BeginInvoke()                                                     
    }

    foreach ($address in $Server.properties.connections[0].managementAddresses)
    {
        try
        {
            [ipaddress]$address
        }
        catch
        {
            $ServerName = $address
            break;
        }
    }

    if([string]::IsNullOrEmpty($ServerName))
    {
        [System.Windows.Forms.MessageBox]::Show("Server Name Missing!!!!") 
        return
    }
    
    $scriptBlock = {   

        $switches = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualEthernetSwitch
        foreach ($switch in $switches) {
            $vfpCtrlExe = "vfpctrl.exe"
            $ports = $switch.GetRelated("Msvm_EthernetSwitchPort", "Msvm_SystemDevice", $null, $null, $null, $null, $false, $null)
            foreach ($port in $ports) {
                $portGuid = $port.Name
                echo "Policy for port : " $portGuid
                & $vfpCtrlExe /list-space  /port $portGuid
                & $vfpCtrlExe /list-mapping  /port $portGuid
                & $vfpCtrlExe /list-rule  /port $portGuid
                & $vfpCtrlExe /port $portGuid /get-port-state
            }
        }
    }

    $text = @()
    $text = RunServerCommand -ServerName $ServerName -scriptBlock $scriptBlock

    DisplayTextForm -FormName $ServerName -Text $text

    if($EnableMultiWindow)
    {
        $progress.Dispose()
    }

} #End Function GetAllVFPPolices

function RunServerCommand {

param(
        [Parameter(mandatory=$true)]
        [string] $ServerName,

        [Parameter(mandatory=$false)]
        [string] $scriptBlock,

        [Parameter(mandatory=$false)]
        [object[]] $argumentList = $null
    )
     

    $text = @()
    $script = ([scriptblock]::Create($scriptBlock))

    if (-not $argumentList)
    {
        $text = Invoke-Command -ComputerName $ServerName -ScriptBlock $script
    }
    else
    {
        $text = Invoke-Command -ComputerName $ServerName -ScriptBlock $script -ArgumentList $argumentList
    }
  
    return $text
} #End Function RunServerCommand

function DisplayTextForm { 

param(
        [Parameter(mandatory=$true)]
        [string] $FormName,

        [Parameter(mandatory=$false)]
        [string[]] $Text
    )

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”) | Out-Null 
    [reflection.assembly]::loadwithpartialname(“System.Drawing”) | Out-Null 
    #endregion

    try
    {
        foreach ($address in $Server.properties.connections[0].managementAddresses)
        {
            try
            {
                [ipaddress]$address
            }
            catch
            {
                $ServerName = $address
                break;
            }
        }

        if([string]::IsNullOrEmpty($ServerName))
        {
            [System.Windows.Forms.MessageBox]::Show("Server Name Missing!!!!") 
        }

        $FormName = $ServerName
    }
    catch
    {
    }

    #region Generated Form Objects 
    $ExplorerForm = New-Object System.Windows.Forms.Form 
    $InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState 
    #endregion Generated Form Objects


    $OnLoadForm_StateCorrection= 
    {#Correct the initial state of the form to prevent the .Net maximized form issue 
    $ExplorerForm.WindowState = $InitialFormWindowState 
    }

    #———————————————- 
    #region Generated Form Code 
    $ExplorerForm.Text = $FormName
    $ExplorerForm.Name = $FormName
    $ExplorerForm.DataBindings.DefaultDataSourceUpdateMode = 0 

    $ExplorerForm.ClientSize = New-Object System.Drawing.Size(700,800) 


    $objTextBoxVtep = New-Object System.Windows.Forms.RichTextBox 
    $objTextBoxVtep.Location = New-Object System.Drawing.Size(40,100) 
    $objTextBoxVtep.Multiline = $true 
    $objTextBoxVtep.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    
    $objTextBoxVtep.WordWrap = $false
    $objTextBoxVtep.Size = New-Object System.Drawing.Size(600,650) 
    $objTextBoxVtep.font = "lucida console"
    foreach ($line in $Text) {
		$objTextBoxVtep.Appendtext($line)
        $objTextBoxVtep.AppendText("`n")
	}
    $ExplorerForm.Controls.Add($objTextBoxVtep) 

    #endregion Generated Form Code

    #Save the initial state of the form 
    $InitialFormWindowState = $ExplorerForm.WindowState 
    #Init the OnLoad event to correct the initial state of the form 
    $ExplorerForm.add_Load($OnLoadForm_StateCorrection) 

    #Show the Form 
    $ExplorerForm.ShowDialog()| Out-Null

} #End Function DisplayTextForm

function CAPing
{
    param($NCIP, $Source, $NCCredential=  [System.Management.Automation.PSCredential]::Empty)

    . .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential

    $headers = @{"Accept"="application/json"}
    $content = "application/json; charset=UTF-8"
    $network = "https://$NCIP/Networking/v1"
    $retry = 30

    $method = "Put"
    $uri = "$network/diagnostics/ConnectivityCheck"
    $body = $caJson

    $networkInterfaces = Get-NCNetworkInterface

    $selectIps = @()

    foreach ($ni in $networkInterfaces)
    {
        try
        {
            if($Source.properties.ipConfigurations[0].properties.privateIPAddress -ne $ni.properties.ipConfigurations[0].properties.privateIPAddress)
            {
                $selectIps += $ni.properties.ipConfigurations[0].properties.privateIPAddress
            }
        }
        catch
        {
            #skip
        }
    } 

    $selectedIp = RadioForm -Name "Dest IP" -Values $selectIps

    foreach ($ni in $networkInterfaces)
    {
        try
        {
            if ( $selectedIp -eq $ni.properties.ipConfigurations[0].properties.privateIPAddress)
            {
                $destination = $ni
            }
        }
        catch
        {
            #skip
        }
    }

    $caJson = @{}
    $caJson.resourceId = ""
    $caJson.properties = @{}
    $caJson.properties.senderIpAddress = $Source.properties.ipConfigurations[0].properties.privateIPAddress
    $caJson.properties.receiverIpAddress = $destination.properties.ipConfigurations[0].properties.privateIPAddress


    $parse = $Source.properties.ipConfigurations[0].properties.subnet.resourceRef.Split("/")
    $Vnet = ""
    for($it = 0 ;$it -lt 3; $it++)
    {
        if( -not [string]::IsNullOrEmpty($parse[$it]))
        {
            $Vnet += "/"
            $Vnet += $parse[$it]
        }
    }
    $caJson.properties.sendervirtualNetwork = @{}
    $caJson.properties.sendervirtualNetwork.resourceRef = $Vnet
    $caJson.properties.receivervirtualNetwork = @{}
    $caJson.properties.receivervirtualNetwork.resourceRef = $Vnet
    $caJson.properties.disableTracing = $false
    $caJson.properties.protocol = "Icmp"
    $caJson.properties.icmpProtocolConfig = @{}
    $caJson.properties.icmpProtocolConfig.sequenceNumber = 1
    $caJson.properties.icmpProtocolConfig.length = 0

    $body = ConvertTo-Json -Depth 20 $caJson
    try
    {
        $result = Invoke-WebRequest -Headers $headers -ContentType $content -Method $method -Uri $uri -Body $body -DisableKeepAlive -UseBasicParsing

        $body = ConvertFrom-Json $result.Content

        $operationId = $body.properties.operationId

        [System.Windows.Forms.MessageBox]::Show("CAPing started:$operationId") 
    }
    catch
    {
      [System.Windows.Forms.MessageBox]::Show("$_") 
    }
} #End Function CAPing

function RDMAValidation
{
    Param(
      [Parameter(Mandatory=$True, Position=1, HelpMessage="Interface index of the adapter for which RDMA config is to be verified")]
      [string] $ServerName
    )

    $vnics = Invoke-Command -ComputerName $ServerName -ScriptBlock { Get-NetAdapter | Where-Object {$_.DriverName -eq "\SystemRoot\System32\drivers\vmswitch.sys" }  }
       

    $vnicNames = @()    

    foreach ($vnic in $vnics)
    {    
        $vnicNames += $vnic.Name
    } 
    try{
         $selectedVName = RadioForm -Name "Adapter Name" -Values $vnicNames
    }
    catch{
        [System.Windows.Forms.MessageBox]::Show("Main error" + $_) 
        return
    }
  
    foreach ($vnic in $vnics)
    {
        if ($selectedVName -eq $vnic.Name)
        {
            $selectedVNic= $vnic
            break
        }
    }

    $IsRoceStr =  RadioForm -Name "IsRoce" -Values "true","false"

    $IsRoce = $false
    if ($IsRoceStr -eq "true")
    {
        $IsRoce = $true
    }


    $scriptBlock = {

        Param(
          [string] $IfIndex,  
          [bool] $IsRoCE
        )

        $rdmaAdapter = Get-NetAdapter -IfIndex $IfIndex

        if ($rdmaAdapter -eq $null)
        {
            Write-Host "ERROR: The adapter with interface index $IfIndex not found"
            return
        }

        $rdmaAdapterName = $rdmaAdapter.Name
        $virtualAdapter = Get-VMNetworkAdapter -ManagementOS | where DeviceId -eq $rdmaAdapter.DeviceID

        if ($virtualAdapter -eq $null)
        {
            $isRdmaAdapterVirtual = $false
            Write-Host "VERBOSE: The adapter $rdmaAdapterName is a physical adapter"
        }
        else
        {
            $isRdmaAdapterVirtual = $true
            Write-Host "VERBOSE: The adapter $rdmaAdapterName is a virtual adapter"
        }

        $rdmaCapabilities = Get-NetAdapterRdma -InterfaceDescription $rdmaAdapter.InterfaceDescription

        if ($rdmaCapabilities -eq $null -or $rdmaCapabilities.Enabled -eq $false) 
        {
            return "ERROR: The adapter $rdmaAdapterName is not enabled for RDMA"
        }

        if ($rdmaCapabilities.MaxQueuePairCount -eq 0)
        { 
            return "ERROR: RDMA capabilities for adapter $rdmaAdapterName are not valid : MaxQueuePairCount is 0"

        }

        if ($rdmaCapabilities.MaxCompletionQueueCount -eq 0)
        {
            return "ERROR: RDMA capabilities for adapter $rdmaAdapterName are not valid : MaxCompletionQueueCount is 0"

        }

        $smbClientNetworkInterfaces = Get-SmbClientNetworkInterface

        if ($smbClientNetworkInterfaces -eq $null)
        {
            return  "ERROR: No network interfaces detected by SMB (Get-SmbClientNetworkInterface)"
        }

        $rdmaAdapterSmbClientNetworkInterface = $null
        foreach ($smbClientNetworkInterface in $smbClientNetworkInterfaces)
        {
            if ($smbClientNetworkInterface.InterfaceIndex -eq $IfIndex)
            {
                $rdmaAdapterSmbClientNetworkInterface = $smbClientNetworkInterface
            }
        }

        if ($rdmaAdapterSmbClientNetworkInterface -eq $null)
        {
            return "ERROR: No network interfaces found by SMB for adapter $rdmaAdapterName (Get-SmbClientNetworkInterface)"
        }

        if ($rdmaAdapterSmbClientNetworkInterface.RdmaCapable -eq $false)
        {
            return "ERROR: SMB did not detect adapter $rdmaAdapterName as RDMA capable. Make sure the adapter is bound to TCP/IP and not to other protocol like vmSwitch."
        }

        $rdmaAdapters = $rdmaAdapter
        if ($isRdmaAdapterVirtual -eq $true)
        {
            Write-Host "VERBOSE: Retrieving vSwitch bound to the virtual adapter"
            $switchName = $virtualAdapter.SwitchName
            Write-Host "VERBOSE: Found vSwitch: $switchName"
            $vSwitch = Get-VMSwitch -Name $switchName
            $rdmaAdapters = Get-NetAdapter -InterfaceDescription $vSwitch.NetAdapterInterfaceDescriptions
            $vSwitchAdapterMessage = "VERBOSE: Found the following physical adapter(s) bound to vSwitch: "
            $index = 1
            foreach ($qosAdapter in $rdmaAdapters)
            {        
                $qosAdapterName = $qosAdapter.Name
                $vSwitchAdapterMessage = $vSwitchAdapterMessage + [string]$qosAdapterName
                if ($index -lt $rdmaAdapters.Length)
                { 
                        $vSwitchAdapterMessage = $vSwitchAdapterMessage + ", " 
                }
                $index = $index + 1
            }
            Write-Host $vSwitchAdapterMessage 
        }


        if ($IsRoCE -eq $true)
        {
            Write-Host "VERBOSE: Underlying adapter is RoCE. Checking if QoS/DCB/PFC is configured on each physical adapter(s)"
            foreach ($qosAdapter in $rdmaAdapters)
            {
                $qosAdapterName = $qosAdapter.Name
                $qos = Get-NetAdapterQos -Name $qosAdapterName 
                if ($qos.Enabled -eq $false)
                {
                    return "ERROR: QoS is not enabled for adapter $qosAdapterName"       
                }

                if ($qos.OperationalFlowControl -eq "All Priorities Disabled")
                {
                    return "ERROR: Flow control is not enabled for adapter $qosAdapterName"        
                }
            }
            Write-Host "VERBOSE: QoS/DCB/PFC configuration is correct."
        }

        return " RDMA configuration on the host is correct, please check switch configuration for E2E RDMA to work."
    }

    $strOutput = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ArgumentList $selectedVNic.ifIndex,$IsRoce

    [System.Windows.Forms.MessageBox]::Show("$strOutput") 
} #End Function RDMAValidation

function VerifyJumboPkt
{
    Param(
      [string] $ServerName,
      [object]$NCCredential=  [System.Management.Automation.PSCredential]::Empty
    )
    try
    {
        $allServers = Get-NCServer

        $serverNames = @()

        foreach ($server in $allServers)
        {
            foreach ($address in $server.properties.connections[0].managementAddresses)
            {
                try
                {
                    [ipaddress]$address
                }
                catch
                {
                    if ($address -ne $ServerName)
                    {
                        $serverNames += $address
                    }
                    break;
                }
            }
        }

        $destServer = RadioForm -Name "Dest Server" -Values $serverNames

        if ($NCCredential -eq [System.Management.Automation.PSCredential]::Empty)
        {
            $cred = Get-Credential -Message "Enter Server Creds"
        }
        else
        {
            $cred = $NCCredential
        }

        $result = Test-LogicalNetworkSupportsJumboPacket -SourceHost $ServerName -DestinationHost $destServer -SourceHostCreds $cred -DestinationHostCreds $cred

        $result = $result | ConvertTo-Json -Depth 10

        [System.Windows.Forms.MessageBox]::Show($result) 
    }
    catch
    {
        [System.Windows.Forms.MessageBox]::Show($_) 
    }

}

function VerifyCerts
{
    Param(
      [string] $NCIP,
      [string] $ServerName,
      [object] $ServerObject,
      [object] $NCCredential=  [System.Management.Automation.PSCredential]::Empty
    )
    . .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential

    $NCCertHash = $null
    foreach ($conn in $ServerObject.properties.connections)
    {
        $cred =  JSONGet -path $conn.credential.resourceRef -NetworkControllerRestIP $NCIP -credential $NCCredential

        if ($cred.properties.type -eq "X509Certificate")
        {
            $NCCertHash = $cred.properties.value
        }
    }

    if ([string]::IsNullOrEmpty($NCCertHash))
    {
        [System.Windows.Forms.MessageBox]::Show("NC Cert is not configured in Server($ServerName) Json.") 
    }

    $ServerCert = $ServerObject.properties.certificate

    $scriptBlock =
    {
        Param(
          [string] $NCCertHash,
          [string] $ServerCert
        )

        $rootCerts = dir Cert:\LocalMachine\Root

        $NCCert = $null
        foreach ($cert in $rootCerts)
        {
            if ($cert.Thumbprint -eq $NCCertHash)
            {
                $NCCert = $cert
            }
        }

        if (-not $NCCert)
        {
            return "NC Cert is Missing"
        }

        $myCerts = dir Cert:\LocalMachine\my
        $serverCertificate = $null
        foreach ($cert in $myCerts)
        {
            $base64 = [System.Convert]::ToBase64String($cert.RawData)
            if ($base64 -eq $ServerCert)
            {
                $serverCertificate = $cert
            }
        }

        if (-not $serverCertificate)
        {
            return "Server Cert is Missing"
        }

        $certToVerify = @()
        $certToVerify += $NCCert
        $certToVerify += $serverCertificate

        foreach ($cert in $certToVerify)
        {

            $server = $false
            $client = $false
            foreach ($eku in $cert.EnhancedKeyUsageList)
            {
                if ($eku.FriendlyName -eq "Server Authentication")
                {
                    $server = $true
                }

                if ($eku.FriendlyName -eq "Client Authentication")
                {
                    $client = $true
                }
            }

            $thumbprint = $cert.Thumbprint

            if ($server -eq $false)
            {
                return "Server EKU is missing on NC Cert($thumbprint) on Server."
            }

            if ($client -eq $false)
            {
                return "Client EKU is missing on NC Cert($thumbprint) on Server."
            }
        }

        $key = 'HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters\'
        $peerCertificateCName = "CN="
        $peerCertificateCName += (Get-ItemProperty -Path $key -Name PeerCertificateCName).PeerCertificateCName

        if ($peerCertificateCName -ne $NCCert.Subject)
        {
            $subject = $NCCert.Subject
            return "NCHostAgent has wrong PeerCertificateCName($peerCertificateCName) instead of $subject"
        }

        $hostAgentCertificateCName = "CN="
        $hostAgentCertificateCName += (Get-ItemProperty -Path $key -Name HostAgentCertificateCName).HostAgentCertificateCName

        if ($hostAgentCertificateCName -ne $serverCertificate.Subject)
        {
            $subject = $serverCertificate.Subject
            return "NCHostAgent has wrong PeerCertificateCName($hostAgentCertificateCName) instead of $subject"
        }

        return "Certificates are configured correctly!!"
    }

    $strOutput = Invoke-Command -ComputerName $ServerName -ScriptBlock $scriptBlock -ArgumentList $NCCertHash,$ServerCert

    [System.Windows.Forms.MessageBox]::Show("$strOutput") 

}  #End Function VerifyCerts

Import-Module .\NetworkControllerWorkloadHelpers.psm1 -Force
. .\NetworkControllerRESTWrappers.ps1 -ComputerName $NCIP -Username $null -Password $null -Credential $Script:NCCredential

$ncVMCredentials = [System.Management.Automation.PSCredential]::Empty

$InputData = @()

$LNs = @{}
$LNs.Name = "Logical Networks"
$LNs.Value = @()
$LNs.Value += {GenerateArrayForm -HandlerFunc "Get-NCLogicalNetwork" -RemoveFunc "Remove-NCLogicalNetwork" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $LNs

$VNs = @{}
$VNs.Name = "VirtualNetworks" 
$VNs.Value = @()
$VNs.Value += {GenerateArrayForm -HandlerFunc "Get-NCVirtualNetwork" -RemoveFunc "Remove-NCVirtualNetwork" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $VNs


$VSs = @{}
$VSs.Name = "Virtual Servers"
$VSs.Value = @() 
$VSs.Value += {GenerateArrayForm -HandlerFunc "Get-NCVirtualServer" -RemoveFunc "Remove-NCVirtualServer" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $VSs

$NIs = @{}
$NIs.Name = "Network Interfaces"
$NIs.Value = @()
$NIs.Value += {GenerateArrayForm -HandlerFunc "Get-NCNetworkInterface" -RemoveFunc "Remove-NCNetworkInterface" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$NIs.Value += {PutNetworkInterface -HandlerFunc "New-NCNetworkInterface" -NCIP $NCIP -NCCredential $Script:NCCredential}
$NIs.Value += {RemoveObjForm -HandlerFunc "Remove-NCNetworkInterface" -GetFunc "Get-NCNetworkInterface" -NCIP $NCIP -NCCredential $Script:NCCredential}
$InputData += $NIs


$NS = @{}
$NS.Name = "Servers"
$NS.Value = @()
$NS.Value = {GenerateArrayForm -HandlerFunc "Get-NCServer" -RemoveFunc "Remove-NCServer" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $NS

$LB = @{}
$LB.Name = "Load Balancer"
$LB.Value = @()
$LB.Value += {GenerateArrayForm -HandlerFunc "Get-NCLoadBalancer" -RemoveFunc "Remove-NCLoadBalancer" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$LB.Value += {PutLoadBalancer -HandlerFunc "New-LoadBalancerVIP" -NCIP $NCIP -NCCredential $Script:NCCredential}
$InputData += $LB

$Acls = @{}
$Acls.Name = "Access Control List"
$Acls.Value = @()
$Acls.Value += {GenerateArrayForm -HandlerFunc "Get-NCAccessControlList" -RemoveFunc "Remove-NCAccessControlList" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow} 
$InputData += $Acls

$Credentials = @{}
$Credentials.Name = "NC Credentials"
$Credentials.Value = @()
$Credentials.Value += {GenerateArrayForm -HandlerFunc "Get-NCCredential" -RemoveFunc "Remove-NCCredential" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow} 
$InputData += $Credentials

$LBM = @{}
$LBM.Name = "Load Balancer Manager"
$LBM.Value = @()
$LBM.Value += {GenerateArrayForm -HandlerFunc "Get-NCLoadbalancerManager" -RemoveFunc "null" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $LBM

$LBMUX = @{}
$LBMUX.Name = "Load Balancer Mux"
$LBMUX.Value = @()
$LBMUX.Value += {GenerateArrayForm -HandlerFunc "Get-NCLoadbalancerMux" -RemoveFunc "Remove-NCLoadBalancerMux" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $LBMUX

$CR = @{}
$CR.Name = "Diagnostics Panel"
$CR.Value = @()
$CR.Value += {GenerateArrayForm -HandlerFunc "Get-NCConnectivityCheckResult" -RemoveFunc "null" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $CR

$Publicip = @{}
$Publicip.Name = "Public IP Addresses"
$Publicip.Value = @()
$Publicip.Value += {GenerateArrayForm -HandlerFunc "Get-NCPublicIPAddress" -RemoveFunc "null" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $Publicip

$RT = @{}
$RT.Name = "Route Tables"
$RT.Value = @()
$RT.Value += {GenerateArrayForm -HandlerFunc "Get-NCRouteTable" -RemoveFunc "null" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $RT

$Gapteways = @{}
$Gapteways.Name = "Gateways"
$Gapteways.Value = @()
$Gapteways.Value += {GenerateArrayForm -HandlerFunc "Get-NCGateway" -RemoveFunc "null" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $Gapteways

$GatewayPools = @{}
$GatewayPools.Name = "Gateway Pools"
$GatewayPools.Value = @()
$GatewayPools.Value += {GenerateArrayForm -HandlerFunc "Get-NCGatewayPool" -RemoveFunc "Remove-NCGatewayPool" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $GatewayPools

$VirtualGateway = @{}
$VirtualGateway.Name = "Virtual Gateway"
$VirtualGateway.Value = @()
$VirtualGateway.Value += {GenerateArrayForm -HandlerFunc "Get-NCVirtualGateway" -RemoveFunc "Remove-NCVirtualGateway" -NCIP $NCIP -NCCredential $Script:NCCredential -EnableMultiWindow $Script:EnableMultiWindow}
$InputData += $VirtualGateway

if(-not $script:IsModule)
{
    #Call the Function 
    GenerateMainForm -DataArr $InputData
}