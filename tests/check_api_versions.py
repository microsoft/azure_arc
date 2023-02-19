import os
import re
import requests

# Define the excluded folders
excluded_folders = [".github", "docs", "img", "social", "tests"]

# Define the regular expression pattern to match Azure API versions
api_version_pattern = re.compile(r"apiVersion\s*=\s*['\"](.*?)['\"]", re.IGNORECASE)

# Define the Azure API endpoint to get the latest API versions
api_endpoint = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/management"

# Define the output file name for the API report
report_file = "tests/api_report.txt"

# Get the latest API versions from the Azure API endpoint
api_endpoint_url = f"{api_endpoint}/readme.md"
api_readme = requests.get(api_endpoint_url).text
latest_api_versions = api_version_pattern.findall(api_readme)

def find_files(root_dir):
    file_list = []
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith((".json", ".bicep", ".tf", ".hcl")) and not any(excluded_folder in root for excluded_folder in excluded_folders):
                file_list.append(os.path.join(root, file))
    return file_list

def get_file_api_versions(file_path):
    with open(file_path, "r") as f:
        file_contents = f.read()
        api_versions = api_version_pattern.findall(file_contents)
    return api_versions

def write_api_report(api_report):
    with open(report_file, "w") as f:
        f.write(api_report)

def generate_api_report():
    repo_files = find_files(".")
    repo_api_versions = set()
    api_report = "Azure API Report\n\n"
    api_report += f"Latest API versions: {latest_api_versions}\n\n"
    api_report += f"{'-'*100}\n"
    api_report += f"| {'API Version':20} | {'Azure Resource Type':35} | {'File Name':45} |\n"
    api_report += f"{'-'*100}\n"
    for file_path in repo_files:
        file_api_versions = get_file_api_versions(file_path)
        if file_api_versions:
            for version in file_api_versions:
                resource_type = os.path.splitext(os.path.basename(file_path))[0]
                repo_api_versions.add(version)
                api_report += f"| {version:20} | {resource_type:35} | {file_path:45} |\n"
    api_report += f"{'-'*100}\n"
    api_report += f"\nRepo API versions: {sorted(repo_api_versions)}\n"
    write_api_report(api_report)

generate_api_report()
