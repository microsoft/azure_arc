@{
    # This is the PowerShell datafile used to provide configuration information for the ft1 environment. Product keys and password are not encrypted and will be available on host during installation.

    # Directory paths
    Ft1Directories           = @{
        Ft1Dir             = "C:\Ft1"
        Ft1LogsDir         = "C:\Ft1\Logs"
        Ft1PowerShellDir   = "C:\Ft1\PowerShell"
        Ft1ToolsDir        = "C:\Tools"
        Ft1TempDir         = "C:\Temp"
        Ft1ConfigMapDir    = "C:\Ft1\ConfigMaps"
        Ft1AppsRepo        = "C:\Ft1\AppsRepo"
        Ft1DataEmulator    = "C:\Ft1\DataEmulator"
        Ft1MonitoringDir   = "C:\Ft1\Monitoring"
    }

    # Required URLs
    URLs                    = @{
        chocoInstallScript = 'https://chocolatey.org/install.ps1'
        wslUbuntu          = 'https://aka.ms/wslubuntu'
        wslStoreStorage    = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
        githubAPI          = 'https://api.github.com'
        grafana            = 'https://api.github.com/repos/grafana/grafana/releases/latest'
        azurePortal        = 'https://portal.azure.com'
        aksEEk3s           = 'https://aka.ms/aks-edge/k3s-msi'
        prometheus         = 'https://prometheus-community.github.io/helm-charts'
        vcLibs             = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        windowsTerminal    = 'https://api.github.com/repos/microsoft/terminal/releases/latest'
        aksEEReleases      = 'https://api.github.com/repos/Azure/AKS-Edge/releases'
    }

    # Azure required registered resource providers
    AzureProviders          = @(
        "Microsoft.Kubernetes",
        "Microsoft.KubernetesConfiguration",
        "Microsoft.ExtendedLocation",
        "Microsoft.HybridCompute",
        "Microsoft.GuestConfiguration",
        "Microsoft.HybridConnectivity"
    )

    # Az CLI required extensions
    AzCLIExtensions         = @(
        'k8s-extension',
        'k8s-configuration',
        'azure-iot'
    )

    # PowerShell modules
    PowerShellModules       = @(
        'Az.ConnectedKubernetes'
        'Az.KubernetesConfiguration'
        'Az.Kusto'
    )

    # Chocolatey packages list
    ChocolateyPackagesList  = @(
        'az.powershell',
        'kubernetes-cli',
        'vcredist140',
        'azcopy10',
        'vscode',
        'git',
        '7zip',
        'kubectx',
        'putty.install',
        'kubernetes-helm',
        'mqtt-explorer',
        'gh'
    )

    # VSCode extensions
    VSCodeExtensions        = @(
        'ms-vscode-remote.remote-wsl',
        'ms-vscode.powershell',
        'redhat.vscode-yaml',
        'ZainChen.json',
        'esbenp.prettier-vscode',
        'ms-kubernetes-tools.vscode-kubernetes-tools',
        'mindaro.mindaro',
        'github.vscode-pull-request-github'
    )


    AKSEEConfig             = @{
        AksEdgeRemoteDeployVersion = "1.0.230221.1200"
        aksEdgeDeployModules       = "main"

        aideuserConfig = @{
            SchemaVersion       = "1.1"
            Version             = "1.0"
            AksEdgeProduct      = ""
            AksEdgeProductUrl   = ""
            Azure               = @{
                SubscriptionId    = ""
                TenantId          = ""
                ResourceGroupName = ""
                Location          = ""
            }
            AksEdgeConfigFile   = "aksedge-config.json"
        }

        Nodes = @{
            'LinuxNode' = @{
                'CpuCount'     = 4
                'MemoryInMB'   = 4096
                'DataSizeInGB' = 20
            }
            'WindowsNode' = @{
                'CpuCount'   = 2
                'MemoryInMB' = 4096
            }
        }

        aksedgeConfig = @{
            SchemaVersion       = ""
            Version             = "1.0"
            DeploymentType      = "SingleMachineCluster"
            Init                =@{
                ServiceIPRangeSize          = 0
            }
            Network             = @{
                NetworkPlugin               = ""
                InternetDisabled            = $false
            }
            User                = @{
                AcceptEula                 = $true
                AcceptOptionalTelemetry    = $true
            }
            Machines            = @()
        }
    }
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
            AKSEEReleaseUseLatest  = $true                            # If set to true, the latest AKSEE release will be used. If set to false, the n-1 version will be used
        }
        Dev     = @{
            ArcClusterName         = "Ag-ArcK8s-Dev"
            NetIPAddress           = "172.20.1.4"
            DefaultGateway         = "172.20.1.1"
            PrefixLength           = "24"
            DNSClientServerAddress = "168.63.129.16"
            ServiceIPRangeStart    = "172.20.1.101"
            ServiceIPRangeSize     = "10"
            ControlPlaneEndpointIp = "172.20.1.91"
            LinuxNodeIp4Address    = "172.20.1.81"
            Subnet                 = "172.20.1.0/24"
            FriendlyName           = "Dev"
            IsProduction           = $false
            Type                   = "AKSEE"
            posNamespace           = "contoso-supermarket"
            Branch                 = "main"
            HelmSetValue           = "alertmanager.enabled=false,grafana.ingress.enabled=true,grafana.service.type=LoadBalancer,prometheus.service.type=LoadBalancer,grafana.adminPassword=adminPasswordPlaceholder"
            HelmService            = "service/prometheus-grafana"
            GrafanaDataSource      = "prometheus"
            HelmValuesFile         = "prometheus-additional-scrape-config.yaml"
            IoTDevices             = @("Freezer-1", "Freezer-2")
            AKSEEReleaseUseLatest  = $true                            # If set to true, the latest AKSEE release will be used. If set to false, the n-1 version will be used
        }
        Staging = @{
            ArcClusterName     = "Ag-AKS-Staging"
            FriendlyName       = "Staging"
            IsProduction       = $false
            Type               = "AKS"
            posNamespace       = "contoso-supermarket"
            Branch             = "staging"
            HelmSetValue       = "alertmanager.enabled=false,grafana.ingress.enabled=true,grafana.service.type=LoadBalancer,prometheus.service.type=LoadBalancer,grafana.adminPassword=adminPasswordPlaceholder"
            HelmService        = "service/prometheus-grafana"
            GrafanaDataSource  = "prometheus"
            HelmValuesFile     = "prometheus-additional-scrape-config.yaml"
            IoTDevices          = @("Freezer-1", "Freezer-2")
        }
    }

    # Universal resource tag and resource types
    TagName                 = 'Project'
    TagValue                = 'Jumpstart_ft1'
    ArcServerResourceType   = 'Microsoft.HybridCompute/machines'
    ArcK8sResourceType      = 'Microsoft.Kubernetes/connectedClusters'

    # Observability variables
    Monitoring              = @{
        AdminUser  = "admin"
        User       = "Contoso Operator"
        Email      = "operator@contoso.com"
        Namespace  = "observability"
        ProdURL    = "http://localhost:3000"
        Dashboards = @{
            "grafana.com" = @() # Dashboards from https://grafana.com/grafana/dashboards
            "custom"      = @('freezer-monitoring','node-exporter-full','cluster-global') # Dashboards from https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_ag/artifacts/monitoring
        }
    }

    # Microsoft Edge startup settings variables
    EdgeSettingRegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    EdgeSettingValueTrue    = '00000001'
    EdgeSettingValueFalse   = '00000000'

    Namespaces              = @(
        "contoso-supermarket"
        "observability"
        "sensor-monitor"
        "images-cache"
    )

    AppConfig = @{
        ContosoSupermarket_contosodb = @{
            GitOpsConfigName = "config-supermarket-db"
            KustomizationName = "contosodb"
            KustomizationPath="./contoso_supermarket/operations/contoso_supermarket/releases/contosodb"
            Namespace = "contoso-supermarket"
            Order = 1
        }
        ContosoSupermarket_cloudsync = @{
            GitOpsConfigName = "config-supermarket-cloudsync"
            KustomizationName = "cloudsync"
            KustomizationPath="./contoso_supermarket/operations/contoso_supermarket/releases/cloudsync"
            Namespace = "contoso-supermarket"
            Order = 2
        }
        ContosoSupermarket_contosopos = @{
            GitOpsConfigName = "config-supermarket-pos"
            KustomizationName = "contosopos"
            KustomizationPath="./contoso_supermarket/operations/contoso_supermarket/releases/contosopos"
            Namespace = "contoso-supermarket"
            Order = 3
        }
        ContosoSupermarket_queue_monitoring_backend = @{
            GitOpsConfigName = "config-supermarket-queue-backend"
            KustomizationName = "queuebackend"
            KustomizationPath="./contoso_supermarket/operations/contoso_supermarket/releases/queue-monitoring-backend"
            Namespace = "contoso-supermarket"
            Order = 4
        }
        ContosoSupermarket_contosoai = @{
            GitOpsConfigName = "config-supermarket-ai"
            KustomizationName = "contosoai"
            KustomizationPath="./contoso_supermarket/operations/contoso_supermarket/releases/contosoai"
            Namespace = "contoso-supermarket"
            Order = 5
        }
        ContosoSupermarket_queue_monitoring_frontend = @{
            GitOpsConfigName = "config-supermarket-queue-frontend"
            KustomizationName = "queuefrontend"
            KustomizationPath="./contoso_supermarket/operations/contoso_supermarket/releases/queue-monitoring-frontend"
            Namespace = "contoso-supermarket"
            Order = 6
        }
        SensorMonitor = @{
            GitOpsConfigName  = "config-sensormonitor"
            KustomizationName = "sensor-monitor"
            KustomizationPath = "./contoso_supermarket/operations/freezer_monitoring/release"
            Namespace         = "sensor-monitor"
            AppPath           = "freezer_monitoring"
            ConfigMaps = @{
                "mqtt-broker-config" = @{
                    ContainerName = "mqtt-broker"
                    RepoPath      = "contents/contoso_supermarket/developer/freezer_monitoring/src/mqtt-broker/mosquitto.conf"
                }
                "mqtt-simulator-config" = @{
                    ContainerName = "mqtt-simulator"
                    RepoPath      = "contents/contoso_supermarket/developer/freezer_monitoring/src/mqtt-simulator/config/settings.json"
                }
                "mqtt2prom-config" = @{
                    ContainerName = "mqtt2prom"
                    RepoPath      = "contents/contoso_supermarket/developer/freezer_monitoring/src/mqtt2prom/config.yaml"
                }
            }
            Order = 7
        }
    }
}
