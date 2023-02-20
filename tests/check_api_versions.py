import os
import json
from tabulate import tabulate

import requests

azure_providers_url = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/providers/2019-05-10/swagger.json"

api_versions = {}


def get_api_versions(swagger_url):
    response = requests.get(swagger_url)
    data = response.json()
    resources = data["paths"]
    for resource in resources:
        for operation in resources[resource]:
            if "parameters" in resources[resource][operation]:
                for parameter in resources[resource][operation]["parameters"]:
                    if "$ref" in parameter:
                        ref = parameter["$ref"]
                        if "#/parameters/api-version" in ref:
                            provider_name = resource.split("/")[1]
                            api_version = ref.split("/")[-1]
                            api_versions[provider_name] = api_version


scan_directory = "."

for root, dirs, files in os.walk(scan_directory):
    dirs[:] = [d for d in dirs if d not in [".github", "docs", "img", "social", "tests"]]
    for file in files:
        if file.endswith(".json") or file.endswith(".template") or file.endswith(".bicep"):
            file_path = os.path.join(root, file)
            with open(file_path, "r") as f:
                data = f.read()
                resources = json.loads(data)
                for resource in resources["resources"]:
                    resource_type = resource["type"]
                    if "providers" in resource_type:
                        provider_parts = resource_type.split("/")
                        provider_name = provider_parts[2]
                        if provider_name in api_versions:
                            current_api_version = resource.get("apiVersion")
                            latest_api_version = api_versions[provider_name]
                            if current_api_version != latest_api_version:
                                print(f"Resource: {resource_type} in {file_path} has an outdated API version. Current version is {current_api_version}. Latest version is {latest_api_version}.")
                                api_versions[provider_name] = latest_api_version

table = []
for provider_name, latest_api_version in api_versions.items():
    table.append([provider_name, latest_api_version])

headers = ["Provider Name", "Latest API Version"]

with open("tests/api_report.json", "w") as f:
    f.write(json.dumps(table, indent=4))
    
print(tabulate(table, headers=headers))
