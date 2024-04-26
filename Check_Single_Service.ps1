# Ask the user if they want to specify servers manually or use serverlist.txt
$useServerList = Read-Host "Do you want to use a server list (serverlist.txt) or specify servers manually? (serverlist/manual) "

# If they chose to use the server list
if ($useServerList -eq "serverlist") {
    # Read the server list from the file
    $servers = Get-Content -Path "serverlist.txt"
}
else {
    # Otherwise, ask the user to specify servers manually
    $servers = Read-Host "Enter a space-separated list of servers"
    $servers = $servers -split " "
}

# Ask the user to specify the service to check
$serviceName = Read-Host "Enter the name of the service to check"

# Check if the service is running on each server
foreach ($server in $servers) {
    # Test if the server is online
    if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
        # Check if the service is running
        $service = Get-Service -ComputerName $server -Name $serviceName -ErrorAction SilentlyContinue

        if ($service) {
            if ($service.Status -eq 'Running') {
                Write-Host "Service '$serviceName' is running on server '$server'" -ForegroundColor Green
            }
            else {
                Write-Host "Service '$serviceName' is not running on server '$server'" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Service '$serviceName' does not exist on server '$server'" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Server '$server' is offline" -ForegroundColor Red
    }
}