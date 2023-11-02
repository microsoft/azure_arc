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
        Ft1DataExplorer    = "C:\Ft1\DataExplorer"
        Ft1MonitoringDir   = "C:\Ft1\Monitoring"
    }

    # Required URLs
    URLs                    = @{
        chocoInstallScript      = 'https://chocolatey.org/install.ps1'
        wslUbuntu               = 'https://aka.ms/wslubuntu'
        wslStoreStorage         = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
        githubAPI               = 'https://api.github.com'
        grafana                 = 'https://api.github.com/repos/grafana/grafana/releases/latest'
        azurePortal             = 'https://portal.azure.com'
        aksEEk3s                = 'https://aka.ms/aks-edge/k3s-msi'
        prometheus              = 'https://prometheus-community.github.io/helm-charts'
        vcLibs                  = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        windowsTerminal         = 'https://api.github.com/repos/microsoft/terminal/releases/latest'
        aksEEReleases           = 'https://api.github.com/repos/Azure/AKS-Edge/releases'
        stepCliReleases         = 'https://api.github.com/repos/smallstep/cli/releases'
        mqttuiReleases          = 'https://api.github.com/repos/EdJoPaTo/mqttui/releases'
        mqttExplorerReleases    = 'https://api.github.com/repos/thomasnordquist/MQTT-Explorer/releases/latest'
    }
    # Azure required registered resource providers
    AzureProviders          = @(
        "Microsoft.Kubernetes",
        "Microsoft.KubernetesConfiguration",
        "Microsoft.HybridCompute",
        "Microsoft.GuestConfiguration",
        "Microsoft.HybridConnectivity",
        "Microsoft.Symphony",
        "Microsoft.Bluefin",
        "Microsoft.DeviceRegistry",
        "Microsoft.EventGrid",
        "Microsoft.ExtendedLocation"
    )

    # Az CLI required extensions
    AzCLIExtensions         = @(
        'k8s-extension',
        'k8s-configuration',
        'eventgrid',
        'customlocation',
        'kusto',
        'storage-preview'
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
        'azcopy10',
        'vscode',
        'git',
        '7zip',
        'kubectx',
        'putty.install',
        'kubernetes-helm',
        'mqtt-explorer',
        'gh',
        'k9s',
        'python'
    )

    # Pip packages list
    PipPackagesList     = @(
        'paho-mqtt'
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
        clusterLogSize             = "1024"

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
                'MemoryInMB'   = 16384
                'DataSizeInGB' = 50
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
                ServiceIPRangeSize = 10
            }
            Network             = @{
                NetworkPlugin = ""
                InternetDisabled  = $false
            }
            User                = @{
                AcceptEula = $true
                AcceptOptionalTelemetry = $true
            }
            Machines            = @()
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
}
