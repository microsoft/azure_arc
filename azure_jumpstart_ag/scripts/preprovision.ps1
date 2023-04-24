########################################################################
# Get Windows Admin Username and Password
$JS_WINDOWS_ADMIN_USERNAME = 'arcdemo'
if ($promptOutput = Read-Host "Enter the Windows Admin Username [$JS_WINDOWS_ADMIN_USERNAME]") { $JS_WINDOWS_ADMIN_USERNAME = $promptOutput }

azd env set JS_WINDOWS_ADMIN_USERNAME $JS_WINDOWS_ADMIN_USERNAME

$JS_WINDOWS_ADMIN_PASSWORD = Read-Host "Enter the Windows Admin Password (hint: ArcPassword123!! - 12 character minimum)" -AsSecureString

azd env set JS_WINDOWS_ADMIN_PASSWORD $JS_WINDOWS_ADMIN_PASSWORD

########################################################################
Write-Host "Getting SSH RSA Public Key..."
$file = "js_rsa"
remove-item $file, "$file.pub" -Force -ea 0 

# Generate the SSH key pair
ssh-keygen -q -t rsa -b 4096 -f $file -N '""' 

# Get the public key
$JS_SSH_RSA_PUBLIC_KEY = get-content "$file.pub"

# Escape the backslashes 
$JS_SSH_RSA_PUBLIC_KEY = $JS_SSH_RSA_PUBLIC_KEY.Replace("\", "\\")

azd env set JS_SSH_RSA_PUBLIC_KEY $JS_SSH_RSA_PUBLIC_KEY


########################################################################
Write-Host "Getting SPN values..."
# Using az because not sure how to do this with PowerShell cmdlet
$subscriptionId = az account show --query id -o tsv
$uniqueSpnName = "jumpstart-spn-$(Get-Random -Minimum 1000 -Maximum 9999)"
$spn = New-AzADServicePrincipal -DisplayName $uniqueSpnName -Role "Owner" -Scope "/subscriptions/$($subscriptionId)"

$SPN_CLIENT_ID = $spn.AppId
$SPN_CLIENT_SECRET = $spn.PasswordCredentials.SecretText
$SPN_TENANT_ID = az account show --query tenantId -o tsv

# Set environment variables
azd env set SPN_CLIENT_ID $SPN_CLIENT_ID
azd env set SPN_CLIENT_SECRET $SPN_CLIENT_SECRET
azd env set SPN_TENANT_ID $SPN_TENANT_ID
