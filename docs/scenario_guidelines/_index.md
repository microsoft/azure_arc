---
type: docs
title: "Scenario Write-up Guidelines"
linkTitle: "Scenario Write-up Guidelines"
weight: 5
---

# Jumpstart Scenario Write-up Guidelines

Thank you for considering writing a Jumpstart scenario, we appreciate it, a lot!

The scenarios published as part of the Jumpstart project are high-quality documents and as such we want you to be able to have all needed guidelines to create one yourself while meeting the project standards and publishing requirements.

In this document, our goal is to provide you with as many details as possible for you to be efficient and successful and as a result, producing an awesome Jumpstart scenario. Our intent here is to give you pointers and tools to achieve just that.

> **IMPORTANT: If you are only getting started with contributing Jumpstart scenarios, it is highly recommended you will review the raw code for existing scenarios. These will help you understand how an approved scenario should look like and will represent all the guidelines provided**

## Code reviews

The Jumpstart project is a mix of various automation, code styles, and high-quality documentation and requires development effort.

Before a scenario is getting published, it will go through a code review process by one of the project maintainers. We want your scenario to be successful and widely adopted and to meet the highest standards possible and we are here to help get there!

## Pull requests and issues

Rather you are working on a new scenario or updating an existing one, a scenario should be submitted with a dedicated pull request and an issue to make the review process easy and clean.

* New scenario

    For new scenarios, please also create a new issue using the ["Feature request" template](https://github.com/microsoft/azure_arc/issues/new?assignees=&labels=&template=feature_request.md&title=). If needed, multiple examples can be found under the [Jumpstart project GitHub repository](https://github.com/microsoft/azure_arc/projects/1).

    ![Screenshot of "Feature request" template](./01.png)

* Existing scenario

    For existing scenarios, please also create a new issue using the ["Bug report" template](https://github.com/microsoft/azure_arc/issues/new?assignees=&labels=bug&template=bug_report.md&title=).

    ![Screenshot of "Bug report" template](./02.png)

* As always, we are here for you. In your scenario "Feature request" issue, tag one of the maintainers and we will answer any question you may have.

## Folder Structure

The Azure Arc Jumpstart repository follows a specific folder structure that you should get familiar with before creating a new scenario.

* Automations, scripts, templates, json files, etc. should be placed under each Azure Arc pillar that corresponds to each scenario.
* The guide for the scenario should be under docs and follow a similar structure.

![Screenshot of folder structure](./03.png)

## Indexing

The Azure Arc Jumpstart website is using [HUGO](https://gohugo.io/) as its web framework alongside [Docsy](https://www.docsy.dev/) as its theme of choice.

* Scenarios must be created in its respected "docs" folder in the project GitHub repository and with the "_index.md_" filename for it to get published.

    ![Screenshot of index file location](./04.png)

* Both the "_title_" and the "_linkTitle_" must be the same.

    ![Screenshot of matching link and linkTitle](./05.png)

* The "_Weight_" field number represents the location of the scenario comparing to other scenarios on the same page on the website.

    ![Screenshot of weight numbering](./06.png)

    ![Screenshot of weight numbering](./07.png)

* As always, if you are not sure and you have questions about this section, we recommend looking at other published scenarios and/or reaching out to one of the maintainers.

## Description

All Jumpstart scenarios start with an overview of what the outcome will be after you run the automation. This description should also mention the starting point for the automation, for example for "Unified Operations" (day-2) scenarios you may need an already deployed server or Kubernetes cluster that is onboarded onto Azure Arc, you should also include pointers to scenarios that would allow you to get to that starting point.

## Prerequisites

Every Jumpstart scenario should have a "Prerequisites" section as the first section. Below you can find guidelines on what to consider for this section.

* The first rule of thumb is to know what should be considered as a prerequisite and what can be automated. Generally speaking, if a prerequisite can be automated, it should be incorporated as part of the overall automation flow of the scenario.

* We would love for you to use good judgment and if the scenario's reviewer will find that a certain prerequisite should be automated he will point that out as part of the pull request code review.

* As mentioned at the beginning of this guidelines readme, to avoid a situation where you will need to refactor code or make unforced changes, it is highly recommended for you to use existing scenarios as a reference and work from there.

## Markdown linting and style

All the scenarios and README files follow standard markdown and linting rules. As a general recommendation, we use [Visual Studio Code](https://code.visualstudio.com/) (VSCode) as it provides a rich IDE experience with support for extensions.

Before submitting a PR for a new/updated scenario, make sure to perform markdown linting to avoid errors and typos. If you are using VSCode, we recommend installing the [_markdownlint_ extension] as it provides an easy way of performing an efficient MD lint.

![Screenshot of the markdownlint extension](./08.png)

Below you can find an example of common markdown lint issues that will be presented to you as you are writing your scenario and should be fixed. [Here](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint), you can find detailed explanations on the markdown rules highlighted by the extension and how to fix a violation of these rules.

![Screenshot of the markdown lint errors](./09.png)

## Screenshots

Quality, accurate and clean screenshots are critical when it comes to providing a great Jumpstart scenario and reader experience. In this section, you will find examples and guidelines on screenshots standards.

### Format, location and file ordering

* Screenshots should be saved in either a _png_ or _jpg_ format.

* Images must include an accurate description.

* As you are adding screenshots to your scenario, keep them in a serial order right order as this helps the PR reviewer.

    ![Screenshot of a wrong screenshots order](./10.png)

    ![Screenshot of a correct screenshots order](./11.png)

* Image files must be located alongside the scenario _index.md_ file.

    ![Screenshot of a correct screenshots structure](./12.png)

### Boxes, arrows and step numbers

* Either highlighting boxes and/or arrows should be created in a non-freeform fashion. Choose color and line width that make sense so it will be embedded nicely in the screenshot.

    ![Screenshot of a wrong highlighting and arrow](./13.png)

    ![Screenshot of a correct highlighting and arrow](./14.png)

* When creating step numbers, make sure these are positioned correctly and visible to the reader.

    ![Screenshot of wrong step numbers positioning and color](./15.png)

    ![Screenshot of correct step numbers positioning and color](./16.png)

* Be aware of sensitive information on your screenshots and be sure to blur it out: subscription ID, passwords, service principals, etc.

## Code blocks and commands

Jumpstart scenarios include code blocks and commands and as such, for it to meet markdown rules and scenario standards, each code block and command must use the correct markdown language highlighter.

As you can see in the below examples, each block is represented differently, depends on the scenario.

* shell + json

    ![Screenshot of a shell+json code block format raw code](./17.png)

    ![Screenshot of shell+json code block format in the website](./18.png)

* PowerShell

    ![Screenshot of a shell+json code block format raw code](./19.png)

    ![Screenshot of shell+json code block format in the website](./20.png)

## Positioning and alignments

### Image positioning

Images should be positionally aligned with its respective bulletining or header. This helps with readability and creates a cleaner look. Below is an example of how such alignment looks like in the code and on the website.

![Screenshot of a correct image positioning in the website](./21.png)

![Screenshot of a correct image positioning in the code](./22.png)

### Code block positioning

Code blocks should be positionally aligned with its respective bulletining or header. This helps with readability and creates a cleaner look. Below is an example of how such alignment looks like on the website.

![Screenshot of a wrong code block positioning](./23.png)

![Screenshot of a correct code block positioning](./24.png)

## Credentials, secrets and passwords

No need to mention how important secrets and passwords are. As you are writing your code and the document for your scenario, be very cognizant of what you are committing.

Rather it's a credential that should be included or a secret/password as part of a terminal out, make sure these are mask from the reader.

![Screenshot of unwanted credentials files](./25.png)

![Screenshot of masked secrets](./26.png)

## Notes, disclaimers and highlighted text

There are many ways for you to emphasize a specific text in your scenario README file.

1. To create a note or a disclaimer, below you can find a couple of examples of the format we have been using and how the result would look like on the Jumpstart website.

    ![Screenshot of Note format raw code](./27.png)

    ![Screenshot of Note format in the website](./28.png)

    ![Screenshot of Disclaimer format raw code](./29.png)

    ![Screenshot of Disclaimer format in the website](./30.png)

2. When you need to either bold or italic a text, use the below markdown characters.

    ![Screenshot of bold text raw code](./31.png)

    ![Screenshot of bold text in the website](./32.png)

    ![Screenshot of italic text raw code](./33.png)

    ![Screenshot of italic text in the website](./34.png)

## Naming convention and branding

The Jumpstart scenarios include many tech terms, brand names, and various naming conventions. For example, how a company name, a product, or a feature are written down is important.

The project maintainers are keeping the naming convention list which can be found [here](https://github.com/microsoft/azure_arc/tree/main/docs/scenario_guidelines/naming.md).

## Examples

Examples of how a result of output should look like are very useful and contribute to the overall confidante of the reader as well can significantly reduce potential user errors.

Rather if it's in an example code block, a command, or a screenshot, wherever it make sense, include an example of how something should look like.

[Here](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_k8s/gke/gke_terraform/#deployment) you can find an example of an example :-)

## File trails

Before submitting your scenario PR, make sure to not include unwanted files such as logs, credentials, state files, scripts testing files, etc. If it's not part of the scenario, it shouldn't be included.

![Screenshot of unwanted file trails](./35.png)

## Links

Every scenario includes URLs, either to an external or internal source.

* When you want to point the reader to another Jumpstart scenario, make sure you are using the Jumpstart website URL for it, meaning _azurearcjumpstart.io/other-scenario_ and not the GitHub repository _index.md_ file. You want to provide an experience that does not force the user to go outside the website.

    ![Screenshot of Jumpstart links in the website](./36.png)

    ![Screenshot of Jumpstart links in the code](./37.png)

* When pointing to a script or various files, use the GitHub repository URL.

    ![Screenshot of script link in the website](./38.png)

    ![Screenshot of script link in the code](./39.png)

## Automation flows explanation

Incorporating an explanation on how you designed the automation(s) in your scenario is key and helps the reader understand the "how" and the overall success of the scenario.

* Generally speaking, it makes sense for each scenario to have an "Automation Flow" section right after the "Prerequisites" section. That way, the reader can get a sense of what is happening "behind the scenes".

* Automation flow section should be accurate and comprehensive but also not too long. Bullet points explaining the flow are ok.

* Automation flow sections follow specific language and format, there are multiple examples for Automation flow in several scenarios. You can either [take a look at this example](https://azurearcjumpstart.io/azure_arc_jumpstart/azure_arc_data/kubeadm/kubeadm_dc_vanilla_arm_template/#automation-flow) or search for "Automation Flow" in the Jumpstart homepage.

    ![Screenshot of searching for Automation Flow](./40.png)
