<#
.SYNOPSIS
    Checks automatic services on local or remote servers and reports those not running.
.DESCRIPTION
    This interactive script allows you to check service status on:
    1. Local server
    2. Manually input servers
    3. Servers from a serverlist.txt file
    Then provides options to save the output to a file.
.NOTES
    File Name      : ServiceStatusChecker.ps1
    Author         : Your Name
    Prerequisite   : PowerShell 5.1 or later
#>

# Create Output directory if it doesn't exist
$outputDir = Join-Path -Path $PSScriptRoot -ChildPath "Output"
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

function Get-ServiceStatus {
    param (
        [string[]]$ComputerNames
    )

    $results = @()

    foreach ($computer in $ComputerNames) {
        try {
            # Get all automatic services (including delayed start)
            $services = Get-Service -ComputerName $computer -ErrorAction Stop | 
                        Where-Object { $_.StartType -eq "Automatic" -or $_.StartType -eq "AutomaticDelayedStart" }

            foreach ($service in $services) {
                if ($service.Status -ne "Running") {
                    $result = [PSCustomObject]@{
                        ServerName      = $computer
                        ServiceName     = $service.Name
                        DisplayName     = $service.DisplayName
                        Status          = $service.Status
                        StartType       = $service.StartType
                        CheckTimestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                    $results += $result
                }
            }
        }
        catch {
            $result = [PSCustomObject]@{
                ServerName      = $computer
                ServiceName     = "ERROR"
                DisplayName     = "Could not connect to server or retrieve services"
                Status          = "N/A"
                StartType       = "N/A"
                CheckTimestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $results += $result
        }
    }

    return $results
}

function Show-MainMenu {
    Clear-Host
    Write-Host "============================================="
    Write-Host "         Service Status Checker" -ForegroundColor Cyan
    Write-Host "============================================="
    Write-Host "1. Check services on local server"
    Write-Host "2. Input servers manually"
    Write-Host "3. Use servers from serverlist.txt"
    Write-Host "4. Exit"
    Write-Host "============================================="
}

function Show-ResultsMenu {
    param (
        [object]$Results
    )

    # Display results in console
    if ($Results.Count -eq 0) {
        Write-Host "`nNo automatic services found that are not running." -ForegroundColor Green
    }
    else {
        $Results | Format-Table -AutoSize
        Write-Host "`nFound $($Results.Count) automatic services not running." -ForegroundColor Yellow
    }

    # Show save options
    Write-Host "`n============================================="
    Write-Host "         Output Options" -ForegroundColor Cyan
    Write-Host "============================================="
    Write-Host "1. Save results to TXT file"
    Write-Host "2. Save results to CSV file"
    Write-Host "3. Return to main menu"
    Write-Host "4. Exit"
    Write-Host "============================================="

    $choice = Read-Host "Please select an option (1-4)"
    switch ($choice) {
        "1" {
            $timestamp = Get-Date -Format "yyMMdd-HHmmss"
            $outputFile = Join-Path -Path $outputDir -ChildPath "ServiceStatus_$timestamp.txt"
            $Results | Out-File -FilePath $outputFile
            Write-Host "Results saved to $outputFile" -ForegroundColor Green
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
        "2" {
            $timestamp = Get-Date -Format "yyMMdd-HHmmss"
            $outputFile = Join-Path -Path $outputDir -ChildPath "ServiceStatus_$timestamp.csv"
            $Results | Export-Csv -Path $outputFile -NoTypeInformation
            Write-Host "Results saved to $outputFile" -ForegroundColor Green
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
        "3" { Show-MainMenu }
        "4" { exit }
        default {
            Write-Host "Invalid option. Returning to main menu." -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
    }
}

# Main script execution
while ($true) {
    Show-MainMenu
    $choice = Read-Host "Please select an option (1-4)"

    switch ($choice) {
        "1" {
            # Local server
            $results = Get-ServiceStatus -ComputerNames $env:COMPUTERNAME
            Show-ResultsMenu -Results $results
        }
        "2" {
            # Manual input
            $servers = Read-Host "Enter server names (comma separated)"
            $serverList = $servers -split ',' | ForEach-Object { $_.Trim() }
            $results = Get-ServiceStatus -ComputerNames $serverList
            Show-ResultsMenu -Results $results
        }
        "3" {
            # From serverlist.txt
            $serverListFile = Join-Path -Path $PSScriptRoot -ChildPath "serverlist.txt"
            if (Test-Path -Path $serverListFile) {
                $serverList = Get-Content -Path $serverListFile | Where-Object { $_ -ne "" }
                if ($serverList.Count -gt 0) {
                    $results = Get-ServiceStatus -ComputerNames $serverList
                    Show-ResultsMenu -Results $results
                }
                else {
                    Write-Host "serverlist.txt is empty." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            else {
                Write-Host "serverlist.txt not found in script directory." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        "4" { exit }
        default {
            Write-Host "Invalid option. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}