import os
import json
import requests

# Function to get the latest published Azure API version for a resource type
def get_latest_api_version(resource_type):
    url = f"https://management.azure.com/providers/Microsoft.{resource_type}/?api-version=2022-02-01"
    response = requests.get(url)
    response_json = json.loads(response.content)
    return response_json["resourceTypes"][0]["apiVersions"][0]

# Define the directory to scan
dir_path = "/path/to/your/directory"

# List all the files in the directory
files = os.listdir(dir_path)

# Initialize a dictionary to store the API versions
api_versions = {}

# Loop through each file and extract the API version
for file in files:
    if file.endswith((".json", ".bicep", ".tf")):
        with open(os.path.join(dir_path, file), "r") as f:
            template = json.load(f)
            if "apiVersion" in template:
                api_version = template["apiVersion"]
                if api_version not in api_versions:
                    api_versions[api_version] = []
                api_versions[api_version].append(file.split("/")[-1])
            elif "azurerm" in template:
                modules = template["azurerm"]["modules"]
                for module in modules:
                    if "version" in module:
                        api_version = module["version"]
                        if api_version not in api_versions:
                            api_versions[api_version] = []
                        api_versions[api_version].append(file.split("/")[-1])

# Get the latest published API versions for each resource type
latest_api_versions = {}
for resource_type in api_versions.keys():
    latest_api_versions[resource_type] = get_latest_api_version(resource_type)

# Generate the report
report = ""
for api_version, files in api_versions.items():
    if api_version not in latest_api_versions.values():
        report += f"\nAPI version {api_version} is out of date for the following files: {', '.join(files)}"
print(report)
