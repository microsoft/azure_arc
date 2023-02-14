@{

    # This is the PowerShell datafile used to provide configuration information for the HCIBox environment. Product keys and password are not encrypted and will be available on all hosts during installation.
    
    # Version 1.0.0

    # HCI host names
    HostList                             = "AZSHOST1", "AZSHOST2"  # DO NOT CHANGE these as they remain hardcoded in places

    # VHDX Paths 
    guiVHDXPath                          = "C:\HCIBox\VHD\gui.vhdx"              # This value controls the location of the GUI VHDX.              
    azsHCIVHDXPath                       = "C:\HCIBox\VHD\azshci.vhdx"           # This value controls the location of the Azure Stack HCI VHDX. 
    
    # SDN Lab Admin Password
    SDNAdminPassword                     = '%staging-password%'                  # Do not change - this value is replaced during Bootstrap with the password supplied in the ARM deployment

    # VM Configuration
    HostVMPath                           = "V:\VMs"                              # This value controls the path where the Nested VMs will be stored on all hosts.
    NestedVMMemoryinGB                   = 70GB                                  # This value controls the amount of RAM for each Nested Hyper-V Host (AzSHOST1-2).
    AzSMGMTMemoryinGB                    = 32GB                                  # This value controls the amount of RAM for the AzSMGMT Nested VM which contains only the Console, Router, Admincenter, and DC VMs.
    InternalSwitch                       = "InternalSwitch"                      # Name of internal switch that the HCIBox VMs will use in Single Host mode. This only applies when using a single host.

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
    MEM_Console                          = 3GB                                     # Memory provided for the Windows 10 Console VM
    MEM_WAC                              = 8GB                                     # Memory provided for the Windows Admin Center VM
    MEM_GRE                              = 2GB                                     # Memory provided for the gre-target VM
    MEM_IPSEC                            = 2GB                                     # Memory provided for the ipsec-target VM

    # Cluster S2D Storage Disk Size (per disk)
    S2D_Disk_Size                        = 100GB                                    # Disk size for each of the 4 dynamic VHD disks attached to the 3 AzSHOST VMs that will be used to create the SDNCLUSTER

    # SDN Host IPs
    AzSMGMTIP                            = "192.168.1.11/24"
    AzSHOST1IP                           = "192.168.1.12/24"
    AzSHOST2IP                           = "192.168.1.13/24"
    AzSHOST3IP                           = "192.168.1.14/24"

    # Physical Host Internal IP
    PhysicalHostInternalIP               = "192.168.1.20"                          # IP Address assigned to Internal Switch vNIC in a Single Host Configuration

    # SDN Lab DNS
    SDNLABDNS                            = "192.168.1.254" 

    # SDN Lab Gateway
    SDNLABRoute                          = "192.168.1.1"

    # Management IPs for Console and Domain Controller
    DCIP                                 = "192.168.1.254/24"
    CONSOLEIP                            = "192.168.1.10/24"
    WACIP                                = "192.168.1.9/24"

    # BGP Router Config
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
    StorageAVLAN                         = 20
    StorageBVLAN                         = 21

    # Subnets
    MGMTSubnet                           = "192.168.1.0/24"
    GRESubnet                            = "50.50.50.0/24"
    ProviderSubnet                       = "172.16.0.0/24"
    VLAN200Subnet                        = "192.168.200.0/24"
    VLAN200VMNetworkSubnet               = "192.168.44.0/24"
    simInternetSubnet                    = "131.127.0.0/24"
    storageAsubnet                       = "192.168.98.0/24"
    storageBsubnet                       = "192.168.99.0/24"

    # Gateway Target IPs
    GRETARGETIP_BE                       = "192.168.233.100/24"
    GRETARGETIP_FE                       = "131.127.0.35/24"
    IPSECTARGETIP_BE                     = "192.168.111.100/24"
    IPSECTARGETIP_FE                     = "131.127.0.30/24"

    # VIP Subnets
    PrivateVIPSubnet                     = "30.30.30.0/24" 
    PublicVIPSubnet                      = "40.40.40.0/24"

    # SDN ASN
    SDNASN                               = 64512
    WACASN                               = 65533

    # Windows Admin Center HTTPS Port
    WACport                              = 443

    # SDDCInstall
    SDDCInstall                          = $true

    # AKS and Resource bridge variables
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
    rbLocation                           = "eastus"
    rbCustomLocationName                 = "hcibox-rb-cl"
    rbIp                                 = "192.168.200.201"
    rbIp2                                = "192.168.200.203"
    rbCpip                               = "192.168.200.202"
    rbVipStart                           = "192.168.200.200"
    rbVipEnd                             = "192.168.200.249"
    rbDHCPExclusionStart                 = "192.168.200.200"
    rbDHCPExclusionEnd                   = "192.168.200.209"
    dcVLAN200IP                          = "192.168.200.205"
}