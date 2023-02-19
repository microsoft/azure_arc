import os
import re
import requests

# Get latest Azure API versions for all resource types
def get_latest_azure_api_versions():
    # Retrieve list of Azure resource types
    url = "https://management.azure.com/subscriptions/{subscription_id}/providers?api-version=2020-01-01"
    headers = {"Authorization": "Bearer " + os.environ["GITHUB_TOKEN"]}
    response = requests.get(url.format(subscription_id=os.environ["AZURE_SUBSCRIPTION_ID"]), headers=headers)
    if not response.ok:
        raise Exception(f"Failed to retrieve Azure resource types: {response.status_code} {response.reason}")
    resource_types = [r["resourceType"] for r in response.json()["value"]]

    # Retrieve latest API versions for each resource type
    latest_api_versions = {}
    for resource_type in resource_types:
        url = f"https://management.azure.com/providers/{resource_type}?api-version=2020-01-01"
        response = requests.get(url, headers=headers)
        if response.ok:
            latest_api_versions[resource_type] = response.json()["resourceTypes"][0]["apiVersions"][0]

    return latest_api_versions

# Get Azure API versions used in templates
def get_template_api_versions(template_file):
    with open(template_file, "r") as f:
        content = f.read()

    api_versions = set(re.findall(r"apiVersion:\s*(\d{4}-\d{2}-\d{2})", content))

    return api_versions

def scan_templates(root_dir):
    # Get latest Azure API versions for all resource types
    latest_api_versions = get_latest_azure_api_versions()

    # Scan all template files in directory
    results = {}
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Ignore directories specified in excludes
        for exclude in excludes:
            if exclude in dirnames:
                dirnames.remove(exclude)

        for filename in filenames:
            if filename.endswith(".json") or filename.endswith(".bicep"):
                template_file = os.path.join(dirpath, filename)

                # Get Azure API versions used in template
                template_api_versions = get_template_api_versions(template_file)

                # Compare with latest Azure API versions
                for api_version in template_api_versions:
                    resource_type = template_file.split(os.sep)[-2]
                    if resource_type in latest_api_versions and api_version != latest_api_versions[resource_type]:
                        if api_version not in results:
                            results[api_version] = []
                        results[api_version].append((resource_type, template_file))

    return results

# Scan templates in directory
root_dir = "."
excludes = [".github", "docs", "img", "social", "tests"]
results = scan_templates(root_dir)

# Generate report
report = "Azure API versions in use:\n\n"
if results:
    report += "{:<20} {:<40} {}\n".format("API Version", "Azure Resource Type", "File")
    report += "-" * 70 + "\n"
    for api_version, resources in sorted(results.items()):
        for resource_type, template_file in resources:
            report += "{:<20} {:<40} {}\n".format(api_version, resource_type, template_file)
else:
    report += "No Azure API versions found in templates."

# Save report to file
report_file = os.path.join(root_dir, "tests", "api_report.txt")
with open(report_file, "w") as f:
    f.write(report)

print(f"Report saved to {report_file}")
