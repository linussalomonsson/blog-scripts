<#
.SYNOPSIS
    This script automates the deployment of Intune configurations from JSON files.

.DESCRIPTION
    The script reads Intune configuration settings from a set of JSON files, 
    deletes existing configurations with the same name, and creates new configurations in Intune. 
    It supports Device Compliance Policies, Configuration Policies, Device Configurations, 
    Group Policy Configurations, Device Templates, and App Protection Policies.

.NOTES
    This should be executed from a CI/CD pipeline.

.AUTHOR
    Email: linus.salomonsson@futureitpartner.se
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$appIdDev,
    [Parameter(Mandatory=$true)]
    [string]$tenantIdDev,
    [Parameter(Mandatory=$true)]
    [string]$appSecretDev
)

$Env:AZURE_CLIENT_ID = $appIdDev
$Env:AZURE_TENANT_ID = $tenantIdDev
$Env:AZURE_CLIENT_SECRET = $appSecretDev

Connect-MgGraph -EnvironmentVariable

$jsonFiles = @(
    @{ FileName = "DeviceAppManagement.AppProtection.json"; VariableName = "AppProtection"; FolderPath = "DeviceAppManagement.AppProtection" }
    @{ FileName = "DeviceManagement.ConfigurationPolicies.json"; VariableName = "ConfigurationPolicies"; FolderPath = "DeviceManagement.ConfigurationPolicies" }
    @{ FileName = "DeviceManagement.DeviceCompliance.json"; VariableName = "DeviceCompliance"; FolderPath = "DeviceManagement.DeviceCompliance" }
    @{ FileName = "DeviceManagement.DeviceConfigurations.json"; VariableName = "DeviceConfigurations"; FolderPath = "DeviceManagement.DeviceConfigurations" }
    @{ FileName = "DeviceManagement.GroupPolicyConfigurations.json"; VariableName = "GroupPolicyConfigurations"; FolderPath = "DeviceManagement.GroupPolicyConfigurations" }
    @{ FileName = "DeviceManagement.Templates.json"; VariableName = "DeviceTemplates"; FolderPath = "DeviceManagement.Templates" }
)

# Initialize the dictionary for json variables
$jsonVariables = @{}

foreach ($jsonFile in $jsonFiles) {
    $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $jsonFile.FolderPath
    $filePath = Join-Path -Path $folderPath -ChildPath $jsonFile.FileName

    Write-Output "Processing file: $filePath"

    if (Test-Path -Path $filePath) {
        $jsonContent = Get-Content -Path $filePath -Raw
        $jsonVariables[$jsonFile.VariableName] = $jsonContent
    } else {
        Write-Error "File not found: $filePath"
    }
}

foreach ($key in $jsonVariables.Keys) {
    if ($null -ne $jsonVariables[$key]) {
        try {
            Set-Variable -Name $key -Value ($jsonVariables[$key] | ConvertFrom-Json)
        } catch {
            Write-Error "Failed to parse JSON for $key"
        }
    } else {
        Write-Error "Variable $key is null"
    }
}

function Get-DeviceCompliance {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceCompliancePolicies"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)"
        $responseContent = $response.value

        if ($DeviceCompliance.PSObject.Properties.Name -contains $configName) {
            $DeviceCompliance = $DeviceCompliance.$configName
            $displayName = $DeviceCompliance.displayName

            $matchingItems = $responseContent | Where-Object { $_.displayName -eq $displayName }

            if ($matchingItems) {
                foreach ($item in $matchingItems) {
                    Write-Output "##[warning]The policy with the name $displayName exists. Deleting the policy with ID $($item.id)"

                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($item.id)" | Out-Null
                }
                Write-Output "All policies with the name $displayName have been deleted."
            } 
            else {
                Write-Output "No policies with the name $displayName were found."
            }
        }
    }
    catch {
        Write-Output "##[error]Could not delete the policy: $($displayName)."
        $_.Exception.Message
        return
    }
}

function New-DeviceCompliance {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceCompliancePolicies"

    if ($DeviceCompliance.PSObject.Properties.Name -contains $configName) {
        
        $settingsJson = $DeviceCompliance.$configName | ConvertTo-Json -Depth 100

        if ($configName) {
            try {
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)" -Body $settingsJson -ContentType "application/json" | Out-Null
                Write-Output "##[section]The policy $configName has been created."
            } catch {
                Write-Output "##[error]The policy $configName could not be created.: $($_.Exception.Message)"
                return
            }
        }
    }
}

function Get-ConfigurationPolicies {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)"
        $responseContent = $response.value

        if ($ConfigurationPolicies.PSObject.Properties.Name -contains $configName) {
            $ConfigurationPolicies = $ConfigurationPolicies.$configName
            $displayName = $ConfigurationPolicies.name

            $matchingItems = $responseContent | Where-Object { $_.name -eq $displayName }

            if ($matchingItems) {
                foreach ($item in $matchingItems) {
                    Write-Output "##[warning]The policy with the name $displayName exists. Deleting the policy with ID $($item.id)"

                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($item.id)" | Out-Null
                }
                Write-Output "All policies with the name $displayName have been deleted."
            } 
            else {
                Write-Output "No policies with the name $displayName were found."
            }
        }
    }
    catch {
        Write-Output "##[error]Could not delete the policy: $($displayName)."
        $_.Exception.Message
        return
    }
}

function New-ConfigurationPolicies {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies"

    if ($ConfigurationPolicies.PSObject.Properties.Name -contains $configName) {
        
        $settingsJson = $ConfigurationPolicies.$configName | ConvertTo-Json -Depth 100

        if ($configName) {
            try {
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)" -Body $settingsJson -ContentType "application/json" | Out-Null
                Write-Output "##[section]The policy $configName has been created."
            } catch {
                Write-Output "##[error]The policy $configName could not be created.: $($_.Exception.Message)"
                return
            }
        }
    }
}

function Get-DeviceConfigurations {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceConfigurations"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)"
        $responseContent = $response.value

        if ($DeviceConfigurations.PSObject.Properties.Name -contains $configName) {
            $DeviceConfigurations = $DeviceConfigurations.$configName
            $displayName = $DeviceConfigurations.displayName

            $matchingItems = $responseContent | Where-Object { $_.displayName -eq $displayName }

            if ($matchingItems) {
                foreach ($item in $matchingItems) {
                    Write-Output "##[warning]The policy with the name $displayName exists. Deleting the policy with ID $($item.id)"

                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($item.id)" | Out-Null
                }
                Write-Output "All policies with the name $displayName have been deleted."
            } 
            else {
                Write-Output "No policies with the name $displayName were found."
            }
        }
    }
    catch {
        Write-Output "##[error]Could not delete the policy: $($displayName)."
        $_.Exception.Message
        return
    }
}

function New-DeviceConfigurations {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/deviceConfigurations"

    if ($DeviceConfigurations.PSObject.Properties.Name -contains $configName) {
        
        $settingsJson = $DeviceConfigurations.$configName | ConvertTo-Json -Depth 100

        if ($configName) {
            try {
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)" -Body $settingsJson -ContentType "application/json" | Out-Null
                Write-Output "##[section]The policy $configName has been created."
            } catch {
                Write-Output "##[error]The policy $configName could not be created.: $($_.Exception.Message)"
                return
            }
        }
    }
}

function Get-GroupPolicyConfigurations {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/groupPolicyConfigurations"

    $GroupPolicyConfigurations = $GroupPolicyConfigurations | ForEach-Object {
        $_.PSObject.Properties.Name -eq $configName -and $_.PSObject.Properties.Name -notcontains "Update"
    
        $GroupPolicyConfigurations = $GroupPolicyConfigurations.$configName
        $displayName = $GroupPolicyConfigurations.displayName

        try {
            $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)"
            $responseContent = $response.value

            $matchingItems = $responseContent | Where-Object { $_.displayName -eq $displayName }
            if ($matchingItems) {
                foreach ($item in $matchingItems) {
                    Write-Host "##[warning]The policy with the name $displayName exists. Deleting the policy with ID $($item.id)" -ForegroundColor DarkYellow

                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($item.id)" | Out-Null
                }
                Write-Output "All policies with the name $displayName have been deleted."
            } 
            else {
                Write-Output "No policies with the name $displayName were found."
            }
        }
        catch {
            Write-Output "##[error]Could not delete the policy: $($displayName)."
            $_.Exception.Message
            return
        }
    }
        $GroupPolicyConfigurations = $GroupPolicyConfigurations | ForEach-Object {
        $_.PSObject.Properties.Name -eq $configName -and $_.PSObject.Properties.Name -contains "Update"
            Write-Output "##[warning]Skipping the policy $configName as it is an update policy."
        }
}

$ConfigurationIds = @{} 
function New-GroupPolicyConfigurations {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/groupPolicyConfigurations"

    if ($GroupPolicyConfigurations.PSObject.Properties.Name -contains $configName) {
        $settingsJson = $GroupPolicyConfigurations.$configName | ConvertTo-Json -Depth 50

        if ($configName -notmatch "Update") {
            try {
                $Configuration = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)" -Body $settingsJson -ContentType "application/json"
                $ConfigurationId = $Configuration.id
                $ConfigurationIds[$configName] = $ConfigurationId
                Write-Output "##[section]The policy $configName has been created."
            } catch {
                Write-Output "##[error]The policy $configName could not be created.: $($_.Exception.Message)"
                return
            }
        } 
        elseif ($configName -match "Update") {
            try {
                $originalConfigName = $configName -replace "Update", ""
                
                if ($ConfigurationIds.ContainsKey($originalConfigName)) {
                    $ConfigurationId = $ConfigurationIds[$originalConfigName]
                    Write-Output "##[section]Found Configuration ID: $ConfigurationId for $originalConfigName"
                    
                    $UpdateURL = "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($ConfigurationId)/updateDefinitionValues"
                    $updateSettingsJson = $GroupPolicyConfigurations.$configName | ConvertTo-Json -Depth 50
                    Invoke-MgGraphRequest -Method POST -Uri $UpdateURL -Body $updateSettingsJson -ContentType "application/json" | Out-Null
                    Write-Output "##[section]Updated $orginialConfigName configuration profile"
                } 
                else {
                    Write-Error "No Configuration ID found for $originalConfigName"
                }
            } 
            catch {
                Write-Error "Could not update $configName configuration profile: $($_.Exception.Message)"
            }
        }
    } 
    else {
        Write-Error "Configuration '$configName' does not exist in the JSON file."
    }
}

function Get-DeviceTemplates {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/intents"

    if ($DeviceTemplates.PSObject.Properties.Name -eq $configName) {
        $DeviceTemplates = $DeviceTemplates.$configName
        $displayName = $DeviceTemplates.displayName

        try {
            $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)"
            $responseContent = $response.value

            $matchingItems = $responseContent | Where-Object { $_.displayName -eq $displayName }

            if ($matchingItems) {
                foreach ($item in $matchingItems) {
                    Write-Output "##[warning]The template with the name $displayName exists. Deleting the template with ID $($item.id)"

                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($item.id)" | Out-Null
                }
                Write-Output "##[warning]All templates with the name $displayName have been deleted."
            } 
            else {
                Write-Output "##[warning]No templates with the name $displayName were found."
            }
        }
        catch {
            Write-Output "##[error]Could not delete the template: $($displayName)."
            $_.Exception.Message
            return
        }
    }
}

function New-DeviceTemplates {
    param(
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/templates"

    $DeviceTemplate = $DeviceTemplates.PSObject.Properties[$configName]

    if ($null -ne $DeviceTemplate) {
        $DeviceTemplateConfig = $DeviceTemplate.Value.PSObject.Copy()
        $DeviceTemplateId = $DeviceTemplate.Value.TemplateId
        $DeviceTemplateConfig.PSObject.Properties.Remove("TemplateId")
        $settingsJson = $DeviceTemplateConfig | ConvertTo-Json -Depth 100

        try {
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($DeviceTemplateId)/createInstance" -Body $settingsJson -ContentType "application/json" | Out-Null
            Write-Output "##[section]The policy $configName has been created."
        }
        catch {
            Write-Output "##[error]The policy $configName could not be created.: $($_.Exception.Message)"
            return
        }
    }
    else {
        Write-Output "##[error]No device template found with the name $configName."
    }
}

function Get-AppProtection {
    param (
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    
    if ($configName -match "Android") {
        $Resource = "deviceAppManagement/androidManagedAppProtections"
    }
    elseif ($configName -match "iOS") {
        $Resource = "deviceAppManagement/iosManagedAppProtections"
    }

    if ($AppProtection.PSObject.Properties.Name -eq $configName) {
        $AppProtection = $AppProtection.$configName
        $displayName = $AppProtection.displayName

        try {
            $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)"
            $responseContent = $response.value

            $matchingItems = $responseContent | Where-Object { $_.displayName -eq $displayName }

            if ($matchingItems) {
                foreach ($item in $matchingItems) {
                    Write-Output "##[warning]The app protection with the name $displayName exists. Deleting the app protection with ID $($item.id)"

                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)/$($item.id)" | Out-Null
                }
                Write-Output "##[warning]All app protection with the name $displayName have been deleted."
            } 
            else {
                Write-Output "##[warning]No app protection with the name $displayName were found."
            }
        }
        catch {
            Write-Output "##[error]Could not delete the app protection: $($displayName)."
            $_.Exception.Message
            return
        }
    }
}

function New-AppProtection {
    param (
        [Parameter(Mandatory=$true)]
        [string]$configName
    )

    $graphApiVersion = "beta"
    
    if ($configName -match "Android") {
        $Resource = "deviceAppManagement/androidManagedAppProtections"
    }
    elseif ($configName -match "iOS") {
        $Resource = "deviceAppManagement/iosManagedAppProtections"
    }

    if ($AppProtection.PSObject.Properties.Name -contains $configName) {

        $settingsJson = $AppProtection.$configName | ConvertTo-Json -Depth 100

        try {
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/$($graphApiVersion)/$($Resource)" -Body $settingsJson -ContentType "application/json" | Out-Null
            Write-Output "##[section]The app protection $configName has been created."
        }
        catch {
            Write-Output "##[error]The app protection $configName could not be created.: $($_.Exception.Message)"
            return
        }
    }
}



foreach ($configName in $DeviceCompliance.PSObject.Properties.Name) {
    Get-DeviceCompliance -configName $configName
    New-DeviceCompliance -configName $configName
}

foreach ($configName in $ConfigurationPolicies.PSObject.Properties.Name) {
    Get-ConfigurationPolicies -configName $configName
    New-ConfigurationPolicies -configName $configName
}

foreach ($configName in $DeviceConfigurations.PSObject.Properties.Name) {
    Get-DeviceConfigurations -configName $configName
    New-DeviceConfigurations -configName $configName
}

foreach ($configName in $GroupPolicyConfigurations.PSObject.Properties.Name) {
    Get-GroupPolicyConfigurations -configName $configName
    New-GroupPolicyConfigurations -configName $configName
}

foreach ($configName in $DeviceTemplates.PSObject.Properties.name) {
    Get-DeviceTemplates -configName $configName
    New-DeviceTemplates -configName $configName
}

foreach ($configName in $AppProtection.PSObject.Properties.Name) {
    Get-AppProtection -configName $configName
    New-AppProtection -configName $configName
}
