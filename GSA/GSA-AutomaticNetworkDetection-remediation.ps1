<#
.SYNOPSIS
    This script automatically detects the network location and remediates Global Secure Access (GSA) services.

.DESCRIPTION
    The script checks the external IP address against a target IP. Based on whether the IP matches, 
    it either stops or starts the specified GSA services. It also checks for a registry key to suspend 
    the remediation process. The script runs in a loop for a defined number of iterations before exiting.

.AUTHOR
    Email: linus.salomonsson@futureitpartner.se
    
#>

function Get-ExternalIP {
    try {
        $externalIP = Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing | Select-Object -ExpandProperty Content
        if (-not [string]::IsNullOrEmpty($externalIP)) {
            return $externalIP.Trim()
        }
        else {
            Write-Warning "Could not retrieve external IP from api.ipify.org. Trying ipinfo.io..."
            $externalIP = Invoke-WebRequest -Uri "https://ipinfo.io/ip/ip" -UseBasicParsing | Select-Object -ExpandProperty Content
            if (-not [string]::IsNullOrEmpty($externalIP)) {
                return $externalIP.Trim()
            }
            else {
                Write-Error "Failed to retrieve external IP from both api.ipify.org and ipinfo.io."
                return $null
            }
        }
    }
    catch {
        Write-Error "Error retrieving external IP: $($_.Exception.Message)"
        return $null
    }
}

function Get-ServicesStopped {
    foreach ($ServiceName in $ServiceNames) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -ne 'Stopped') {
            return $false
        }
    }
    return $true 
}

function Get-ServicesRunning {
    foreach ($ServiceName in $ServiceNames) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -ne 'Running') {
            return $false
        }
    }
    return $true
}

$TargetExternalIP = "xxx.xxx.xxx.xxx"
$ServiceNames = @(
    "GlobalSecureAccessPolicyRetrieverService",
    "GlobalSecureAccessClientManagerService",
    "GlobalSecureAccessEngineService",
    "GlobalSecureAccessTunnelingService"
)

$RegPath = "HKLM:\SOFTWARE\EntraGSA_NetworkDetection"
$RegKey_LastRemediation = "EntraGSA_RemediationScript_Last_Run"
$RegKey_SuspendRemediation = "EntraGSA_SuspendNetworkDetectionRemediation"

$RerunEveryMin = 1
$RerunNumberBeforeExiting = 59
$RerunTesting = $false

$RunFrequency = 1

While ($RunFrequency -le $RerunNumberBeforeExiting) {
    $externalIP = Get-ExternalIP
    $servicesRunning = Get-ServicesRunning
    $servicesStopped = Get-ServicesStopped
    $SuspendStatusValue = Get-ItemProperty -Path $RegPath -Name $RegKey_SuspendRemediation -ErrorAction SilentlyContinue

    if ($SuspendStatusValue) {
        $SuspendStatusValue = Get-ItemPropertyValue -Path $RegPath -Name $RegKey_SuspendRemediation -ErrorAction SilentlyContinue
    }

    if (($null -eq $SuspendStatusValue) -or ($SuspendStatusValue -eq "") -or ($SuspendStatusValue -eq 0)) {
        if ($externalIP -eq $TargetExternalIP) {
            Write-Output "External IP is correct. Checking services..."
            $LocalNetworkDetected = $true
        }
        else {
            Write-Output "External IP is not correct. Checking services..."
            $LocalNetworkDetected = $false
        }

        if ($LocalNetworkDetected) {
            Write-Output "Local network detected. Turning off services..."

            if ($servicesRunning) {
                Write-Output "All services are running. Stopping services..."
                foreach ($ServiceName in $ServiceNames) {
                    Write-Output "Stopping service $ServiceName..."
                    Stop-Service -Name $ServiceName -ErrorAction Stop -WarningAction SilentlyContinue -Force
                    Clear-DnsClientCache
                }
            }
            if ($servicesStopped) {
                Write-Output "All services are stopped."
            }
        }
        elseif (-not $LocalNetworkDetected) {
            Write-Output "Local network not detected. Turning on services..."

            if ($servicesStopped) {
                Write-Output "All services are stopped. Starting services..."
                foreach ($ServiceName in $ServiceNames) {
                    Write-Output "Starting service $ServiceName..."
                    Start-Service -Name $ServiceName -ErrorAction Stop -WarningAction SilentlyContinue
                    Clear-DnsClientCache
                }
            }
            if ($servicesRunning) {
                Write-Output "All services are running."
            }
        }

        if (-not (Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }

        $Now = (Get-Date)
        New-ItemProperty -Path $RegPath -Name $RegKey_LastRemediation -Value $Now -PropertyType String -Force | Out-Null

        $RunFrequency = 1 + $RunFrequency

        if ($RerunTesting -eq $true) {
            Write-Output "Sleeping for 2 seconds..."
            Start-Sleep -Seconds 2
        }
        else {
            $SleepSeconds = $RerunEveryMin * 60
            Write-Output "Sleeping for $($RerunEveryMin) min..."
            Start-Sleep -Seconds $SleepSeconds
        }
    }
    else {
        Write-Output "Suspending script due to suspend-key was detected..."
        exit 0
    }
}
Write-Output "Script has run $RerunNumberBeforeExiting times. Exiting..."
exit 0