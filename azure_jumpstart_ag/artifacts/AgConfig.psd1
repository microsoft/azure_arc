@{

    # This is the PowerShell datafile used to provide configuration information for the Agora environment. Product keys and password are not encrypted and will be available on host during installation.

    # Directory paths
    AgDirectories = @{
        AgDir = "C:\Ag"
        AgLogsDir = "C:\Ag\Logs"
        AgVMDir = "C:\Ag\Virtual Machines"
        AgKVDir = "C:\Ag\KeyVault"
        AgGitOpsDir = "C:\Ag\GitOps"
        AgIconDir = "C:\Ag\Icons"
        AgAgentScriptsDir = "C:\Ag\agentScripts"
        AgToolsDir = "C:\Tools"
        AgTempDir = "C:\Temp"
        AgVHDXDir = "C:\Ag\VHDX"
        AgL1Files = "C:\Ag\L1Files"
    }

    # Az CLI required extensions
    AzCLIExtensions                      = @()

    # PowerShell modules
    PowerShellModules                    = @('Az.ConnectedKubernetes')

    # Chocolatey app list
    chocolateyAppList = @('azure-cli','az.powershell','kubernetes-cli','vcredist140','microsoft-edge','azcopy10','vscode','git','7zip','kubectx','putty.install','kubernetes-helm','dotnetcore-3.1-sdk','zoomit','openssl.light','mqtt-explorer','grafana')

    # VSCode extensions
    VSCodeExtensions  = @('ms-vscode-remote.remote-containers','ms-vscode-remote.remote-wsl')

    # VHDX Paths 
    L0VHDPath                            = "C:\Ag\VHD\L0.vhdx"              # This value controls the location of the GUI VHDX.              
    L1VHDPath                            = "C:\Ag\VHD\L1.vhdx"                 # This value controls the location of the Azure Stack HCI VHDX. 
    
    AzureProviders                       = "Microsoft.Kubernetes", "Microsoft.KubernetesConfiguration", "Microsoft.ExtendedLocation"
    
    # L1 VM Configuration
    HostVMPath                           = "V:\VMs"                              # This value controls the path where the Nested VMs will be stored the host.
    L1VMMemory                           = 24GB                                  # This value controls the amount of RAM for each AKS EE host VM
    L1VMNumVCPU                          = 8                                     # This value controls the number of vCPUs to assign to each AKS EE host VM
    InternalSwitch                       = "InternalSwitch"                      # Name of the internal switch that the L0 VM will use.
    L1Username                           = "Administrator"                       # Admin credential for the 3 VMs that run on the Agora-Client
    L1Password                           = 'Agora123!!'                          # 
    L1DefaultGateway                     = "172.20.1.1"                          #
    L1SwitchName                         = "AKS-Int"                             #
    L1NatSubnetPrefix                    = "172.20.1.0/24"                       #

    # NAT Configuration
    natHostSubnet                        = "192.168.128.0/24"
    natHostVMSwitchName                  = "InternalNAT"
    natConfigure                         = $true
    natSubnet                            = "192.168.46.0/24"                      # This value is the subnet is the NAT router will use to route to  AzSMGMT to access the Internet. It can be any /24 subnet and is only used for routing.
    natDNS                               = "%staging-natDNS%"                     # Do not change - can be configured by passing the optioanl natDNS parameter to the ARM deployment.

    # AKS variables
    SiteConfig = @{
        Seattle = @{
            ArcClusterName = "Ag-AKSEE-Seattle"
            NetIPAddress = "172.20.1.2"
            DefaultGateway = "172.20.1.1"
            PrefixLength = "24"
            DNSClientServerAddress = "168.63.129.16"
            ServiceIPRangeStart = "172.20.1.31"
            ServiceIPRangeSize = "10"
            ControlPlaneEndpointIp = "172.20.1.21"
            LinuxNodeIp4Address = "172.20.1.11"
        }
        Chicago = @{
            ArcClusterName = "Ag-AKSEE-Chicago"
            NetIPAddress = "172.20.1.3"
            DefaultGateway = "172.20.1.1"
            PrefixLength = "24"
            DNSClientServerAddress = "168.63.129.16"
            ServiceIPRangeStart = "172.20.1.71"
            ServiceIPRangeSize = "10"
            ControlPlaneEndpointIp = "172.20.1.61"
            LinuxNodeIp4Address = "172.20.1.51"
        }
        AKSEEDev = @{
            ArcClusterName = "Ag-AKSEE-Dev"
            NetIPAddress = "172.20.1.4"
            DefaultGateway = "172.20.1.1"
            PrefixLength = "24"
            DNSClientServerAddress = "168.63.129.16"
            ServiceIPRangeStart = "172.20.1.101"
            ServiceIPRangeSize = "10"
            ControlPlaneEndpointIp = "172.20.1.91"
            LinuxNodeIp4Address = "172.20.1.81"
        }
    }
}