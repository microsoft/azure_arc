---
type: docs
weight: 100
toc_hide: true
---

# Streamlining the Software Delivery Process using CI/CD

## Overview

In today's fast-paced software development industry, having a robust and efficient CI/CD (Continuous Integration/Continuous Deployment) pipeline is critical for organizations to maintain a competitive edge and stay ahead of the curve. This is particularly important for organizations like Contoso Supermarket to deliver a seamless shopping experience to its customers. With the increasing adoption of cloud technologies, the need for an efficient CI/CD pipeline has become more pronounced, as it allows Contoso Supermarket to quickly and reliably deploy changes to their applications and infrastructure.

GitHub Actions allows Contoso Supermarket's developers to define workflows to build, test, and deploy their applications directly from their GitHub repositories. With its wide range of pre-built actions and integrations, GitHub Actions makes it easy for developers to implement CI/CD pipelines for Contoso Supermarket's critical applications and services and to ship more features without compromising quality, security and speed.

## Architecture

Contoso Supermarket has three environments for their development process (Dev, Staging, Canary and Production), each environment is represented in their GitHub repository as a seperate branch to allow developers to develop, test and ship features and fixes in a controlled manner across each environment.

### Development workflow

- The inner loop is where developers start to make changes and test locally on the local _Dev_ cluster and then using the CI/CD workflow
- Changes are then automatically pushed to the Staging environment for testing and validation.
- Once the changes are approved by a release manager, the changes start to get pushed to the outer loop to the canary environment which is an actual cluster in the Chicago's store
- After this release has been cleared for successful testing and operation in the Chicago's environment, the release manager will approve the changes for production
- The CI/CD workflow will run final tests and deploy this release to the production environment in the Seattle's store

  ![Screenshot showing the developer workflow](./img/developer_workflow.png)

### CI/CD workflow

Contoso Supermarket has implemented a CI/CD workflow to make it easier for developers to focus on code and streamline all the code build, test and deployment activities. Before starting to code this new feature, its useful to take take a look on how the Contoso Supermarket's GitHub repository is structured and how CI/CD workflow is configured.

  ![Screenshot showing the CI/CD workflow](./img/ci_cd_workflow.png)

- The GitHub repository for Contoso Supermarket has a branch per environment as follows:
  - Main branch targets the local _Dev_ environment/cluster
  - Staging branch targets the _Staging_ environment/cluster
  - Canary branch targets the _Chicago_ environment/cluster
  - Production branch targets the _Seattle_ environment/cluster

  ![Screenshot showing the GitHub repository branches](./img/repo_branches.png)

- The repository has two main folders to seperate the development team applications' code (developer) and the DevOps team operations GitOps configurations (operations)

  ![Screenshot showing the GitHub repository main folder structure](./img/repo_folder_structure.png)

- Within the _developer_ folder, there is a folder for each application's source code. This is where Contoso Supermarket's developers develop new features

  ![Screenshot showing the developer folder structure](./img/repo_developer_structure.png)

- Within the _operations_ folder, there is also folder for each application's GitOps configuration. This is where Contoso Supermarket's DevOps team manage how the applications are deployed to the different environments

  ![Screenshot showing the operations folder structure](./img/repo_operations_structure.png)

- Each application has folder for _charts_ where the Kubernetes mainfests for each application is located and a folder for _releases_ where the helm releases for each application and each environment is located. This way the DevOps team can control the promotion of each version of the applications across the CI/CD workflow on different environments and also enable/disable features created by the developers as needed

  ![Screenshot showing the helm folder structure](./img/repo_operations_helm_structure.png)

  ![Screenshot showing the helm releases folder structure](./img/repo_operations_helmreleases_structure.png)

## Developer experience

As a Contoso Supermarket developer, you are assigned a new task to implement a new feature to the Point of Sale (PoS) application where customers have provided feedback that the checkout process is not optimal. As they are adding products to their cart, there is no way for them to see how many items are in the cart and how much is the total cost at this time of their buying process.

The development process will start from the local _dev_ cluster, where as a developer, you will write some code to add this new functionality using VSCode's dev containers feature.

  ![Screenshot showing the pos application before the checkout feature](./img/pos_before_checkout_feature.png)

- Connect to the Client VM `Ag-VM-Client` using the instructions in the [Deployment Guide](https://github.com/microsoft/azure_arc/blob/jumpstart_ag/docs/azure_jumpstart_ag/contoso_supermarket/deployment/_index.md#connecting-to-the-agora-client-virtual-machine).

- Open VSCode from the desktop shortcut

  ![Screenshot showing the the VSCode icon on the desktop](./img/open_vscode.png)

- Bring up the VSCode command palette

  ![Screenshot showing the opening the command palette in VSCode](./img/vscode_command_palette.png)

- Select the option to open a folder in a dev container from the command palette

  ![Screenshot showing opening a folder in a dev container](./img/vscode_dev_container.png)

- Browse to the cloned repository on the Client VM located at _C:\Ag\AppsRepo\jumpstart-agora-apps_

  ![Screenshot showing the cloned repository on the client VM](./img/vscode_dev_container_open_folder.png)

- Select the _Ubuntu_ operating system for your dev container

  ![Screenshot showing the operating system for the dev container](./img/vscode_dev_container_os.png)

  ![Screenshot showing the operating system creation for the dev container](./img/vscode_dev_container_os_create.png)

- No need for any additional features to install, so click _Ok_

  ![Screenshot showing the additional operating system features to install](./img/vscode_dev_container_os_options.png)

- Click on _Trust folder and continue_, now you can see the cloned repository opened in VSCode, in te _Ubuntu_ dev container

  ![Screenshot showing the trust folder prompt in VSCode](./img/vscode_dev_container_pos_app.png)

  ![Screenshot showing the cloned repository opened in the dev container](./img/vscode_dev_container_trust_folder.png)

- Click on the GitHub icon in the VSCode toolbar, click on _Manage Unsafe Repositories_ and select the _jumpstart-agora-apps_ repository to whitelist it

  ![Screenshot showing the trust repository prompt in VSCode](./img/vscode_dev_container_trust_repository.png)

- To add this new checkout functionality, you will have to create a new feature branch and edit the _navbar.html_ file in the _pos_ application.
- Create a new branch from VSCode called _feature-checkout-cart_ and publish this branch to the remote repository

  ![Screenshot showing creating a new branch](./img/vscode_dev_new_feature_branch.png)

  ![Screenshot showing publishing the new branch](./img/vscode_dev_publish_branch.png)

- Navigate to the file _contoso_supermarket/developer/pos/src/templates/navbar.html_

  ![Screenshot showing the navbar.html file](./img/vscode_dev_navbar_file.png)

- To simulate adding this new functionality, uncomment the commented section in the _navbar.html_ file and save your changes

  ![Screenshot showing the commented section of the navbar.html file](./img/vscode_dev_navbar_file_uncommented.png)

- You should see a new change visible in the GitHub pane (if you don't see any changes, click refresh)

  ![Screenshot showing the added changes in the repository](./img/vscode_dev_add_changes.png)

- Add a commit message and click Commit, for example: "Adding checkout functionality" and push your code

  ![Screenshot showing the added a commit message](./img/vscode_dev_commit_message.png)

  ![Screenshot showing the added pushing code to remote](./img/vscode_dev_push_changes.png)

- After the code has been pushed, navigate to your GitHub fork of the _jumpstart-agora-apps_, you will see a notification about changes in the _feature-checkout-cart_branch. Click _Compare & Pull request_

  ![Screenshot showing new changes message](./img/github_create_pr_dev.png)

- Change the base repository to your fork, create the pull request, merge the pull request and delete the feature branch after the merge

  ![Screenshot showing changing base branch and submitting the pull request](./img/github_change_remote.png)

  ![Screenshot showing changing base branch and submitting the pull request](./img/github_change_remote_updated.png)

  ![Screenshot showing merging the pull request](./img/github_merge_dev.png)

  ![Screenshot showing deleting the feature](./img/github_delete_branch_dev.png)

- A GitHub action is automatically triggered to build new Docker image of the Pos application and deploy this new image to the Staging cluster

  ![Screenshot showing the staging GitHub Action](./img/github_github_actions_dev.png)
