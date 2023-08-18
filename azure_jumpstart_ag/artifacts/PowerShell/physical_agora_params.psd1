@{
    AgDirectories = @{
        AgLogsDir = "C:\Logs"
    }

    AzCLIExtensions = @("extension1", "extension2")

    PowerShellModules = @("module1", "module2")

    AzureProviders = @("provider1", "provider2")

    AppConfig = @{
        App1 = @{
            Order = 1
            GitOpsConfigName = "app1-config"
            Namespace = "app1-namespace"
            KustomizationName = "app1-kustomization"
            KustomizationPath = "path/to/app1/kustomization"
            ConfigMaps = @{
                ConfigMap1 = @{
                    RepoPath = "path/to/repo1/config"
                }
            }
        }
        # Add more app configurations here
    }

    SiteConfig = @{
        Site1 = @{
            FriendlyName = "Site1"
            ArcClusterName = "Cluster1"
            Branch = "main"
            Type = "AKS"
            IoTDevices = @("device1", "device2")
        }
        # Add more site configurations here
    }
}
