$debug = $true
########################################################################
# Get Windows Admin Username and Password
$JS_WINDOWS_ADMIN_USERNAME = 'arcdemo'
if ($promptOutput = Read-Host "Enter the Windows Admin Username [$JS_WINDOWS_ADMIN_USERNAME]") { $JS_WINDOWS_ADMIN_USERNAME = $promptOutput }

azd env set JS_WINDOWS_ADMIN_USERNAME $JS_WINDOWS_ADMIN_USERNAME

# The user will be prompted for this by azd so we can maintain the security of the password.
# $JS_WINDOWS_ADMIN_PASSWORD = Read-Host "Enter the Windows Admin Password (hint: ArcPassword123!! - 12 character minimum)" -AsSecureString

# azd env set JS_WINDOWS_ADMIN_PASSWORD $JS_WINDOWS_ADMIN_PASSWORD


########################################################################
Write-Host "Creating SSH RSA Public Key..."
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
# TODO - consider moving SPN creation to Bicep
Write-Host "Creating Azure Service Principal..."
# Install Azure module if not already installed
if (-not (Get-Command -Name Get-AzContext)) {
    Write-Host "Installing Azure module..."
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
}

# If not signed in, run the Connect-AzAccount cmdlet
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

$uniqueSpnName = "jumpstart-spn-$(Get-Random -Minimum 1000 -Maximum 9999)"
# TODO - check for success and exit if failure
#        provide instructions for getting the correct permissions
try {
    $spn = New-AzADServicePrincipal -DisplayName $uniqueSpnName -Role "Owner" -Scope "/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)" -ErrorAction Stop
}
catch {
    If ($error[0].ToString() -match "Forbidden"){
        Throw "You do not have permission to create a service principal. Please contact your Azure subscription administrator to grant you the Owner role on the subscription."
    }
    else {
        Throw "An error occurred creating the service principal. Please try again."
    }
} 

$SPN_CLIENT_ID = $spn.AppId
$SPN_CLIENT_SECRET = $spn.PasswordCredentials.SecretText
$SPN_TENANT_ID = (Get-AzContext).Tenant.Id

# Set environment variables
If ($debug){Write-Host "Setting environment variables..."}
azd env set SPN_CLIENT_ID $SPN_CLIENT_ID
azd env set SPN_CLIENT_SECRET $SPN_CLIENT_SECRET
azd env set SPN_TENANT_ID $SPN_TENANT_ID
