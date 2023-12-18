@{

    # This is the PowerShell datafile used to provide configuration information for the HCIBox environment. Product keys and password are not encrypted and will be available on all hosts during installation.
    
    # HCIBox Folders
    Paths = @{
        VMDir = "C:\HCIBox\Virtual Machines"
        LogsDir = "C:\HCIBox\Logs"
        IconDir = "C:\HCIBox\Icons"
        VHDDir = "C:\HCIBox\VHD"
        SDNDir = "C:\HCIBox\SDN"
        KVDir = "C:\HCIBox\KeyVault"
        WACDir = "C:\HCIBox\Windows Admin Center"
        AgentScriptDir = "C:\HCIBox\agentScript"
        ToolsDir = "C:\Tools"
        TempDir = "C:\Temp"
        VMPath = "C:\VMs"
    }

    ChocolateyPackagesList = @(
        'az.powershell',
        'kubernetes-cli',
        'vcredist140',
        'microsoft-edge',
        'azcopy10',
        'vscode',
        'git',
        '7zip',
        'kubectx',
        'terraform',
        'putty.install',
        'kubernetes-helm',
        'dotnet-sdk',
        'setdefaultbrowser',
        'zoomit',
        'azure-data-studio'
    )

    # VSCode extensions
    VSCodeExtensions        = @(
        'ms-vscode-remote.remote-containers',
        'ms-vscode-remote.remote-wsl',
        'ms-vscode.powershell',
        'redhat.vscode-yaml',
        'ZainChen.json',
        'esbenp.prettier-vscode',
        'ms-kubernetes-tools.vscode-kubernetes-tools'
    )

    HostVMDriveLetter = "V"
    HostVMPath        = "V:\VMs"                              # This value controls the path where the Nested VMs will be stored on all hosts.
    guiVHDXPath       = "C:\HCIBox\VHD\gui.vhdx"              # This value controls the location of the GUI VHDX.              
    azsHCIVHDXPath    = "C:\HCIBox\VHD\azshci.vhdx"           # This value controls the location of the Azure Stack HCI VHDX. \
    
    MgmtHostConfig = @{
        Hostname = "AzSMGMT"
        IP       = "192.168.1.11/24"
    }

    NodeHostConfig = @(
        @{
            Hostname    = "AzSHOST1"
            IP          = "192.168.1.12/24"
            StorageAIP  = "10.71.1.10"
            StorageBIP  = "10.71.2.10"
        },
        @{
            Hostname    = "AzSHOST2"
            IP          = "192.168.1.13/24"
            StorageAIP  = "10.71.1.11"
            StorageBIP  = "10.71.2.11"
        }
    )
    
    # SDN Lab Admin Password
    SDNAdminPassword                     = '%staging-password%'                  # Do not change - this value is replaced during Bootstrap with the password supplied in the ARM deployment

    # VM Configuration
    NestedVMMemoryinGB                   = 105GB                                 # This value controls the amount of RAM for each Nested Hyper-V Host (AzSHOST1-2).
    AzSMGMTMemoryinGB                    = 28GB                                  # This value controls the amount of RAM for the AzSMGMT Nested VM which contains only the Console, Router, Admincenter, and DC VMs.
    AzSMGMTProcCount                     = 20
    InternalSwitch                       = "InternalSwitch"                      # Name of internal switch that the HCIBox VMs will use in Single Host mode.
    FabricSwitch                         = "vSwitch-Fabric"
    FabricNIC                            = "FABRIC"
    ClusterVSwitchName                   = "hciSwitch"
    ClusterName                          = "hciboxcluster"
    WACVMName                            = "AdminCenter"
    ClusterSharedVolumePath              = "C:\ClusterStorage\S2D_vDISK1"
    LCMDeployUsername                    = "HCIBoxDeployUser"
    LCMADOUName                          = "hcioudocs"
    LCMDeploymentPrefix                  = "hcibox"

    # ProductKeys
    GUIProductKey                        = "WX4NM-KYWYW-QJJR4-XV3QB-6VM33"        # Product key for Windows Server 2019 (Desktop Experience) Datacenter Installation

    # SDN Lab Domain
    SDNDomainFQDN                        = "jumpstart.local"                      # Limit name (not the .com) to 14 characters as the name will be used as the NetBIOS name. 
    DCName                               = "jumpstartdc"                          # Name of the domain controller virtual machine (limit to 14 characters)

    # NAT Configuration
    natHostSubnet                        = "192.168.128.0/24"
    natHostVMSwitchName                  = "InternalNAT"
    natConfigure                         = $true
    natSubnet                            = "192.168.46.0/24"                      # This value is the subnet is the NAT router will use to route to  AzSMGMT to access the Internet. It can be any /24 subnet and is only used for routing.
    natDNS                               = "%staging-natDNS%"                     # Do not change - can be configured by passing the optioanl natDNS parameter to the ARM deployment.

    # Global MTU
    SDNLABMTU                            = 9014                                   # Controls the MTU for all Hosts. 

    #SDN Provisioning
    ProvisionNC                          = $false                                 # Provisions Network Controller Automatically.
    ConfigureBGPpeering                  = $true                                  # Peers the GW and MUX VMs with the BGP-ToR-Router automatically if ProvisionNC = $true

    ################################################################################################################
    # Edit at your own risk. If you edit the subnets, ensure that you keep using the PreFix /24.                   #
    ################################################################################################################

    # AzSMGMT Management VM's Memory Settings
    MEM_DC                               = 2GB                                     # Memory provided for the Domain Controller VM
    MEM_BGP                              = 2GB                                     # Memory provided for the BGP-ToR-Router
    MEM_WAC                              = 10GB                                    # Memory provided for the Windows Admin Center VM

    # Cluster S2D Storage Disk Size (per disk)
    S2D_Disk_Size                        = 170GB                                    # Disk size for each of the 4 dynamic VHD disks attached to the 3 AzSHOST VMs that will be used to create the SDNCLUSTER

    # Physical Host Internal IP
    PhysicalHostInternalIP               = "192.168.1.20"                          # IP Address assigned to Internal Switch vNIC in a Single Host Configuration

    # SDN Lab DNS
    SDNLABDNS                            = "192.168.1.254" 

    # SDN Lab Gateway
    SDNLABRoute                          = "192.168.1.1"

    # Management IPs for Console and Domain Controller
    DCIP                                 = "192.168.1.254/24"
    WACIP                                = "192.168.1.9/24"
    WACMAC                               = "10155D010B00"

    # BGP Router Config
    BGPRouterName                        = "bgp-router"
    BGPRouterIP_MGMT                     = "192.168.1.1/24"
    BGPRouterIP_ProviderNetwork          = "172.16.0.1/24"
    BGPRouterIP_VLAN200                  = "192.168.200.1/24"
    BGPRouterIP_SimulatedInternet        = "131.127.0.1/24"
    BGPRouterASN                         = "65534"

    # VLANs
    providerVLAN                         = 12
    vlan200VLAN                          = 200
    mgmtVLAN                             = 0
    simInternetVLAN                      = 131
    StorageAVLAN                         = 711
    StorageBVLAN                         = 712

    # Subnets
    MGMTSubnet                           = "192.168.1.0/24"
    storageAsubnet                       = "255.255.255.0"
    storageBsubnet                       = "255.255.255.0"

    # VIP Subnets
    PublicVIPSubnet                      = "40.40.40.0/24"

    # SDN ASN
    SDNASN                               = 64512
    WACASN                               = 65533

    # Windows Admin Center HTTPS Port
    WACport                              = 443

    # AKS and Resource bridge variables
    AKSworkloadClusterName               = "hcibox-aks" # lowercase only
    AKSvnetname                          = "akshcivnet"
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
    rbLocation                           = "eastus"
    rbCustomLocationName                 = "hcibox-rb-cl"
    rbIp                                 = "192.168.200.201"
    rbIp2                                = "192.168.200.202"
    rbCpip                               = "192.168.200.203"
    rbVipStart                           = "192.168.200.200"
    rbVipEnd                             = "192.168.200.249"
    rbDHCPExclusionStart                 = "192.168.200.200"
    rbDHCPExclusionEnd                   = "192.168.200.209"
    dcVLAN200IP                          = "192.168.200.205"
    rbSubnetMask                         = "255.255.255.0"
    rbDNSIP                              = "192.168.1.254"
    clusterIpRangeStart                  = "192.168.1.100"
    clusterIpRangeEnd                    = "192.168.1.199"
}