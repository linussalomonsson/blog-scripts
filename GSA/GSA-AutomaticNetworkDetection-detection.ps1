$RegPath = "HKLM:\SOFTWARE\EntraGSA_NetworkDetection"
$RegKeyLocation = "EntraGSA_DetectionScript_Last_Run"
$RegKey_SuspendRemediation  = "EntraGSA_SuspendNetworkDetectionRemediation"
$GSAClientName = "Global Secure Access Client"

$installedPrograms = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | ForEach-Object {$_.DisplayName}

if ($installedPrograms -contains $GSAClientName) {

    Write-Output "GSAClient is installed"

    $SuspendStatusValue = 0 # Value 0 enables the remedation to run. Value 1 disables the remediation from running.

    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null   
    }

    $Now = (Get-Date)
    New-ItemProperty -Path $RegPath -Name $RegKeyLocation -Value $Now -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name $RegKey_SuspendRemediation -Value $SuspendStatusValue -PropertyType String -Force | Out-Null
    exit 1
    
}
else {
    Write-Output "GSAClient is not installed"
    exit 0
}