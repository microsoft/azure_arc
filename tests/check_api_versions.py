import os
import re
import requests

# Define the regex pattern for matching Azure API versions
api_version_pattern = re.compile(r"(?<=apiVersion\": \")[\d.-]+(?=\")")

# Define the directory to start scanning from (root of repository)
start_dir = os.getcwd()

# Define the directories to exclude
exclude_dirs = [".github", "docs", "img", "social", "tests"]

# Define the output file and location
output_file = os.path.join(start_dir, 'tests', 'api_report.txt')

# Define the Azure API version endpoint URL
api_endpoint = 'https://management.azure.com/providers/Microsoft.ApiManagement/apiVersionSet?api-version=2020-06-01-preview'

# Send a request to the API endpoint to get the latest published API versions
response = requests.get(api_endpoint)
if response.status_code == 200:
    latest_api_versions = set(response.json().get('value')[0].get('versionSet').get('versions'))
else:
    print(f'Error getting latest API versions: {response.status_code}')

# Recursively search through all directories, skipping any excluded directories
with open(output_file, 'w') as f:
    for root, dirs, files in os.walk(start_dir):
        # Skip any excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        for file in files:
            # Check if the file is an ARM, Bicep, or Terraform template
            if file.endswith('.json') or file.endswith('.bicep') or file.endswith('.tf'):
                # Read the file contents and look for the API version
                with open(os.path.join(root, file), 'r') as file_contents:
                    contents = file_contents.read()
                    api_versions = api_version_pattern.findall(contents)
                    for api_version in api_versions:
                        f.write(f'{api_version}\n')

# Read the API versions from the report file and compare to the latest published API versions
with open(output_file, 'r') as f:
    repo_api_versions = set(f.read().splitlines())

# Create a report of the API versions and the latest published API versions
report = []
for api_version in repo_api_versions:
    if api_version not in latest_api_versions:
        report.append(f'API version {api_version} is not the latest published version')

if report:
    print('\n'.join(report))
else:
    print('All API versions in the repo are the latest published versions')
