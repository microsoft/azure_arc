@{
    # This is the PowerShell datafile used to provide configuration information for the aio environment. Product keys and password are not encrypted and will be available on host during installation.

    # Directory paths
    aioDirectories           = @{
        aioDir             = "C:\aio"
        aioLogsDir         = "C:\aio\Logs"
        aioPowerShellDir   = "C:\aio\PowerShell"
        aioToolsDir        = "C:\Tools"
        aioTempDir         = "C:\Temp"
        aioConfigMapDir    = "C:\aio\ConfigMaps"
        aioAppsRepo        = "C:\aio\AppsRepo"
        aioDataExplorer    = "C:\aio\DataExplorer"
        aioMonitoringDir   = "C:\aio\Monitoring"
        aioInfluxMountPath = "C:\aio\InfluxDB"
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
        "Microsoft.DeviceRegistry",
        "Microsoft.EventGrid",
        "Microsoft.ExtendedLocation",
        "Microsoft.IoTOperationsOrchestrator",
        "Microsoft.IoTOperationsMQ",
        "Microsoft.IoTOperationsDataProcessor"
    )

    # Az CLI required extensions
    AzCLIExtensions         = @(
        'k8s-extension',
        'k8s-configuration',
        'eventgrid',
        'customlocation',
        'kusto',
        'storage-preview',
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
        'azcopy10',
        'vscode',
        'git',
        '7zip',
        'kubectx',
        'putty.install',
        'kubernetes-helm',
        'mqtt-explorer',
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
                'CpuCount'     = 6
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
    TagValue                = 'Jumpstart_aio'
    ArcServerResourceType   = 'Microsoft.HybridCompute/machines'
    ArcK8sResourceType      = 'Microsoft.Kubernetes/connectedClusters'

    # Microsoft Edge startup settings variables
    EdgeSettingRegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    EdgeSettingValueTrue    = '00000001'
    EdgeSettingValueFalse   = '00000000'
}
