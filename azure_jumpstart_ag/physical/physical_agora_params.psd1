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
        AgAdxDashboards   = "C:\Ag\AdxDashboards"
        AgDataEmulator    = "C:\Ag\DataEmulator"
        AgMonitoringDir   = "C:\Ag\Monitoring"
    }

    GitHub                 = @{
        githubAccount      = "agoraedge"
        githubBranch       = "physical_ag"
        gitHubUser         = "agoraedge"
        githubPat          = ""
    }
    # Required URLs

    AzureDeployment             =@{
        deploymentName     = ""
        azureLocation      = "westus2"
        appId              = ""
        spnClientSecret    = ""
        spnTenantId        = ""
        spnClientID        = ""
    }

    URLs                    = @{
        chocoInstallScript = 'https://chocolatey.org/install.ps1'
        wslUbuntu          = 'https://aka.ms/wslubuntu'
        wslStoreStorage    = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
        docker             = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
        githubAPI          = 'https://api.github.com'
        grafana            = 'https://api.github.com/repos/grafana/grafana/releases/latest'
        azurePortal        = 'https://portal.azure.com'
        aksEEk3s           = 'https://aka.ms/aks-edge/k3s-msi'
        nginx              = 'https://kubernetes.github.io/ingress-nginx'
        prometheus         = 'https://prometheus-community.github.io/helm-charts'
        vcLibs             = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        windowsTerminal    = 'https://api.github.com/repos/microsoft/terminal/releases/latest'
    }

    # Azure required registered resource providers
    AzureProviders          = @(
        "Microsoft.Kubernetes",
        "Microsoft.KubernetesConfiguration",
        "Microsoft.ExtendedLocation"
    )

    # Az CLI required extensions
    AzCLIExtensions         = @(
        'k8s-extension',
        'k8s-configuration',
        'azure-iot'
    )

    # PowerShell modules
    PowerShellModules       = @(
        'Az'
        'Az.Accounts'
        'Az.Resources'
        'Az.ConnectedKubernetes'
        'Az.KubernetesConfiguration'
        'Az.Kusto'
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
        'main'
    )

    # AKS Edge Essentials variables
    SiteConfig              = @{
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
        }
    }

    # Universal resource tag and resource types
    TagName                 = 'Project'
    TagValue                = 'Jumpstart_Agora'
    ArcServerResourceType   = 'Microsoft.HybridCompute/machines'
    ArcK8sResourceType      = 'Microsoft.Kubernetes/connectedClusters'
    AksResourceType         = 'Microsoft.ContainerService/managedClusters'

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
    }
}