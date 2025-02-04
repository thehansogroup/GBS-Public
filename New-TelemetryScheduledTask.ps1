# Define constants
$logFile = "C:\ProgramData\New-TelemetryScheduledTask.log"
$scriptUrl = "https://raw.githubusercontent.com/thehansogroup/GBS-Public/refs/heads/main/Invoke-SendClientTelemetryV002.ps1"
$scriptPath = "C:\ProgramData\Invoke-SendClientTelemetryV002.ps1"
$taskName = "TelemetryTask"

# Function to log messages
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $logFile
}

# Start logging
Write-Log "New-TelemetryScheduledTask script started."

try {
    # Ensure the ProgramData folder is writable
    if (!(Test-Path "C:\ProgramData")) {
        Write-Log "ERROR: ProgramData directory not found!"
        exit 1
    }

    # Download Invoke-SendClientTelemetry.ps1
    Write-Log "Downloading Invoke-SendClientTelemetry.ps1 from $scriptUrl..."
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -ErrorAction Stop
    Write-Log "Downloaded Invoke-SendClientTelemetry.ps1 successfully to $scriptPath."

    # Define scheduled task action
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""

    # Define trigger: Run 5 minutes after user logon
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = "PT5M"  # 5-minute delay

    # Set task to run as SYSTEM
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

    # Task settings
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $taskPrincipal -Settings $taskSettings -Force
    Write-Log "Scheduled task '$taskName' created successfully. Runs as SYSTEM, 5 minutes after user login."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
}

Write-Log "New-TelemetryScheduledTask script finished."

# SIG # Begin signature block
# MIIRawYJKoZIhvcNAQcCoIIRXDCCEVgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU17jno364k8A8hswIsW7b0nst
# f26ggg3LMIIGvzCCBKegAwIBAgIRAIFOQhehKX/tWszUF/iRrXUwDQYJKoZIhvcN
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
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUzKKFguww1fmMGPYSNtfwoSSnA4YwDQYJ
# KoZIhvcNAQEBBQAEggIAPej4KN3k4RH/6AW6x02jKNa3Z5dTcI6SUa73pj9CUwtY
# BiquRde5P6x8j4QNx+wP6TKigsCypnnKuKzZkYaLswPpfNEXm/aegSPSYKZOVc3P
# EmG3siz4CveHJlqLTZ8fa41Kauo8ZPzaCbZesm69+frWDnqH9u4Zxui/rD+xpqMT
# 7MHhk7aSp8dicJn2/kVmclZjQT3ZAXxztpDHsI19/B1cnhhT0nCbo4l3DdqT6hvg
# ofX2xX1+Z3BfZjE3DTNPTFxGoq2u72RC4OiCSSZtZk8sQHLQDrVcmY1wxbwTXF2T
# Fpzo/ZxwjGvjdTKYLezl5TlH3E1jo44muMfJ0s6rBMG9y5Mo4BnUy7edBkrXdNsP
# 5Omgp3b3nMvbo9hw+hZEEpIJUZhQjQHaYKcomCOueJrisM05zRnxq6QZHBCF/ajW
# H4EUyybEzKlMGyA92sYHnjyuJ6zjGtMep6hkU87aTsq0huoKUPUiLDO0nqT74iKv
# w+33kp6b6eeKQAQFhuQSCipH6UgW2WGkzzEkSi3norEjLXBZZWpP2lkZWEEvNEMP
# 0CwPPBHYbyuGjwXXs0FEEHwVHZ/E3XrBeLUU36FHUMGCAY2QwtGjtRZLkQeq/1U/
# WXlrJT7anZqmpl94GejuTr+x99xTh1J0wfjkCYfooISgnxuD9jH5mm/AKF5TdpU=
# SIG # End signature block
