import requests
import re

# read list of repositories from config file
with open("repositories.txt") as f:
    repositories = [line.strip() for line in f]

for repo in repositories:
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    response = requests.get(url)

    if response.status_code == 200:
        data = response.json()
        latest_release = data["name"]
        # extract version number using regular expression
        version_number = re.search(r"\d+(\.\d+)*", latest_release).group()
        print(f"Latest release for {repo}: {version_number}")
    else:
        print(f"Error retrieving latest release for {repo}")
