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

As a Contoso Supermarket developer, you are assigned a new task to implement a new feature to the Point of Sale (PoS) application where customers have provided feedback that the checkout process is not optimal. As they are adding products to their cart, there is no way for them to see how many items are in the cart and how much is the total cost at this time of their buying process.

  ![Screenshot showing the pos application before the checkout feature](./img/pos_before_checkout_feature.png)

Contoso Supermarket has implemented a CI/CD workflow to make it easier for developers to focus on code and streamline all the code build, test and deployment activities. Before starting to code this new feature, its useful to take take a look on how the Contoso Supermarket's GitHub repository is structured and how CI/CD workflow is configured.



  ![Screenshot showing the CI/CD workflow](./img/ci_cd_workflow.png)

