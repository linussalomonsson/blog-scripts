<#
.SYNOPSIS
    Downloads a certificate from Azure Blob Storage and configures it for Remote Desktop Services.
.DESCRIPTION
    This script downloads a certificate from Azure Blob Storage, imports it, and configures it for Remote Desktop Services roles.
    Modify the script to your needs, whether that be deploying from an RMM tool or any different means.
.PARAMETER certpassword
    The password for the certificate.
.PARAMETER fileName
    The name of the certificate file, eg. "certificate.pfx".
.PARAMETER blobUri
    The url to the Azure Blob Storage container, eg. "https://<storageaccount>.blob.core.windows.net/<container>/".
.PARAMETER blobSAS
    The Shared Access Signature token for the Azure Blob Storage container, eg. "?sp=XXXX".

.AUTHOR
    Email: linus.salomonsson@daeio.com
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[securestring]$certpassword,
	[Paramter(Mandatory = $true)]
	[string]$fileName,
	[Parameter(Mandatory = $true)]
	[string]$blobUri,
	[Parameter(Mandatory = $true)]
	[string]$blobSAS
)

$hostname = [System.Net.Dns]::GetHostByName((hostname)).HostName
$logPath = "C:\ProgramData\daeio\cert-deployment.log"

# Add timestamp to transcript start
Start-Transcript -Path $logPath -Force

Write-Output "Starting certificate deployment at $(Get-Date)"

if ($blobUri -notlike "*/") {
	$blobUri += "/"
	$fullUri = $blobUri + $fileName + $blobSAS
}
else {
	$fullUri = $blobUri + $fileName + $blobSAS
}

if ($fileName -notlike "*.pfx") {
	Write-Output "The certificate file must be a .pfx file"
	exit
}
else {
	$OutputPath = "C:\ProgramData\daeio\$($fileName)"
}

try {
	Invoke-WebRequest -Uri $fullURI -OutFile $OutputPath
	Write-Output "Successfully downloaded certificate..."
}
catch {
	Write-Error "Could not download certificate..."
	$_.Exception.Message
	Stop-Transcript
	exit 1
}

function Invoke-Certificate {
	param(
		[Parameter(Mandatory = $true)]
		[string]$hostname,
		[Parameter(Mandatory = $true)]
		[string]$certPath,
		[Parameter(Mandatory = $true)]
		[securestring]$certpassword
	)

	$roles = @("RDGateway","RDWebAccess","RDPublishing","RDRedirector")

	try {
		Import-PfxCertificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\My -Exportable -Password $certpassword
		Write-Output "Imported certificate to Cert:\LocalMachine\My"

		foreach ($role in $roles) {
			Write-Output "Setting certificate for role '$role'..."
			Set-RDCertificate -Role $role -ImportPath $certPath -Password $certpassword -ConnectionBroker $hostname -Force
		}

		Write-Output "Successfully set SSL certificate for $hostname"

		if (Get-Module -ListAvailable -Name RDWebClientManagement -ErrorAction SilentlyContinue) {
			Import-RDWebClientBrokerCert -Path $certPath -Password $certpassword -ErrorAction Stop
			Publish-RDWebClientPackage -Type Production -Latest -ErrorAction Stop
			Write-Output "Successfully imported and published new certificate to the HTML webclient"
		}
		else {
			Write-Output "HTML webclient module is not installed, skipping import and publish..."
		}

	}
	catch {
		Write-Error "Could not set SSL certificate for $hostname"
		$_.Exception.Message
		throw
	}
}

try {
	Invoke-Certificate -HostName $hostname -certPath $OutputPath -certpassword $certpassword
}
catch {
	Write-Error "Could not set SSL certificate for $hostname"
	$_.Exception.Message
	exit 1
}

Write-Output "Removing certificate file '$OutputPath'"
Remove-Item -Path $OutputPath -Force
Write-Output "Successfully removed certificate file"

Write-Output "Finished certificate deployment at $(Get-Date)"
Stop-Transcript
exit 0
