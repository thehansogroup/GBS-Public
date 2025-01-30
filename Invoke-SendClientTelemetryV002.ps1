# Globale Parameter
$global:DataEndpointURL = "https://prod-89.westeurope.logic.azure.com:443/workflows/c557b724d40449e1b0e33075c42ae56f/triggers/When_a_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_a_HTTP_request_is_received%2Frun&sv=1.0&sig=tYWsT9wMkLRRViM_wkcBKF-MzZqDXHDgpJmyv05JeeY"
$global:LogFilePath = "C:\ProgramData\SystemAndVMInfo.log"
$global:JsonFilePath = "C:\ProgramData\CurrentSystemInfo.json"

# Function to write logs
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [string]$Type # "INFO", "ERROR"
    )

    try {
        $timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        $logEntry = "$timestamp [$Type] $Message"
        Add-Content -Path $global:LogFilePath -Value $logEntry
    } catch {
        Write-Error "Failed to write log entry: $_"
    }
}



function Get-HardwareHashInfo {
    # Ensure that the required module is installed
    if (!(Get-Module -ListAvailable -Name WindowsAutopilotIntune)) {
        try {
            # Ensure NuGet is installed
            if (-not (Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq "NuGet" })) {
                Install-PackageProvider -Name NuGet -Force -Confirm:$false
            }
            
            # Set PSGallery as a trusted repository if not already trusted
            if ((Get-PSRepository -Name 'PSGallery').InstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            }
            
            Install-Script -Name Get-WindowsAutopilotInfo -Force -Confirm:$false -ErrorAction Stop
        } catch {
            Write-Log -Message "Failed to install Get-WindowsAutopilotInfo. $_ Ensure you have admin rights and an internet connection." -Type "ERROR"
            return 0
        }
    }

    # Collect the Hardware Hash directly without output file
    $HardwareHash = Get-WindowsAutopilotInfo | ConvertTo-Json -Compress
    Write-Log -Message "Successfully got Hardware Hash" -Type "INFO"
    # Convert the collected hash to Base64
    $Base64HardwareHash = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($HardwareHash))

    return $Base64HardwareHash

}

function Initialize-LogFile {
    # Ensure the global log file path is set
    if (-not $global:LogFilePath) {
        throw "Global variable 'LogFilePath' is not set. Please set it before calling Initialize-LogFile."
    }

    # Check if the log file exists and its size
    $maxFileSize = 100kb
    $archiveFilePath = "$global:LogFilePath.archive"

    if (Test-Path $global:LogFilePath) {
        $fileInfo = Get-Item $global:LogFilePath
        if ($fileInfo.Length -ge $maxFileSize) {
            # Overwrite the existing archive file if it exists
            Move-Item -Path $global:LogFilePath -Destination $archiveFilePath -Force
        }
    }


}

# Function to retrieve local drive information
function Get-LocalDrives {
    try {
        $localDrives = Get-WmiObject -Class Win32_LogicalDisk |
            Where-Object { $_.DriveType -eq 3 } | # 3 = Local disk
            Select-Object DeviceID, @{Name = "SizeGB"; Expression = { [math]::Round($_.Size / 1GB, 2) }}, @{Name = "FreeSpaceGB"; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) }}

        Write-Log -Message "Successfully retrieved local drives: $($localDrives | ConvertTo-Json -Depth 1)" -Type "INFO"
        return $localDrives
    } catch {
        Write-Log -Message "Error retrieving local drives: $_" -Type "ERROR"
        return $null
    }
}

# Function to get the currently logged-in user
function Get-LoggedInUser {
    try {
        $user = (Get-WmiObject -Query "SELECT * FROM Win32_ComputerSystem").UserName
        Write-Log -Message "Successfully retrieved logged-in user: $user" -Type "INFO"
        return $user
    } catch {
        Write-Log -Message "Error retrieving logged-in user: $_" -Type "ERROR"
        return $null
    }
}

# Function to retrieve TPM version
function Get-TPMVersion {
    try {
        $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
        if ($tpm) {
            $version = $tpm.SpecVersion
            Write-Log -Message "Successfully retrieved TPM version: $version" -Type "INFO"
            return $version
        } else {
            Write-Log -Message "No TPM detected" -Type "INFO"
            return "No TPM detected"
        }
    } catch {
        Write-Log -Message "Error retrieving TPM version: $_" -Type "ERROR"
        return $null
    }
}

# Function to retrieve installed software
function Get-InstalledSoftware {
    try {
        $software = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
            Where-Object { $_.DisplayName } | # Only include items with a DisplayName
            Select-Object DisplayName, DisplayVersion, Publisher |
            ForEach-Object {
                [PSCustomObject]@{
                    DisplayName    = ($_.DisplayName -replace '[^\x20-\x7E]', '').Trim()
                    DisplayVersion = ($_.DisplayVersion -as [string])
                    Publisher      = ($_.Publisher -replace '[^\x20-\x7E]', '').Trim()
                }
            }

        Write-Log -Message "Successfully retrieved installed software." -Type "INFO"
        return $software
    } catch {
        Write-Log -Message "Error retrieving installed software: $_" -Type "ERROR"
        return $null
    }
}

# Function to scan known paths for VM-related files
function Get-VMFilesOptimized {
    $knownPaths = @(
        "C:\ProgramData\Microsoft\Windows\Hyper-V",
        "C:\Users\Public\Documents\Hyper-V",
        "C:\Users\$env:USERNAME\Documents\Hyper-V",
        "C:\ProgramData\VMware",
        "C:\Users\$env:USERNAME\Documents\Virtual Machines",
        "C:\Users\Public\Documents\Virtual Machines",
        "C:\Users\$env:USERNAME\VirtualBox VMs",
        "C:\Users\Public\VirtualBox VMs",
        "C:\Users\$env:USERNAME\Documents\Parallels",
        "C:\Users\Public\Documents\Parallels",
        "C:\Users\$env:USERNAME\AppData\Local\Packages\Microsoft.Hyper-V\LocalState",
        "C:\VMs",
        "C:\Users\$env:USERNAME\Documents\My Virtual Machines",
        "C:\Users\Public\Documents\My Virtual Machines",
        "C:\Program Files (x86)\VMware\VMware Workstation",
        "C:\ProgramData\VMware Workstation",
        "C:\Users\$env:USERNAME\Virtual Machines"
    )
    
    $vmExtensions = @("*.vhdx", "*.vhd", "*.vmdk", "*.vdi", "*.qcow2", "*.raw", "*.img", "*.nvram", "*.vmem", "*.vmss", "*.vmsd", "*.vmsn", "*.vmx", "*.vmxf")
    
    $vmFiles = @()

    foreach ($path in $knownPaths) {
        if (Test-Path $path) {
            try {
                $files = Get-ChildItem -Path $path -Recurse -Include $vmExtensions -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Length -gt 1GB } |
                    Select-Object FullName, @{Name = 'SizeGB'; Expression = { [math]::Round($_.Length / 1GB, 2) }}
                $vmFiles += $files
                Write-Log -Message "Scanned path $path and found VM files: $($files | ConvertTo-Json -Depth 1)" -Type "INFO"
            } catch {
                Write-Log -Message "Error scanning path $($path): $_" -Type "ERROR"
            }
        } else {
            Write-Log -Message "Path $path does not exist" -Type "INFO"
        }
    }

    return $vmFiles
}


# Function to retrieve OS version
function Get-OSVersion {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $osVersion = $os.Caption + " " + $os.Version
        Write-Log -Message "Successfully retrieved OS version: $osVersion" -Type "INFO"
        return $osVersion
    } catch {
        Write-Log -Message "Error retrieving OS version: $_" -Type "ERROR"
        return $null
    }
}

# Function to retrieve domain information
function Get-DomainInfo {
    try {
        $domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
        if ($domain -and $domain -ne "WORKGROUP") {
            Write-Log -Message "Successfully retrieved domain name: $domain" -Type "INFO"
            return $domain
        } else {
            Write-Log -Message "Client is not part of a domain." -Type "INFO"
            return "Not in a domain"
        }
    } catch {
        Write-Log -Message "Error retrieving domain information: $_" -Type "ERROR"
        return $null
    }
}

# Function to check the recovery partition
function Check-RecoveryPartition {
    try {
        # Run reagentc /info and capture the output
        $output = & reagentc /info
        $winReStatusLine = $output | Select-String -Pattern 'WinRE-Status'
        $winReStatus = if ($winReStatusLine -match 'WinRE-Status:\s*(\S+)') { $matches[1] } else { "Unknown" }

        # Retrieve all partitions and filter for recovery partition based on GPT type
        $recoveryPartition = Get-Partition | Where-Object { $_.GptType -eq "{DE94BBA4-06D1-4D40-A16A-BFD50179D6AC}" }

        if ($recoveryPartition) {
            if ($winReStatus -eq "Enabled") {
                Write-Log -Message "Recovery partition exists and Windows RE is enabled." -Type "INFO"
                return "Recovery partition is present and Windows RE is enabled"
            } else {
                Write-Log -Message "Recovery partition exists but Windows RE is not enabled." -Type "INFO"
                return "Recovery partition is present but Windows RE is not enabled"
            }
        } else {
            Write-Log -Message "No recovery partition found." -Type "INFO"
            return "No recovery partition found"
        }
    } catch {
        Write-Log -Message "Error checking recovery partition: $_" -Type "ERROR"
        return "Error checking recovery partition"
    }
}

# Function to send data to the endpoint
function Send-DataToEndpoint {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Payload
    )

    try {
        $jsonPayload = $Payload | ConvertTo-Json -Depth 10
        Set-Content -Path $global:JsonFilePath -Value $jsonPayload -Encoding UTF8
        $response = Invoke-RestMethod -Uri $global:DataEndpointURL -Method Post -ContentType "application/json" -Body $jsonPayload
        Write-Log -Message "Successfully sent data to endpoint. Response: $response" -Type "INFO"
    } catch {
        Write-Log -Message "Error sending data to endpoint: $_" -Type "ERROR"
    }
}

# Function to retrieve system information
function Get-SystemInfo {
    try {
        $system = Get-CimInstance -ClassName Win32_ComputerSystem
        $bios = Get-CimInstance -ClassName Win32_BIOS
        
        $info = [PSCustomObject]@{
            Manufacturer = $system.Manufacturer
            Model = $system.Model
            SerialNumber = $bios.SerialNumber
        }
        
        Write-Log -Message "Successfully retrieved system information." -Type "INFO"
        return $info
    } catch {
        Write-Log -Message "Error retrieving system information: $_" -Type "ERROR"
        return $null
    }
}

# Main function to collect and send system and VM information
function Collect-AndSendSystemAndVMInfo {
    try {
        $result = [PSCustomObject]@{
            HardwareHash     = Get-HardwareHashInfo
            LocalDrives      = Get-LocalDrives
            SystemInfo       = Get-SystemInfo
            VMFiles          = Get-VMFilesOptimized
            LoggedInUser     = Get-LoggedInUser
            TPMVersion       = Get-TPMVersion
            InstalledSoftware = Get-InstalledSoftware
            OSVersion        = Get-OSVersion
            DomainInfo       = Get-DomainInfo
            RecoveryPartition = Check-RecoveryPartition
            ComputerName = $env:COMPUTERNAME
        }

        Write-Log -Message "Successfully collected system and VM information: $($result | ConvertTo-Json -Depth 1)" -Type "INFO"
        Send-DataToEndpoint -Payload $result
    } catch {
        Write-Log -Message "Error during data collection or sending: $_" -Type "ERROR"
    }
}

# Execute the script
try {
    Initialize-LogFile
    Collect-AndSendSystemAndVMInfo
} catch {
    Write-Log -Message "Unhandled error: $_" -Type "ERROR"
}

# SIG # Begin signature block
# MIIRawYJKoZIhvcNAQcCoIIRXDCCEVgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUeHhH2/fn4iTV2PksNtNUFsl9
# LKCggg3LMIIGvzCCBKegAwIBAgIRAIFOQhehKX/tWszUF/iRrXUwDQYJKoZIhvcN
# AQELBQAwUzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# KTAnBgNVBAMTIEdsb2JhbFNpZ24gQ29kZSBTaWduaW5nIFJvb3QgUjQ1MB4XDTI0
# MDYxOTAzMjUxMVoXDTM4MDcyODAwMDAwMFowWTELMAkGA1UEBhMCQkUxGTAXBgNV
# BAoTEEdsb2JhbFNpZ24gbnYtc2ExLzAtBgNVBAMTJkdsb2JhbFNpZ24gR0NDIFI0
# NSBDb2RlU2lnbmluZyBDQSAyMDIwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA1kJN+eNPxiP0bB2BpjD3SD3P0OWN5SAilgdENV0Gzw8dcGDmJlT6UyNg
# AqhfAgL3jsluPal4Bb2O9U8ZJJl8zxEWmx97a9Kje2hld6vYsSw/03IGMlxbrFBn
# LCVNVgY2/MFiTH19hhaVml1UulDQsH+iRBnp1m5sPhPCnxHUXzRbUWgxYwr4W9De
# ullfMa+JaDhAPgjoU2dOY7Yhju/djYVBVZ4cvDfclaDEcacfG6VJbgogWX6Jo1gV
# lwAlad/ewmpQZU5T+2uhnxgeig5fVF694FvP8gwE0t4IoRAm97Lzei7CjpbBP86l
# 2vRZKIw3ZaExlguOpHZ3FUmEZoIl50MKd1KxmVFC/6Gy3ZzS3BjZwYapQB1Bl2KG
# vKj/osdjFwb9Zno2lAEgiXgfkPR7qVJOak9UBiqAr57HUEL6ZQrjAfSxbqwOqOOB
# Gag4yJ4DKIakdKdHlX5yWip7FWocxGnmsL5AGZnL0n1VTiKcEOChW8OzLnqLxN7x
# Sx+MKHkwRX9sE7Y9LP8tSooq7CgPLcrUnJiKSm1aNiwv37rL4kFKCHcYiK01YZQS
# 86Ry6+42nqdRJ5E896IazPyH5ZfhUYdp6SLMg8C3D0VsB+FDT9SMSs7PY7G1pBB6
# +Q0MKLBrNP4haCdv7Pj6JoRbdULNiSZ5WZ1rq2NxYpAlDQgg8f8CAwEAAaOCAYYw
# ggGCMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdDgQWBBTas43AJJCja3fTDKBZ3SFnZHYLeDAfBgNV
# HSMEGDAWgBQfAL9GgAr8eDm3pbRD2VZQu86WOzCBkwYIKwYBBQUHAQEEgYYwgYMw
# OQYIKwYBBQUHMAGGLWh0dHA6Ly9vY3NwLmdsb2JhbHNpZ24uY29tL2NvZGVzaWdu
# aW5ncm9vdHI0NTBGBggrBgEFBQcwAoY6aHR0cDovL3NlY3VyZS5nbG9iYWxzaWdu
# LmNvbS9jYWNlcnQvY29kZXNpZ25pbmdyb290cjQ1LmNydDBBBgNVHR8EOjA4MDag
# NKAyhjBodHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL2NvZGVzaWduaW5ncm9vdHI0
# NS5jcmwwLgYDVR0gBCcwJTAIBgZngQwBBAEwCwYJKwYBBAGgMgEyMAwGCisGAQQB
# oDIKBAIwDQYJKoZIhvcNAQELBQADggIBADIQ5LwXpYMQQJ3Tqf0nz0VyqcUfSzNZ
# bywyMXlxhNY2Z9WrdPzU8gY6brXWy/FCg5a9fd6VLBrtauNBHKbIiTHCWWyJvCoj
# A1lQR0n9b1MOKijMSFTv8yMYW5I2TryjY9TD+wAPgNEgwsrllrrwmluqpCV6Gdv6
# 23tTT/m2o9lj1XVfAaUo27YYKRRleZzbtOuImBRTUGAxDGazUeNuySkmZPAU0XN4
# xISNPhSlklmreUFG6jTPgXZGOpF4GXO+/gb118GEOaBwTAo1AF7YKjAkHzJ3tuF8
# 37NGQeH6bY3j4wufL0DZpToNZMm+jNEayWUgOuIA+k56ITdBcJmdUB+Ze3WQdHNN
# RaVOWH/ddmqQWIlmk2Sj/lT3Tarr5SDuddeIsh0MPLyhkqBW5Ef8Zw/qeCnfj6PH
# 2eMxeKcLKZRrHCddISeH4qPvyECQLlwXKCXTAUQXq4DafJSoWyP8IJ6bkaGQ/7MN
# 5XJELEcV89SRcib58gXjAWf3abXeBbb+KJCMf6EpO7cs2mQiaZbE9NNXDSqFxrto
# aKyL8VJLZG6quLfsTRQc+qgUOM7sJevkYt01+bh7B10bQ2cCCGs9vyUjg4GWcwfu
# /lhaPDfaoNtf0pw6RpKcxCYcCTDaJeQOHZBz1B6HTmmEgZHNZX7nNfqDgGrTNB1G
# p3gIpngyJWZ6MIIHBDCCBOygAwIBAgIMCSJ712y7XnC1vLv+MA0GCSqGSIb3DQEB
# CwUAMFkxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMS8w
# LQYDVQQDEyZHbG9iYWxTaWduIEdDQyBSNDUgQ29kZVNpZ25pbmcgQ0EgMjAyMDAe
# Fw0yMjA5MjAwNzQwMzNaFw0yNTA5MjAwNzQwMzNaMHIxCzAJBgNVBAYTAkRFMRsw
# GQYDVQQIExJCYWRlbi1XdWVydHRlbWJlcmcxEjAQBgNVBAcTCUthcmxzcnVoZTEY
# MBYGA1UEChMPR0JTIEV1cm9wYSBHbWJIMRgwFgYDVQQDEw9HQlMgRXVyb3BhIEdt
# YkgwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDf7Rhn/PQRXvkf6mRA
# LqRDi3lshhIFKOnTt5OLs6d0/dOgh4z+iBuZp/E9oMGy0T6ppkQloLTWel3HG+pL
# 4G5z3x76fJjC+3skStkm5IzG37jt3e1/kt3kZzl6vvHCW+Sg9+7dRGN9nWAQI2lg
# bV0vE39x7GMpw9aP+uDPRwDRxUMnOm07xYz/GskYBWYazrLdWQ6p5RbAwx5iI7gQ
# z3PzwmQIFwYktcsQ3g4ZyP5cQisdKkAEg+5ltOhTvpRJWIjIQT9miDqjaqiJ/T5G
# EyeL14U2m48JJz4NhWQcGdtfcaCjFLkZWctMtI2WAsN2nNCP50lxyKBHHfzZgZx+
# 0bqg2lOCsZgbW0fKRrEw27QemaG85Qd7tzjKZkHEC1kg0MZabC/cwVG/fKuHF4R2
# SMwZOE8iXyvg9T8klu5Mn1S6NiDqfMVfYpdVos3qohBnaO9g4hEDhtkHx10vxWv0
# YmomFymV+LBO3DotBkz9rBppRXkIUYYrws1+40lDavLovit0qMxOGtz1RiAh7VpZ
# 84VPoQ+uWhrEcafm2yHEmLkzkfU8k9ftz67vML0YYXUiUwrHehG94gwuXVtg5ynr
# pDKucqoNd1fRGczRTFpEOOUuxrDsjf8C8lHuKb8Z/yEKcnBhSoOxo8UgLJM1D3Zb
# Jy96T4SKDlVwH+1v7VMaoBEE4wIDAQABo4IBsTCCAa0wDgYDVR0PAQH/BAQDAgeA
# MIGbBggrBgEFBQcBAQSBjjCBizBKBggrBgEFBQcwAoY+aHR0cDovL3NlY3VyZS5n
# bG9iYWxzaWduLmNvbS9jYWNlcnQvZ3NnY2NyNDVjb2Rlc2lnbmNhMjAyMC5jcnQw
# PQYIKwYBBQUHMAGGMWh0dHA6Ly9vY3NwLmdsb2JhbHNpZ24uY29tL2dzZ2NjcjQ1
# Y29kZXNpZ25jYTIwMjAwVgYDVR0gBE8wTTBBBgkrBgEEAaAyATIwNDAyBggrBgEF
# BQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCAYG
# Z4EMAQQBMAkGA1UdEwQCMAAwRQYDVR0fBD4wPDA6oDigNoY0aHR0cDovL2NybC5n
# bG9iYWxzaWduLmNvbS9nc2djY3I0NWNvZGVzaWduY2EyMDIwLmNybDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAfBgNVHSMEGDAWgBTas43AJJCja3fTDKBZ3SFnZHYLeDAd
# BgNVHQ4EFgQUf/q/LhujFmCeLAMoiKfqCjlplMgwDQYJKoZIhvcNAQELBQADggIB
# ABQEyHjMScj0zzXDRV4or10cfc557pcRB2wyYmp4kHBkzlV1Qa+kaM1gtmgtNe9V
# 0/JP9QFEVF9DET8tcwb4Vkz+06l/GfJTByiTicy4y7mW2xGwuW33D+hrrrlOCwuz
# eaAW6wUr0CwyfvfnHfkHhaSXYoOibEBgoXNqt0H24Oshdn0xUcZwzJ++g5Ml3GqF
# Tp2YDhBMmSpElXBsx+FOENgkcet5ikN9N0fbyD9iW0x7z8WtNBIMFgq+QqUoCl3F
# nafUJaQfIZqj/7FqX+yQpDIq3u9VkZSSEAnSZa/rx1a7gjt8UZc/eehbCxa5OH9D
# ldojxhcRH1KPgAIWiBK7JSu5q5Li+vZVXgdjoFjSeAgvenP7tWkaKOdSPO3PbTr5
# tYPHn/JkVpQtvgrD+2xrk6rYyQLO7KRuiYdCf8ziRn5t414dfWZeieA+XWy5HU/a
# PZkoO18/y0gxhb+GJ/RBfFESV53rbB95h34zrJjgu/cyv4UsVDsu9AEmhgAMuc5E
# A9tuGi96PFZHWHJZQBTovnLJbDVldPDCEf40/jLRsFxiRkAzcTN8wgFWBSAE//nC
# D0N6XObbfC8KBylZoq8gD4X0qGhCNfRvnqW7UaHihoz1wCLO34zkd/TSem6m4Cb/
# vUz0x0pJ4OqJx61UaFQg9NXerTWI/l8LhNddViatglQ0MYIDCjCCAwYCAQEwaTBZ
# MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEvMC0GA1UE
# AxMmR2xvYmFsU2lnbiBHQ0MgUjQ1IENvZGVTaWduaW5nIENBIDIwMjACDAkie9ds
# u15wtby7/jAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUtfK+1R+Rg1FSizggpUHGgwozgL4wDQYJ
# KoZIhvcNAQEBBQAEggIAkx7ThksOl/TZ3v+zITP5pe0PVZj+Fjj/kydIaX8rhMMh
# JP4tcqm2uEAt93nuC68I0RxagiURhIWX2NA8KGmWCprqHJzljHdh10hg/mP8t+st
# FKbMPmc5f7YiZTff9DyA6R3c6S9EMMBojDZjKO9uL1P2rQRAm2/mwN7PNly9sTlP
# zIKsdlCAModdasyaqkeHuKm461wcKGJgBlfwss8jh/HKecx/xLJL1bHEoCK52gSd
# 7925SN+0bZFRTurtbdnH55j6730eDzxj+21xu1+vIsKeR2u/4lomHx0Z1N4Mnf3s
# bL9zppnSeUw5Agr4e6m95RWWGTIgakRYbm/WBju0KDaHACMGEvd6ZH77iYmcxIxZ
# xnyTeSPAkSFUUex1lSaYZ/xHQ5iYTePDAg4OsGZf6GUx+E4W5AMECgsedblDgl5B
# KGZ+ShZACr49e/RbpY2zXdkXqeyhtPAgSs2rPYFLdJNMFMwqqTYA+D0l1/5mKjEG
# YJpxD+8y4KK0Aol4zD2RK5UID0lKZd+U6VNmN7P9nJClgWrTABfoPjvkkGT942Ib
# 6hgBgDYjI+To472Qf8ygSTFqQ3GYzTEt5KxPX/3Lv8ZQphQB151zxf6WvW4+HS5o
# B/ZK2RunjHA4QDEnydL2uUc+x71wL7nrzVmQBhAICEQTPvgtW6ElBe0QIewQ7LU=
# SIG # End signature block
