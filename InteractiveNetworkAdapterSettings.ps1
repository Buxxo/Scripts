function Show-NetworkAdapters {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object Name, InterfaceAlias, InterfaceIndex, Status
    if (-not $adapters) {
        Write-Host "No active network adapters found!" -ForegroundColor Red
        return $null
    }
    
    Write-Host "`nAvailable Network Adapters:" -ForegroundColor Green
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        Write-Host "$($i+1). $($adapters[$i].Name) (Index: $($adapters[$i].InterfaceIndex))" -ForegroundColor Cyan
    }
    
    return $adapters
}

function Edit-IPSettings {
    param (
        [int]$InterfaceIndex,
        [string]$InterfaceName
    )
    
    Write-Host "`nCurrent IP Configuration for $($InterfaceName):" -ForegroundColor Yellow
    $currentIP = Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 | Select-Object IPAddress, PrefixLength
    $currentGateway = Get-NetRoute -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } | Select-Object NextHop
    
    if ($currentIP) {
        Write-Host "IP Address: $($currentIP.IPAddress)/$($currentIP.PrefixLength)"
        Write-Host "Gateway: $($currentGateway.NextHop)"
    } else {
        Write-Host "No IPv4 address configured" -ForegroundColor Red
    }
    
    $ipAddress = Read-Host "`nEnter new IP Address (leave blank to keep current)"
    if ($ipAddress -eq "") {
        $ipAddress = $currentIP.IPAddress
    }
    
    $prefixLength = Read-Host "Enter new Prefix Length (e.g., 24 for 255.255.255.0, leave blank to keep current)"
    if ($prefixLength -eq "") {
        $prefixLength = $currentIP.PrefixLength
    }
    
    $gateway = Read-Host "Enter new Gateway (leave blank to keep current)"
    if ($gateway -eq "") {
        $gateway = $currentGateway.NextHop
    }
    
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    Remove-NetRoute -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    
    # Set new IP configuration
    try {
        New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $ipAddress -PrefixLength $prefixLength -DefaultGateway $gateway -ErrorAction Stop
        Write-Host "IP configuration updated successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error updating IP configuration: $_" -ForegroundColor Red
    }
}

function Edit-DNSSettings {
    param (
        [int]$InterfaceIndex,
        [string]$InterfaceName
    )
    
    Write-Host "`nCurrent DNS Configuration for $($InterfaceName):" -ForegroundColor Yellow
    $currentDNS = Get-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses
    
    if ($currentDNS) {
        Write-Host "DNS Servers: $($currentDNS -join ', ')"
    } else {
        Write-Host "No DNS servers configured" -ForegroundColor Red
    }
    
    Write-Host "`nEnter DNS servers (separate multiple servers with commas)"
    Write-Host "Example: 8.8.8.8, 8.8.4.4"
    $dnsInput = Read-Host "DNS Servers (leave blank to keep current)"
    
    if ($dnsInput -ne "") {
        $dnsServers = $dnsInput -split ',' | ForEach-Object { $_.Trim() }
        
        try {
            Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses $dnsServers -ErrorAction Stop
            Write-Host "DNS configuration updated successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Error updating DNS configuration: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "DNS configuration unchanged"
    }
}

function Show-MainMenu {
    Clear-Host
    Write-Host "`nNetwork Adapter Configuration Tool`n" -ForegroundColor Magenta
    Write-Host "1. Select Network Adapter to Configure"
    Write-Host "2. Exit`n"
}

function Show-AdapterMenu {
    param (
        [string]$AdapterName
    )
    
    Clear-Host
    Write-Host "`nConfigure $($AdapterName)`n" -ForegroundColor Magenta
    Write-Host "1. Change IP Address/Subnet/Gateway"
    Write-Host "2. Change DNS Settings"
    Write-Host "3. Back to Adapter Selection"
    Write-Host "4. Exit`n"
}

# Main script execution
while ($true) {
    Show-MainMenu
    $mainChoice = Read-Host "Select an option"
    
    switch ($mainChoice) {
        '1' {
            $adapters = Show-NetworkAdapters
            if (-not $adapters) {
                Pause
                continue
            }
            
            $adapterChoice = Read-Host "`nSelect adapter to configure (1-$($adapters.Count))"
            if (-not ($adapterChoice -match "^\d+$" -and [int]$adapterChoice -ge 1 -and [int]$adapterChoice -le $adapters.Count)) {
                Write-Host "Invalid selection!" -ForegroundColor Red
                Pause
                continue
            }
            
            $selectedAdapter = $adapters[[int]$adapterChoice - 1]
            
            while ($true) {
                Show-AdapterMenu -AdapterName $selectedAdapter.Name
                $adapterMenuChoice = Read-Host "Select an option"
                
                switch ($adapterMenuChoice) {
                    '1' { Edit-IPSettings -InterfaceIndex $selectedAdapter.InterfaceIndex -InterfaceName $selectedAdapter.Name }
                    '2' { Edit-DNSSettings -InterfaceIndex $selectedAdapter.InterfaceIndex -InterfaceName $selectedAdapter.Name }
                    '3' { break }
                    '4' { exit }
                    default {
                        Write-Host "Invalid selection!" -ForegroundColor Red
                    }
                }
                
                if ($adapterMenuChoice -eq '3') {
                    break
                }
                
                Pause
            }
        }
        '2' { exit }
        default {
            Write-Host "Invalid selection!" -ForegroundColor Red
            Pause
        }
    }
}

function Pause {
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}