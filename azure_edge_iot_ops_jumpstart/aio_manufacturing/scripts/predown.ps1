########################################################################
# Delete service principal
########################################################################
$spnObjectId = $env:SPN_OBJECT_ID
Remove-AzRoleAssignment -ObjectId $spnObjectId -RoleDefinitionName "Owner"
Remove-AzADServicePrincipal -ObjectId $spnObjectId