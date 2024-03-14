@{
    # This is the PowerShell datafile used to provide configuration information for the Agora environment. Product keys and password are not encrypted and will be available on host during installation.

    # Directory paths
    AgDirectories           = @{
        AgDir             = "C:\Ag"
        AgPowerShellDir   = "C:\Ag\PowerShell"
        AgLogsDir         = "C:\Ag\Logs"
        AgVMDir           = "C:\Ag\Virtual Machines"
        AgIconDir         = "C:\Ag\Icons"
        AgToolsDir        = "C:\Tools"
        AgTempDir         = "C:\Temp"
        AgVHDXDir         = "V:\VMs"
        AgConfigMapDir    = "C:\Ag\ConfigMaps"
        AgL1Files         = "C:\Ag\L1Files"
        AgAppsRepo        = "C:\Ag\AppsRepo"
        AgMonitoringDir   = "C:\Ag\Monitoring"
    }

    # Required URLs
    URLs                    = @{
        chocoInstallScript      = 'https://chocolatey.org/install.ps1'
        wslUbuntu               = 'https://aka.ms/wslubuntu'
        wslStoreStorage         = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
        docker                  = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
        githubAPI               = 'https://api.github.com'
        grafana                 = 'https://api.github.com/repos/grafana/grafana/releases/latest'
        azurePortal             = 'https://portal.azure.com'
        aksEEk3s                = 'https://aka.ms/aks-edge/k3s-msi'
        nginx                   = 'https://kubernetes.github.io/ingress-nginx'
        prometheus              = 'https://prometheus-community.github.io/helm-charts'
        vcLibs                  = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        windowsTerminal         = 'https://api.github.com/repos/microsoft/terminal/releases/latest'
        aksEEReleases           = 'https://api.github.com/repos/Azure/AKS-Edge/releases'
        mqttExplorerReleases    = 'https://api.github.com/repos/thomasnordquist/MQTT-Explorer/releases/latest'
    }

    # Azure required registered resource providers
    AzureProviders          = @(
        "Microsoft.Kubernetes",
        "Microsoft.KubernetesConfiguration",
        "Microsoft.ExtendedLocation",
        "Microsoft.HybridCompute",
        "Microsoft.GuestConfiguration",
        "Microsoft.HybridConnectivity",
        "Microsoft.DeviceRegistry",
        "Microsoft.EventGrid",
        "Microsoft.ExtendedLocation",
        "Microsoft.IoTOperationsOrchestrator",
        "Microsoft.IoTOperationsMQ",
        "Microsoft.IoTOperationsDataProcessor",
        #RP for ESA:
        "Microsoft.openservicemesh"
    )

    # Az CLI required extensions
    AzCLIExtensions         = @(
        'k8s-extension',
        'k8s-configuration',
        'eventgrid',
        'customlocation',
        'kusto',
        'storage-preview'
        'azure-iot-ops'
    )

    # PowerShell modules
    PowerShellModules       = @(
        'Az.ConnectedKubernetes',
        'Az.KubernetesConfiguration',
        'Az.Kusto',
        'Az.EventGrid',
        'Az.Storage',
        'Az.EventHub'
    )

    # Chocolatey packages list
    ChocolateyPackagesList  = @(
        'az.powershell',
        'kubernetes-cli',
        'vcredist140',
        'microsoft-edge',
        'azcopy10',
        'vscode',
        'git',
        '7zip',
        'kubectx',
        'putty.install',
        'kubernetes-helm',
        'dotnet-sdk',
        'zoomit',
        'openssl.light',
        'mqtt-explorer',
        'gh',
        'python'
    )

    # Pip packages list
    PipPackagesList     = @(
        'paho-mqtt'
    )

    # VSCode extensions
    VSCodeExtensions        = @(
        'ms-vscode-remote.remote-containers',
        'ms-vscode-remote.remote-wsl',
        'ms-vscode.powershell',
        'redhat.vscode-yaml',
        'ZainChen.json',
        'esbenp.prettier-vscode',
        'ms-kubernetes-tools.vscode-kubernetes-tools',
        'mindaro.mindaro',
        'github.vscode-pull-request-github'
    )

    # Git branches
    GitBranches             = @(
        'production',
        'staging',
        'canary' ,
        'main'
    )

    # VHDX blob url
    ProdVHDBlobURL          = 'https://jsvhds.blob.core.windows.net/agora/contoso-supermarket-w11/AGBase.vhdx?sp=r&st=2023-05-06T14:38:41Z&se=2033-05-06T22:38:41Z&spr=https&sv=2022-11-02&sr=b&sig=DTDZOvPlzwrjg3gppwVo1TdDZRgPt5AYBfe9YeKEobo%3D'
    PreProdVHDBlobURL       = 'https://jsvhds.blob.core.windows.net/agora/contoso-supermarket-w11-preprod/*?si=Agora-RL&spr=https&sv=2021-12-02&sr=c&sig=Afl5LPMp5EsQWrFU1bh7ktTsxhtk0QcurW0NVU%2FD76k%3D'

    # L1 virtual machine configuration
    HostVMDrive             = "V"                                   # This value controls the drive letter where the nested virtual
    L1VMMemory              = 32GB                                  # This value controls the amount of RAM for each AKS Edge Essentials host virtual machine
    L1VMNumVCPU             = 8                                     # This value controls the number of vCPUs to assign to each AKS Edge Essentials host virtual machine.
    InternalSwitch          = "InternalSwitch"                      # This value controls the Hyper-V internal switch name used by L0 Azure virtual machine.
    L1Username              = "Administrator"                       # This value controls the Admin credential username for the L1 Hyper-V virtual machines that run on the Agora-Client.
    L1Password              = 'Agora123!!'                          # This value controls the Admin credential password for the L1 Hyper-V virtual machines that run on the Agora-Client.
    L1DefaultGateway        = "172.20.1.1"                          # This value controls the default gateway IP address used by each L1 Hyper-V virtual machines that run on the Agora-Client.
    L1SwitchName            = "AKS-Int"                             # This value controls the Hyper-V internal switch name used by each L1 Hyper-V virtual machines that run on the Agora-Client.
    L1NatSubnetPrefix       = "172.20.1.0/24"                       # This value controls the network subnet used by each L1 Hyper-V virtual machines that run on the Agora-Client.

    # NAT Configuration
    natHostSubnet           = "192.168.128.0/24"
    natHostVMSwitchName     = "InternalNAT"
    natConfigure            = $true
    natSubnet               = "192.168.46.0/24"                      # This value is the subnet is the NAT router will use to route to  AzSMGMT to access the Internet. It can be any /24 subnet and is only used for routing.
    natDNS                  = "%staging-natDNS%"                     # Do not change - can be configured by passing the optional natDNS parameter to the ARM deployment.

    # AKS Edge Essentials variables
    SiteConfig              = @{
        Seattle = @{
            ArcClusterName         = "Ag-ArcK8s-Seattle"
            NetIPAddress           = "172.20.1.2"
            DefaultGateway         = "172.20.1.1"
            PrefixLength           = "24"
            DNSClientServerAddress = "168.63.129.16"
            ServiceIPRangeStart    = "172.20.1.31"
            ServiceIPRangeSize     = "10"
            ControlPlaneEndpointIp = "172.20.1.21"
            LinuxNodeIp4Address    = "172.20.1.11"
            Subnet                 = "172.20.1.0/24"
            FriendlyName           = "Seattle"
            IsProduction           = $true
            Type                   = "AKSEE"
            posNamespace           = "contoso-supermarket"
            Branch                 = "production"
            HelmSetValue           = "alertmanager.enabled=false,grafana.enabled=false,prometheus.service.type=LoadBalancer"
            HelmService            = "service/prometheus-kube-prometheus-prometheus"
            GrafanaDataSource      = "seattle"
            HelmValuesFile         = "prometheus-additional-scrape-config.yaml"
            IoTDevices             = @("Freezer-1", "Freezer-2")
            clusterLogSize         = "1024"
            AKSEEReleaseUseLatest  = $true                            # If set to true, the latest AKSEE release will be used. If set to false, the n-1 version will be used
        }
        Chicago = @{
            ArcClusterName         = "Ag-ArcK8s-Chicago"
            NetIPAddress           = "172.20.1.3"
            DefaultGateway         = "172.20.1.1"
            PrefixLength           = "24"
            DNSClientServerAddress = "168.63.129.16"
            ServiceIPRangeStart    = "172.20.1.71"
            ServiceIPRangeSize     = "10"
            ControlPlaneEndpointIp = "172.20.1.61"
            LinuxNodeIp4Address    = "172.20.1.51"
            Subnet                 = "172.20.1.0/24"
            FriendlyName           = "Chicago"
            IsProduction           = $true
            Type                   = "AKSEE"
            posNamespace           = "contoso-supermarket"
            Branch                 = "canary"
            HelmSetValue           = "alertmanager.enabled=false,grafana.enabled=false,prometheus.service.type=LoadBalancer"
            HelmService            = "service/prometheus-kube-prometheus-prometheus"
            GrafanaDataSource      = "chicago"
            HelmValuesFile         = "prometheus-additional-scrape-config.yaml"
            IoTDevices             = @("Freezer-1", "Freezer-2")
            clusterLogSize         = "1024"
            AKSEEReleaseUseLatest  = $true                            # If set to true, the latest AKSEE release will be used. If set to false, the n-1 version will be used
        }
    }

    # Universal resource tag and resource types
    TagName                 = 'Project'
    TagValue                = 'Jumpstart_Agora'
    ArcServerResourceType   = 'Microsoft.HybridCompute/machines'
    ArcK8sResourceType      = 'Microsoft.Kubernetes/connectedClusters'
    AksResourceType         = 'Microsoft.ContainerService/managedClusters'


    # Observability variables
    Monitoring              = @{
        AdminUser  = "admin"
        User       = "Contoso Operator"
        Email      = "operator@contoso.com"
        Namespace  = "observability"
        ProdURL    = "http://localhost:3000"
        Dashboards = @{
            "grafana.com" = @() # Dashboards from https://grafana.com/grafana/dashboards
            "custom"      = @('node-exporter-full','cluster-global') # Dashboards from https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_ag/artifacts/monitoring
        }
    }

    Namespaces              = @(
        "contoso-manufacturing"
        "observability"
        "images-cache"
    )

    AppConfig = @{
        ContosoBakeries_decode = @{
            GitOpsConfigName = "config-decode"
            KustomizationName = "decode"
            KustomizationPath="./contoso_manufacturing/operations/contoso_manufacturing/releases/decode"
            Namespace = "contoso-bakeries"
            Order = 1
        }
        ContosoBakeries_rtspSimulator = @{
            GitOpsConfigName = "config-rtspSimulator"
            KustomizationName = "rtspSimulator"
            KustomizationPath="./contoso_manufacturing/operations/contoso_manufacturing/releases/rtspSimulator"
            Namespace = "contoso-bakeries"
            Order = 2
        }

        # SensorMonitor = @{
        #     GitOpsConfigName  = "config-sensormonitor"
        #     KustomizationName = "sensor-monitor"
        #     KustomizationPath = "./contoso_supermarket/operations/freezer_monitoring/release"
        #     Namespace         = "sensor-monitor"
        #     AppPath           = "freezer_monitoring"
        #     ConfigMaps = @{
        #         "mqtt-broker-config" = @{
        #             ContainerName = "mqtt-broker"
        #             RepoPath      = "contents/contoso_supermarket/developer/freezer_monitoring/src/mqtt-broker/mosquitto.conf"
        #         }
        #         "mqtt-simulator-config" = @{
        #             ContainerName = "mqtt-simulator"
        #             RepoPath      = "contents/contoso_supermarket/developer/freezer_monitoring/src/mqtt-simulator/config/settings.json"
        #         }
        #         "mqtt2prom-config" = @{
        #             ContainerName = "mqtt2prom"
        #             RepoPath      = "contents/contoso_supermarket/developer/freezer_monitoring/src/mqtt2prom/config.yaml"
        #         }
        #     }
        #     Order = 7
        # }
    }

    # Microsoft Edge startup settings variables
    EdgeSettingRegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    EdgeSettingValueTrue    = '00000001'
    EdgeSettingValueFalse   = '00000000'

}