# Running AI at the Edge

## Overview

Contoso prides itself on being technology innovators. In the current market, Contoso's leadership recognizes that maintaining their position as leaders in the retail space requires innovation in every aspect of their operations.

To this end, Contoso Supermarket has developed an artificial intelligence (AI) mechanism that empowers them to enhance the customer experience in their stores. By implementing such a mechanism, their objective is to accurately detect the number of people waiting at different checkout lanes and enable proactive actions based on this data.

## Architecture

Contoso has four Kubernetes environments for their application rollout process (Dev, Staging, Canary, and Production), each environment is represented in their GitHub repository as a separate branch to allow developers to develop, test, and ship features and fixes in a controlled manner across each environment.

   ![Screenshot showing the Contoso Supermarket's virtualization stack](./img/ag_aks_clusters.png)

In each cluster, a queue monitoring frontend service is deployed to allow store managers to monitor the checkout queues and leverages the power of AI to detect the number of users in a certain queue so they can take immediate action to enhance the customers' checkout experience.

   ![Screenshot showing the Contoso Supermarket's queue monitoring service](./img/ai_diagram.png)

Contoso's DevOps team has adopted GitOps methodologies which allows them to use Git as the single source of truth for managing infrastructure and application deployments. It involves declarative definitions of infrastructure and application configurations, which are stored in Git repositories. The GitOps pipeline automatically detects any changes made to the repositories and triggers the necessary actions to deploy the changes to the target environments.

One of the main benefits of GitOps is its ability to provide a consistent and auditable deployment process. All changes to the infrastructure and application configurations are tracked and versioned in Git, making it easy to roll back to a previous state if necessary. The declarative nature of GitOps also enables the automation of the deployment process, which reduces the risk of human error and streamlines the entire process.

### GitOps workflow

Contoso has deployed GitOps configurations for all of their services to make it easier for their developers to focus on code and streamline all the code build, test, and deployment activities. Flux v2 is the main driver for Contoso's GitOps workflow by monitoring the Git repository holding all the clusters' configurations and applications code for changes and automatically updating the deployed resources accordingly. This makes it easy for teams to manage their infrastructure as code, using Git as the single source of truth. [GitOps on Azure Arc-enabled Kubernetes](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/hybrid/arc-enabled-kubernetes/eslz-arc-kubernetes-cicd-gitops-disciplines) leverages Flux v2 to provide a unified experience for managing Kubernetes clusters across different environments. This integration allows users to deploy and manage applications in Arc-enabled Kubernetes clusters, while also providing a centralized management plane through Azure Arc. This can simplify the process of managing Kubernetes clusters across different environments and provide greater visibility and control over the entire deployment process.

Before starting to code this new feature, it is useful to take a look at how Contoso's GitHub repository is structured.

- The GitHub repository for Contoso's applications has a branch per environment as follows:
  - _Main_ branch targets the local _Dev_ environment/cluster
  - _Staging_ branch targets the _Staging_ environment/cluster
  - _Canary_ branch targets the _Chicago_ environment/cluster
  - _Production_ branch targets the _Seattle_ environment/cluster

    ![Screenshot showing the GitHub repository branches](./img/repo_branches.png)

- The repository has two main folders to separate the development team applications' code (developer) and the DevOps team operations GitOps configurations (operations).

    ![Screenshot showing the GitHub repository main folder structure](./img/repo_folder_structure.png)

- Within the _developer_ folder there is a folder for each application's source code. This is where Contoso Supermarket's developers develop new features.

    ![Screenshot showing the developer folder structure](./img/repo_developer_structure.png)

- Within the _operations_ folder there is also a folder for each application's GitOps configuration. This is where Contoso Supermarket's DevOps team manages how the applications are deployed to the different environments.

    ![Screenshot showing the operations folder structure](./img/repo_operations_structure.png)

- Each application has a folder for [Helm](https://helm.sh/docs/) _charts_ where the Kubernetes manifests for each application are located and a folder for _releases_ where the Helm Releases for each application and each environment is located. This way the DevOps team can control the promotion of each version of the applications across the GitOps workflow on different environments and also enable/disable features created by the developers as needed.

    ![Screenshot showing the helm folder structure](./img/repo_operations_helm_structure.png)

    ![Screenshot showing the helm releases folder structure](./img/repo_operations_helmreleases_structure.png)

## Store Manager Experience

Contoso leverages their existing CCTV cameras by seamlessly integrating them into the store manager interface. This integration enables Store Managers to take immediate action, such as opening or closing lanes, based on the real-time data provided by the cameras. All data processing occurs locally using an edge device, ensuring compliance with corporate policies and safeguarding data privacy.

The "Managers Control Center" serves as the central hub of this experience. From this interface, store managers can easily monitor the number of people in each lane. The home page consists of two main areas.

To access the "Managers Control Center", select the POS [_env_] Manager option from the _POS_ Bookmarks folder. Each environment will have it's own "Managers Control Center" instance with a different IP.

![POS Bookmar](./img/control-center-menu.png)

- __Heatmap:__ Using the heatmap, the Store Manager can open or close checkout lanes to distribute the traffic of the store, using the Toggles above each lane.

    ![Store Manager Screenshot Heatmap focus](./img/checkout-heatmap.png)

- __Reporting:__ Contoso is interested in improving their store experience by measuring 2 key metrics: Total people in the store, and Shopper Wait Time. This metrics are shown in the Store Manager Control Center as shown below

    ![Store Manager Reporting Pane](./img/reporting.png)

## Live View

These metrics are generated by combining an AI engine that captures inferences from the CCTV cameras with an application running the business logic. To provide visibility into the process of capturing these inferences, the Contoso Dev team has included an option to view the live video feed from one of their cameras.

Contoso has decided to have the "Live View" option enabled by default in the Dev and Staging environments.

![Screenshot of enabled live view button](./img/live-view-button.png)

Live View will be disabled by default in Seattle and Chicago environments as shown in the picture below:

![Screenshot of disabled live view button](./img/disabled-live-view.png)

## DevOps team experience

The Contoso Supermarket's DevOps team has received a request from the _Chicago_ store managers that they need the live view feature enabled in their store as their queues are getting longer throughout peak hours through the day.

- Connect to the Client VM `Ag-VM-Client` using the instructions in the [Deployment Guide](https://github.com/microsoft/azure_arc/blob/jumpstart_ag/docs/azure_jumpstart_ag/contoso_supermarket/deployment/_index.md#connecting-to-the-agora-client-virtual-machine).

- Open VSCode from the desktop shortcut.

    ![Screenshot showing the the VSCode icon on the desktop](./img/open_vscode.png)

- Bring up the VSCode command palette.

    ![Screenshot showing the opening the command palette in VSCode](./img/vscode_command_palette.png)

- Select the option to open a folder in a dev container from the command palette.

    ![Screenshot showing opening a folder in a dev container](./img/vscode_dev_container.png)

- Browse to the cloned repository on the Client VM located at _C:\Ag\AppsRepo\jumpstart-agora-apps_.

    ![Screenshot showing the cloned repository on the client VM](./img/vscode_dev_container_open_folder.png)

- Select the _Ubuntu_ operating system for your dev container.

    ![Screenshot showing the operating system for the dev container](./img/vscode_dev_container_os.png)

    ![Screenshot showing the operating system creation for the dev container](./img/vscode_dev_container_os_create.png)

- No need for any additional features to install, so click _Ok_.

    ![Screenshot showing the additional operating system features to install](./img/vscode_dev_container_os_options.png)

- Click on _Trust folder and continue_, now you can see the cloned repository opened in VSCode, in the _Ubuntu_ dev container.

    ![Screenshot showing the trust folder prompt in VSCode](./img/vscode_dev_container_pos_app.png)

    ![Screenshot showing the cloned repository opened in the dev container](./img/vscode_dev_container_trust_folder.png)

- Click on the GitHub icon in the VSCode toolbar, click on _Manage Unsafe Repositories_ and select the _jumpstart-agora-apps_ repository to whitelist it.

    ![Screenshot showing the trust repository prompt in VSCode](./img/vscode_dev_container_trust_repository.png)

- Switch to the _canary_ branch to enable the "Live View"feature on the _Chicago_ Kubernetes cluster

    ![Screenshot showing switching to the canary branch](./img/vscode_canary_branch.png)

- Navigate to the file _contoso_supermarket/operations/contoso_supermarket/releases/queue-monitoring-frontend/canary/chicago.yaml_. You can see that "Live View" is disabled

    ![Screenshot showing the navbar.html file](./img/vscode_canary_live_view_disabled.png)

- Change the value to _True_ to enable the "Live View" feature

    ![Screenshot showing the navbar.html file](./img/vscode_canary_live_view_enabled.png)

- After a couple of seconds, Flux v2 should detect this new change and you should start seeing pod recreation activity on the _Chicago_ Kubernetes clusters

    ![Screenshot showing pods terminating in the canary cluster](./img/live_view_containers.png)

- After refreshing the store manager view, we can see that the "Live View" feature is enabled and the "Live View" button is not greyed out anymore.

    ![Screenshot showing the live view feature enabled on the browser](./img/edge_live_view_enabled.png)

    ![Screenshot showing the live view feature showing the video feed](./img/edge_canary_pos_manage_live_view.png)

## Next Steps

Use the following guides to explore different use cases of Contoso Supermarket in Jumpstart Agora.

- [PoS](https://placeholder)
- [Freezer Monitor](https://placeholder)
- [CI/CD](https://placeholder)
- [Basic GitOps](https://placeholder)
- [Analytics](https://analytics)
- [Troubleshooting](https://troubleshooting)
