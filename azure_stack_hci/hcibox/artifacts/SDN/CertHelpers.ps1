# --------------------------------------------------------------
#  Copyright © Microsoft Corporation.  All Rights Reserved.
#  Microsoft Corporation (or based on where you live, one of its affiliates) licenses this sample code for your internal testing purposes only.
#  Microsoft provides the following sample code AS IS without warranty of any kind. The sample code arenot supported under any Microsoft standard support program or services.
#  Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose.
#  The entire risk arising out of the use or performance of the sample code remains with you.
#  In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the code be liable for any damages whatsoever
#  (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss)
#  arising out of the use of or inability to use the sample code, even if Microsoft has been advised of the possibility of such damages.
# ---------------------------------------------------------------


Function PrettyTime()   {
    return "[" + (Get-Date -Format o) + "]"
}
Function Log($msg)   {
    Write-Verbose $( $(PrettyTime) + " " + $msg) -Verbose
}

function GetSubjectName([bool] $UseManagementAddress)   {
	if ($UseManagementAddress -eq $true)
	{
		# When IP Address is specified, we are currently looking just for IPv4 corpnet ip address
		# In the final design, only computer names will be used for subject names
		$corpIPAddresses = get-netIpAddress -AddressFamily IPv4 -PrefixOrigin Dhcp -ErrorAction Ignore
		if ($corpIPAddresses -ne $null -and $corpIPAddresses[0] -ne $null)
		{
			$mesg = [System.String]::Format("Using IP Address {0} for certificate subject name", $corpIPAddresses[0].IPAddress);
			Log $mesg
			return $corpIPAddresses[0].IPAddress
		}
		else
		{
			Log "Unable to find management IP address ";
		}
	}
	
	$hostFqdn = [System.Net.Dns]::GetHostByName(($env:computerName)).HostName;
	$mesg = [System.String]::Format("Using computer name {0} for certificate subject name", $hostFqdn);
	Log $mesg
    return $hostFqdn ;
}
function GenerateSelfSignedCertificate([string] $subjectName)   {
    $cryptographicProviderName = "Microsoft Base Cryptographic Provider v1.0";
    [int] $privateKeyLength = 1024;
    $sslServerOidString = "1.3.6.1.5.5.7.3.1";
    $sslClientOidString = "1.3.6.1.5.5.7.3.2";
    [int] $validityPeriodInYear = 5;

    $name = new-object -com "X509Enrollment.CX500DistinguishedName.1"
    $name.Encode("CN=" + $SubjectName, 0)

	$mesg = [System.String]::Format("Generating certificate with subject Name {0}", $subjectName);
	Log $mesg


    #Generate Key
    $key = new-object -com "X509Enrollment.CX509PrivateKey.1"
    $key.ProviderName = $cryptographicProviderName
    $key.KeySpec = 1 #X509KeySpec.XCN_AT_KEYEXCHANGE
    $key.Length = $privateKeyLength
    $key.MachineContext = 1
    $key.ExportPolicy = 0x2 #X509PrivateKeyExportFlags.XCN_NCRYPT_ALLOW_EXPORT_FLAG 
    $key.Create()

    #Configure Eku
    $serverauthoid = new-object -com "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue($sslServerOidString)
    $clientauthoid = new-object -com "X509Enrollment.CObjectId.1"
    $clientauthoid.InitializeFromValue($sslClientOidString)
    $ekuoids = new-object -com "X509Enrollment.CObjectIds.1"
    $ekuoids.add($serverauthoid)
    $ekuoids.add($clientauthoid)
    $ekuext = new-object -com "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    # Set the hash algorithm to sha512 instead of the default sha1
    $hashAlgorithmObject = New-Object -ComObject X509Enrollment.CObjectId
    $hashAlgorithmObject.InitializeFromAlgorithmName( $ObjectIdGroupId.XCN_CRYPT_HASH_ALG_OID_GROUP_ID, $ObjectIdPublicKeyFlags.XCN_CRYPT_OID_INFO_PUBKEY_ANY, $AlgorithmFlags.AlgorithmFlagsNone, "SHA512")


    #Request Cert
    $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"

    $cert.InitializeFromPrivateKey(2, $key, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = (get-date).ToUniversalTime()
    $cert.NotAfter = $cert.NotBefore.AddYears($validityPeriodInYear);
    $cert.X509Extensions.Add($ekuext)
    $cert.HashAlgorithm = $hashAlgorithmObject
    $cert.Encode()

    $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")

	Log "Successfully added cert to local machine store";
}
function GivePermissionToNetworkService($targetCert)   {
    $targetCertPrivKey = $targetCert.PrivateKey 
    $privKeyCertFile = Get-Item -path "$ENV:ProgramData\Microsoft\Crypto\RSA\MachineKeys\*"  | where {$_.Name -eq $targetCertPrivKey.CspKeyContainerInfo.UniqueKeyContainerName} 
    $privKeyAcl = Get-Acl $privKeyCertFile
    $permission = "NT AUTHORITY\NETWORK SERVICE","Read","Allow" 
    $accessRule = new-object System.Security.AccessControl.FileSystemAccessRule $permission 
    $privKeyAcl.AddAccessRule($accessRule) 
    Set-Acl $privKeyCertFile.FullName $privKeyAcl
}
Function AddCertToLocalMachineStore($certFullPath, $storeName, $securePassword)    {
    $rootName = "LocalMachine"

    # create a representation of the certificate file
    $certificate = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
    if($securePassword -eq $null)
    {
        $certificate.import($certFullPath)
    }
    else 
    {
        # https://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509keystorageflags(v=vs.110).aspx
        $certificate.import($certFullPath, $securePassword, "MachineKeySet,PersistKeySet")
    }
    
    # import into the store
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store($storeName, $rootName)
    $store.open("MaxAllowed")
    $store.add($certificate)
    $store.close()
}
Function GetSubjectFqdnFromCertificatePath($certFullPath)    {
    # create a representation of the certificate file
    $certificate = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
    $certificate.import($certFullPath)
    return GetSubjectFqdnFromCertificate $certificate ;
}
Function GetSubjectFqdnFromCertificate([System.Security.Cryptography.X509Certificates.X509Certificate2] $certificate)    {
    $mesg = [System.String]::Format("Parsing Subject Name {0} to get Subject Fqdn ", $certificate.Subject)
    Log $mesg
    $subjectFqdn = $certificate.Subject.Split('=')[1] ;
    return $subjectFqdn;
}
Function GetCertificate($cn, [bool]$generateCert=$false) {
    $cert = get-childitem "Cert:\localmachine\my" | where {$_.Subject.ToUpper().StartsWith("CN=$cn")}

    if (($generateCert -eq $true) -and ($cert -eq $null)) {
        $mesg = [System.String]::Format("Generating Certificate...");
        Log $mesg
        GenerateSelfSignedCertificate $cn
        $cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where {$_.Subject.ToUpper().StartsWith("CN=$cn")}
    }

    # adding check for cert
    if ($cert -eq $null) {
        $mesg = [System.String]::Format("Certificate was null, waiting 30 secs and retrying, CN= {0}", $cn);
        Log $mesg
        Sleep 30
        $cert = get-childitem "Cert:\localmachine\my" | where {$_.Subject.ToUpper().StartsWith("CN=$cn")}

        #last chance
        if ($cert -eq $null) {
            throw "Certificate not available..."
        }
    }
    return $cert;
}

