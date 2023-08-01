---
type: docs
weight: 100
toc_hide: true
---

# Streamlining the Software Delivery Process using CI/CD

## Overview

In today's fast-paced software development industry having a robust and efficient CI/CD (Continuous Integration/Continuous Deployment) pipeline is critical for organizations to maintain a competitive edge and stay ahead of the curve. This is particularly important for organizations like Contoso Supermarket to deliver a seamless shopping experience to its customers. With the increasing adoption of cloud technologies, the need for an efficient CI/CD pipeline has become more pronounced, as it allows Contoso Supermarket to quickly and reliably deploy changes to their applications and infrastructure.

GitHub Actions allows Contoso Supermarket's developers to define workflows to build, test, and deploy their applications directly from their GitHub repositories. With its wide range of pre-built actions and integrations, GitHub Actions makes it easy for developers to implement CI/CD pipelines for Contoso Supermarket's critical applications and services and to ship more features without compromising quality, security, and speed.

Contoso Supermarket's DevOps team has adopted GitOps methodologies which allows them to use Git as the single source of truth for managing infrastructure and application deployments. It involves declarative definitions of infrastructure and application configurations, which are stored in Git repositories. The GitOps pipeline automatically detects any changes made to the repositories and triggers the necessary actions to deploy the changes to the target environments.

One of the main benefits of GitOps is its ability to provide a consistent and auditable deployment process. All changes to the infrastructure and application configurations are tracked and versioned in Git, making it easy to roll back to a previous state if necessary. The declarative nature of GitOps also enables the automation of the deployment process, which reduces the risk of human error and streamlines the entire process.

## Architecture

Contoso has four Kubernetes environments for their application rollout process (Dev, Staging, Canary, and Production), each environment is represented in their GitHub repository as a separate branch to allow developers to develop, test, and ship features and fixes in a controlled manner across each environment.

   ![Screenshot showing the Contoso Supermarket's virtualization stack](./img/ag_aks_clusters.png)

### Development workflow

- The inner loop is where developers start to make changes and test locally on the local _Dev_ cluster and then use the CI/CD workflow.
- Changes are then automatically pushed to the _Staging_ environment for testing and validation.
- Once the changes are approved by a release manager, the changes are pushed to the outer loop to the _Canary_ environment which is where the actual cluster in the Chicago store is deployed.
- After this release has been cleared for successful testing and operation in the Chicago environment, the release manager will approve the changes for production
- The CI/CD workflow will run final tests and deploy this release to the _Production_ environment in the Seattle store

    ![Screenshot showing the developer workflow](./img/developer_workflow.png)

### CI/CD workflow

Contoso has implemented a CI/CD workflow to make it easier for their developers to focus on code and streamline all the code build, test, and deployment activities. Before starting to code this new feature, it is useful to take a look at how Contoso's GitHub repository is structured and how their CI/CD workflow is configured.

   ![Screenshot showing the CI/CD workflow](./img/ci_cd_workflow.png)

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

- Each application has a folder for [Helm](https://helm.sh/docs/) _charts_ where the Kubernetes manifests for each application are located and a folder for _releases_ where the Helm Releases for each application and each environment is located. This way the DevOps team can control the promotion of each version of the applications across the CI/CD workflow on different environments and also enable/disable features created by the developers as needed.

    ![Screenshot showing the helm folder structure](./img/repo_operations_helm_structure.png)

    ![Screenshot showing the helm releases folder structure](./img/repo_operations_helmreleases_structure.png)

- Helm Releases control the promotion of the PoS application images from one environment to the other using the image tag as a Helm value.

    ![Screenshot showing the helm release values](./img/github_helm_release_example.png)

- The repository has the following GitHub actions that build the Contoso Supermarket's CI/CD workflow
  - __Promote-to-staging:__ This workflow is triggered once a pull request targeting the code of the PoS application is merged. It will build the new images based on code changes, increment the image tag, run unit tests, and update the PoS application on the _Staging_ environment.
  - __Promote-to-canary:__ This workflow is triggered once the staging cluster has a healthy deployment of the PoS application, this is done once the Flux v2 operator captures the new commit in the staging branch and generates a notification that the deployment is ready. It will build the new canary image, run integration tests, and submits a PR to update the image tag on the _canary_ Helm release.
  - __Promote-to-production:__ This workflow is triggered once the canary cluster has a healthy deployment of the PoS application, this is done once the Flux v2 operator captures the new commit in the canary branch and generates a notification that the deployment is ready. It will build the new production image, run final tests, and submits a PR to update the image tag on the _production_ Helm release.

    ![Screenshot showing all the GitHub actions](./img/github_actions_list.png)

## Developer experience

As a Contoso Supermarket developer, you are assigned a new task to implement a new feature to the Point of Sale (PoS) application where customers have provided feedback that the checkout process is not optimal. As products get added to the cart there is no way to see how many items are in the cart and the total cost.

The development process will start from the local _dev_ cluster, where as a developer, you will write some code to add this new functionality using VSCode's dev containers feature.

   ![Screenshot showing the PoS application before the checkout feature](./img/pos_before_checkout_feature.png)

- Connect to the Client VM _Ag-VM-Client_ using the instructions in the [Deployment Guide](https://github.com/microsoft/azure_arc/blob/jumpstart_ag/docs/azure_jumpstart_ag/contoso_supermarket/deployment/_index.md#connecting-to-the-agora-client-virtual-machine).

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

    ![Screenshot showing the jammy ubuntu flavor for the dev container](./img/vscode_dev_container_ubuntu_flavor.png)

- No need for any additional features to install, so click _Ok_.

    ![Screenshot showing the additional operating system features to install](./img/vscode_dev_container_os_options.png)

- Click on _Trust folder and continue_, now you can see the cloned repository opened in VSCode, in the _Ubuntu_ dev container.

    ![Screenshot showing the trust folder prompt in VSCode](./img/vscode_dev_container_trust_folder.png)

    ![Screenshot showing the cloned repository opened in the dev container](./img/vscode_dev_container_pos_app.png)

- Click on the GitHub icon in the VSCode toolbar, click on _Manage Unsafe Repositories_ and select the _jumpstart-agora-apps_ repository to add it to the allow list.

    ![Screenshot showing the trust repository prompt in VSCode](./img/vscode_dev_container_trust_repository.png)

- To add this new checkout functionality, you will have to create a new feature branch and edit the _navbar.html_ file in the _pos_ application.
- Create a new branch from VSCode called _feature-checkout-cart_ and publish this branch to the remote repository.

    ![Screenshot showing creating a new branch](./img/vscode_dev_new_feature_branch.png)

    ![Screenshot showing publishing the new branch](./img/vscode_dev_publish_branch.png)

- Navigate to the file _contoso_supermarket/developer/PoS/src/templates/navbar.html_.

    ![Screenshot showing the navbar.html file](./img/vscode_dev_navbar_file.png)

- To simulate adding this new functionality, uncomment the commented section in the _navbar.html_ file and save your changes.

    ![Screenshot showing the commented section of the navbar.html file](./img/vscode_dev_navbar_file_uncommented.png)

- You should see a new change visible in the GitHub pane (if you don't see any changes, click refresh).

    ![Screenshot showing the added changes in the repository](./img/vscode_dev_add_changes.png)

- Add a commit message and click Commit, for example: "Adding checkout functionality" and push your code.

    ![Screenshot showing the added a commit message](./img/vscode_dev_commit_message.png)

    ![Screenshot showing the added pushing code to remote](./img/vscode_dev_push_changes.png)

- After the code has been pushed, navigate to your GitHub fork of the _jumpstart-agora-apps_, you will see a notification about changes in the _feature-checkout-cart_branch. Click_Compare & Pull request_.

    ![Screenshot showing new changes message](./img/github_create_pr_dev.png)

- Change the base repository to your fork, create the pull request, merge the pull request and delete the feature branch after the merge.

    ![Screenshot showing changing base branch and submitting the pull request](./img/github_change_remote.png)

    ![Screenshot showing changing base branch and submitting the pull request](./img/github_change_remote_updated.png)

    ![Screenshot showing merging the pull request](./img/github_merge_dev.png)

    ![Screenshot showing deleting the feature](./img/github_delete_branch_dev.png)

- A GitHub action is automatically triggered to build a new Docker image of the PoS application and deploy this new image to the Staging cluster.

    ![Screenshot showing the staging GitHub Action](./img/github_actions_dev.png)

- On the Client VM, open Windows Terminal, switch to the _Staging_ Kubernetes cluster and monitor the _contosopos_ pods. You should see the pods are recreated as the Flux v2 extension picks up the changes you made on the _Dev_ environment and deploys it to the _Staging_ cluster.

  ```azurecli
  kubectx staging
  kubectl get pods -n contoso-supermarket
  ```

    ![Screenshot showing the PoS application pods](./img/repo_staging_pods_gitops.png)

- Open the Microsoft Edge browser, and navigate to the _POS Staging - Customer_ bookmark.

    ![Screenshot showing the staging customer bookmark in edge](./img/edge_staging_customer_portal.png)

- The new checkout feature is now deployed and visible on the _Staging_ environment.

    ![Screenshot showing the new checkout feature in the staging environment](./img/pos_after_checkout_feature.png)

    > __NOTE: In some cases you may need to force a refresh of your browser's cache to see the updated feature. This can be done by pressing Ctrl-F5 to force the cache to clear and reload the page.__

- Once the PoS application is healthy on the _Staging_ cluster, a pull request is created automatically to update the _Canary_ environment with the new PoS application image.

    ![Screenshot showing the canary Pull request](./img/github_canary_pr.png)

- Merge the new pull request to deploy this new checkout feature to the _Canary_ environment (Chicago store) and delete the branch.

    ![Screenshot showing merging canary Pull request](./img/github_canary_pr_merge.png)

    ![Screenshot showing deleting the canary Pull request branch](./img/github_canary_pr_delete_branch.png)

- Once the merge is complete, GitOps configuration will pick up the new changes and deploy the new image to the _Canary_ cluster.

    ![Screenshot showing canary customer view before update](./img/edge_canary_before_update.png)

- On the Client VM, open Windows Terminal, switch to the _Chicago_ Kubernetes cluster and monitor the _contosopos_ pods. You should see the pods are recreated as the Flux v2 extension picks up the changes you made on the _Staging_ environment and deploys it to the _Canary_ cluster.

  ```azurecli
  kubectx chicago
  kubectl get pods -n contoso-supermarket
  ```

    ![Screenshot showing canary customer view before update](./img/repo_canary_pods_gitops.png)

    ![Screenshot showing canary customer view after update](./img/edge_canary_after_update.png)

- Once the PoS application is healthy on the _Canary_ cluster, a pull request is created automatically to update the _Production_ environment with the new PoS application image.

    ![Screenshot showing the production Pull request](./img/github_production_pr.png)

- Merge the new pull request to deploy this new checkout feature to the _Production_ environment (Seattle store) and delete the branch.

    ![Screenshot showing merging production Pull request](./img/github_production_pr_merge.png)

    ![Screenshot showing deleting the production Pull request branch](./img/github_production_pr_delete_branch.png)

- Once the merge is complete, GitOps configuration will pick up the new changes and deploy the new image to the _Production_ cluster.

    ![Screenshot showing production customer view before update](./img/edge_production_before_update.png)

- On the Client VM, open Windows Terminal, switch to the _Seattle_ Kubernetes cluster and monitor the _contosopos_ pods. You should see the pods are recreated as the Flux v2 extension picks up the changes you made on the _Staging_ environment and deploys it to the _Canary_ cluster.

     ```azurecli
     kubectx seattle
     kubectl get pods -n contoso-supermarket
     ```

    ![Screenshot showing production customer view before update](./img/repo_production_pods_gitops.png)

    ![Screenshot showing production customer view after update](./img/edge_production_after_update.png)

## Next steps

It is now time to move on to the next Contoso Supermarket scenario and learn how to experiment with [infrastructure observability for Kubernetes and Arc-enabled Kubernetes](../k8s_infra_observability/_index.md).
