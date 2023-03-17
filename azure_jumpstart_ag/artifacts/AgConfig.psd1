@{

    # This is the PowerShell datafile used to provide configuration information for the HCIBox environment. Product keys and password are not encrypted and will be available on all hosts during installation.
    
    # Version 1.0.0

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

    # Store location names
    StoreLocations                       = "Chicago", "New Orleans", "Seattle"                # The location names for the stores

    # VHDX Paths 
    L0VHDPath                            = "C:\Ag\VHD\L0.vhdx"              # This value controls the location of the GUI VHDX.              
    L1VHDPath                            = "C:\Ag\VHD\L1.vhdx"                 # This value controls the location of the Azure Stack HCI VHDX. 
    
    AzureProviders                       = "Microsoft.Kubernetes", "Microsoft.KubernetesConfiguration", "Microsoft.ExtendedLocation"
    
    # L1 VM Configuration
    HostVMPath                           = "V:\VMs"                              # This value controls the path where the Nested VMs will be stored the host.
    L1VMMemoryInGB                       = 16GB                                  # This value controls the amount of RAM for each AKS EE host VM
    L1VMNumVCPU                          = 4                                     # This value controls the number of vCPUs to assign to each AKS EE host VM
    InternalSwitch                       = "InternalSwitch"                      # Name of the internal switch that the L0 VM will use.
    L1Username                           = "Administrator"
    L1Password                           = '%staging-password%'
    L1DefaultGateway                     = "172.20.1.1"
    L1SwitchName                         = "AKS-Int"
    L1NatSubnetPrefix                    = "172.20.1.0/24"

    # SDN Lab Domain
    SDNDomainFQDN                        = "jumpstart.local"                      # Limit name (not the .com) to 14 characters as the name will be used as the NetBIOS name. 
    DCName                               = "jumpstartdc"                          # Name of the domain controller virtual machine (limit to 14 characters)

    # NAT Configuration
    natHostSubnet                        = "192.168.128.0/24"
    natHostVMSwitchName                  = "InternalNAT"
    natConfigure                         = $true
    natSubnet                            = "192.168.46.0/24"                      # This value is the subnet is the NAT router will use to route to  AzSMGMT to access the Internet. It can be any /24 subnet and is only used for routing.
    natDNS                               = "%staging-natDNS%"                     # Do not change - can be configured by passing the optioanl natDNS parameter to the ARM deployment.

    # AKS variables
    AKSworkloadClusterName               = "hcibox-aks" # lowercase only
    AKSvnetname                          = "akshcivnet"
    AKSvSwitchName                       = "sdnSwitch"
    AKSNodeStartIP                       = "192.168.200.25"
    AKSNodeEndIP                         = "192.168.200.100"
    AKSVIPStartIP                        = "192.168.200.125"
    AKSVIPEndIP                          = "192.168.200.200"
    AKSIPPrefix                          = "192.168.200.0/24"
    AKSGWIP                              = "192.168.200.1"
    AKSDNSIP                             = "192.168.1.254"
    AKSCSV                               = "C:\ClusterStorage\S2D_vDISK1"
    AKSImagedir                          = "C:\ClusterStorage\S2D_vDISK1\aks\Images"
    AKSWorkingdir                        = "C:\ClusterStorage\S2D_vDISK1\aks\Workdir"
    AKSCloudConfigdir                    = "C:\ClusterStorage\S2D_vDISK1\aks\CloudConfig"
    AKSCloudSvcidr                       = "192.168.1.15/24"
    AKSVlanID                            = "200"
}