import os 
import subprocess

# Declaring the deployment environment (Production/Dev)
os.environ['templateBaseUrl'] = 'https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_arcbox/ARM/'
templateBaseUrl = os.getenv('templateBaseUrl')

os.environ['deploymentEnvironment'] = templateBaseUrl.find("microsoft/azure_arc/main")
deploymentEnvironment = os.getenv('deploymentEnvironment')

# templateBaseUrl = os.getenv('templateBaseUrl')

# os.environ['deploymentEnvironment'] = subprocess.check_output("echo ['templateBaseUrl']", shell=True)
print(f'{templateBaseUrl}')

# os.environ['API_USER'] = 'username'



templateBaseUrl = 'https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_arcbox/ARM/'
deploymentEnvironment = templateBaseUrl.find('microsoft/azure_arc/main')


flavor = None
if flavor is None:
    jumpstartDeployment = "Jumpstart scenario"
else:
    jumpstartDeployment = "Jumpstart ArcBox"

print(f'{jumpstartDeployment}')

# Setting up the environment variable for the Jumpstart App Configuration connection string deployment (Production/Dev)
jumpstartAppConfigProduction = 'Endpoint=https://jumpstart-prod.azconfig.io;Id=xcEf-l6-s0:Fn+IoFEzNKvm/Bo0+W1I;Secret=dkuO3eUhqccYw6YWkFYNcPMZ/XYQ4r9B/4OhrWTLtL0='
jumpstartAppConfigDev = 'Endpoint=https://jumpstart-dev.azconfig.io;Id=5xh8-l6-s0:q89J0MWp2twZnTsqoiLQ;Secret=y5UFAWzPNdJsPcRlKC538DimC4/nb1k3bKuzaLC90f8='

if deploymentEnvironment is None:
    AZURE_APPCONFIG_CONNECTION_STRING = jumpstartAppConfigDev
    deploymentEnvironment = 'Dev'
    print()
    print(f'This is a {jumpstartDeployment} {deploymentEnvironment} deployment!')
else:
    AZURE_APPCONFIG_CONNECTION_STRING = jumpstartAppConfigProduction
    deploymentEnvironment = 'Production'
    print()
    print(f'This is a {jumpstartDeployment} {deploymentEnvironment} deployment!')

from az.cli import az

# AzResult = namedtuple('AzResult', ['exit_code', 'result_dict', 'log'])
exit_code, result_dict, logs = az("group list")

# On 0 (SUCCESS) print result_dict, otherwise get info from `logs`
if exit_code == 0:
    print (result_dict)
else:
    print(logs)


# Declaring required Azure Arc resource providers
providersArcKubernetes = subprocess.check_output("az appconfig kv list --key 'providersArcKubernetes' --label {deploymentEnvironment} --query '[].value' -o tsv", shell=True)

providersArcKubernetes = subprocess.check_output("az appconfig kv list --key 'providersArcKubernetes' --label {deploymentEnvironment} --query '[].value' -o tsv", shell=True)

print({providersArcKubernetes})

providersArcKubernetes = subprocess.check_output("az(appconfig kv list --key 'providersArcKubernetes' --label {deploymentEnvironment} --query '[].value' -o tsv)", shell=True)
providersArcKubernetes = subprocess.check_output(az("appconfig kv list --key 'providersArcKubernetes' -o tsv"), shell=True)

providersArcKubernetes = subprocess.check_output(az("group list"), shell=True)