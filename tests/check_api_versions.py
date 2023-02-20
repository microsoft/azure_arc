from github import Github
import requests
import json
from tabulate import tabulate

# Access the public repository using an unauthenticated client
g = Github()

# Get the repository object
repo = g.get_repo("microsoft/azure_arc")

# Define the file extensions to be searched
file_extensions = [".json", ".yml", ".yaml", ".bicep", ".tf", ".hcl"]

# Define the resource type patterns
resource_type_patterns = ["Microsoft.", "azure"]

# Define the exclude folders
exclude_folders = [".github", "docs", "img", "social", "tests"]

# Define the Azure API versions endpoint
azure_api_versions_url = "https://management.azure.com/providers?api-version=2021-04-01"

# Get the latest Azure API versions
latest_api_versions = {}
response = requests.get(azure_api_versions_url)
if response.status_code == 200:
    response_json = response.json()
    for provider in response_json["value"]:
        for resource_type in provider["resourceTypes"]:
            latest_api_versions[resource_type["resourceType"]] = resource_type["apiVersions"][-1]

# Initialize the report
report = {
    "repository": repo.full_name,
    "outdated_api_versions": [],
    "resource_types_not_found": []
}

# Iterate through the files in the repository
for content in repo.get_contents(""):
    if content.type == "dir" and content.name not in exclude_folders:
        for inner_content in repo.get_contents(content.path):
            if inner_content.type == "dir" and inner_content.name not in exclude_folders:
                for file in repo.get_contents(inner_content.path):
                    if file.path.endswith(tuple(file_extensions)):
                        # Read the file content
                        file_content = file.decoded_content.decode("utf-8")
                        # Find the resource type and API version
                        for pattern in resource_type_patterns:
                            if pattern in file_content:
                                resource_type = file_content[file_content.index(pattern):].split(".")[0]
                                api_version = file_content[file_content.index("apiVersion")+12:].split("\n")[0].strip().replace("'", "").replace('"', '')
                                if resource_type in latest_api_versions and api_version != latest_api_versions[resource_type]:
                                    report["outdated_api_versions"].append({
                                        "path": file.path,
                                        "resource_type": resource_type,
                                        "outdated_api_version": api_version,
                                        "latest_api_version": latest_api_versions[resource_type]
                                    })
                                elif resource_type not in latest_api_versions:
                                    report["resource_types_not_found"].append(resource_type)

# Generate the report table
outdated_api_versions_table = []
for outdated_api_version in report["outdated_api_versions"]:
    outdated_api_versions_table.append([
        outdated_api_version["path"],
        outdated_api_version["resource_type"],
        outdated_api_version["outdated_api_version"],
        outdated_api_version["latest_api_version"]
    ])
resource_types_not_found_table = []
for resource_type_not_found in report["resource_types_not_found"]:
    resource_types_not_found_table.append([
        resource_type_not_found
    ])
headers = ["File Path", "Resource Type", "Outdated API Version", "Latest API Version"]
outdated_api_versions_table_str = tabulate(outdated_api_versions_table, headers=headers, tablefmt="grid")
headers = ["Resource Type"]
resource_types_not_found_table_str = tabulate(resource_types_not_found_table, headers=headers, tablefmt="grid")

# Write the report to a file
with open("report.json", "w") as f:
    f.write("Repository: {}\n\n".format(report["repository"]))
