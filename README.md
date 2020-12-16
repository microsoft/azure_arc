# Azure Arc Jumpstart documentation

If you are looking to explore the Jumpstart documentation, please go to the documentation website:

https://azurearcjumpstart.io

This repository contains the markdown files which generate the above website. See below for guidance on running with a local environment to contribute to the docs.

## Want to help and contribute?

Before making your first contribution, make sure to review the [contributing](https://azurearcjumpstart.io/contributing/) section in the docs.

* Found a bug?! Use the [Bug Report](https://github.com/microsoft/azure_arc/issues/new?assignees=&labels=bug&template=bug_report.md&title=) issue template to let us know

* To ask for a scenario or create one yourself use the [Feature Request](https://github.com/microsoft/azure_arc/issues/new?assignees=&labels=&template=feature_request.md&title=) issue template

## Overview

This docs is built using Hugo with the Docsy theme, hosted through Netlify.

## Pre-requisites

* [Hugo/Hugo extended](https://gohugo.io/getting-started/installing)
* [Node.js](https://nodejs.org/en/)

## Local Environment Setup

1. Ensure pre-requisites are installed

2. Clone this repository

    ```shell
    git clone https://github.com/microsoft/azure_arc_jumpstartweb
    ```

3. Go to main directory

    ```shell
    cd ./azure_arc_jumpstartweb
    ```

4. Update submodules:

    ```shell
    git submodule update --init --recursive
    ```

5. Install npm packages:

    ```shell
    npm install
    ```

6. Run in local

    ```shell
    npm run start
    ```
