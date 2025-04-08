<#
.SYNOPSIS
    Cleans up Chrome cache for all user profiles on multiple remote servers.
.DESCRIPTION
    This script reads a list of servers from serverlist.txt and cleans the Chrome cache
    (AppData\Local\Google\Chrome\User Data\Default\Cache) for all users on each server.
.NOTES
    File Name      : Clean-ChromeCacheMultiServer.ps1
    Requires Admin : Yes (for remote administration)
    PSDrive        : Creates a temporary PSDrive for each server
#>

# Require elevation if not running as admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires administrator privileges. Restarting with elevated permissions..."
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Configuration
$scriptRoot = $PSScriptRoot
$serverListPath = Join-Path -Path $scriptRoot -ChildPath "serverlist.txt"
$logFile = Join-Path -Path $scriptRoot -ChildPath "ChromeCacheCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Check if serverlist.txt exists
if (-not (Test-Path $serverListPath)) {
    Write-Warning "Server list not found at $serverListPath"
    Write-Host "Creating a sample serverlist.txt file..."
    @"
# List target servers below (one per line)
server1.domain.com
server2.domain.com
192.168.1.100
"@ | Out-File $serverListPath -Encoding utf8
    Write-Host "Sample serverlist.txt created. Please edit it with your target servers and run the script again." -ForegroundColor Yellow
    exit
}

# Get list of servers (ignore commented lines)
$servers = Get-Content $serverListPath | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' }

if (-not $servers) {
    Write-Warning "No valid servers found in $serverListPath"
    exit
}

# Start logging
Start-Transcript -Path $logFile -Append

Write-Host "Starting Chrome cache cleanup across $(@($servers).Count) servers..." -ForegroundColor Cyan

foreach ($server in $servers) {
    Write-Host "`nProcessing server: $server" -ForegroundColor Green
    
    try {
        # Test connection first
        if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
            Write-Warning "Server $server is not reachable"
            continue
        }

        # Create temporary PSDrive for admin share
        $driveName = "Temp$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $remotePath = "\\$server\c$\Users"
        
        try {
            New-PSDrive -Name $driveName -PSProvider FileSystem -Root $remotePath -ErrorAction Stop | Out-Null
            Write-Host "Connected to $server via admin share"

            # Get all user profiles
            $userProfiles = Get-ChildItem "$driveName`:\" -Directory | Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }

            foreach ($user in $userProfiles) {
                $username = $user.Name
                $cachePath = "$driveName`:\$username\AppData\Local\Google\Chrome\User Data\Default\Cache"
                
                if (Test-Path $cachePath) {
                    try {
                        Write-Host "Cleaning Chrome cache for $username on $server"
                        
                        # Delete all files in the cache directory
                        Remove-Item "$cachePath\*" -Force -Recurse -ErrorAction Stop
                        
                        Write-Host "Successfully cleaned Chrome cache for $username on $server" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "Failed to clean Chrome cache for $username on $server. Error: $_"
                    }
                }
                else {
                    Write-Host "Chrome cache directory not found for $username on $server" -ForegroundColor Yellow
                }
            }
        }
        finally {
            # Clean up PSDrive
            if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
                Remove-PSDrive -Name $driveName -Force
            }
        }
    }
    catch {
        Write-Warning "Error processing server $server. $_"
    }
}

Stop-Transcript
Write-Host "`nChrome cache cleanup completed for all servers." -ForegroundColor Cyan
Write-Host "Log file created at: $logFile" -ForegroundColor Yellow