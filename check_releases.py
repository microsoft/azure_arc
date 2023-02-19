import requests

# read list of repositories from config file
with open("repositories.txt") as f:
    repositories = [line.strip() for line in f]

for repo in repositories:
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    response = requests.get(url)

    if response.status_code == 200:
        data = response.json()
        latest_release = data["name"]
        # extract version number
        version_number = latest_release.lstrip('v')
        print(f"Latest release for {repo}: v{version_number}")
    else:
        print(f"Error retrieving latest release for {repo}")
