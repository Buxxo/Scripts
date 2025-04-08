<#
.SYNOPSIS
    Cleans up Chrome cache for all user profiles on a server.
.DESCRIPTION
    This script finds all user profiles on the server and deletes the Chrome cache
    located in AppData\Local\Google\Chrome\User Data\Default\Cache for each user.
.NOTES
    File Name      : Clean-ChromeCacheAllUsers.ps1
    Requires Admin : Yes (to access other users' AppData folders)
#>

# Require elevation if not running as admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires administrator privileges. Restarting with elevated permissions..."
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Get all user profiles on the system
$userProfiles = Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }

foreach ($user in $userProfiles) {
    $username = $user.Name
    $cachePath = "C:\Users\$username\AppData\Local\Google\Chrome\User Data\Default\Cache"
    
    # Check if the cache directory exists
    if (Test-Path $cachePath) {
        try {
            Write-Host "Cleaning Chrome cache for user: $username"
            
            # Delete all files in the cache directory
            Remove-Item "$cachePath\*" -Force -Recurse -ErrorAction Stop
            
            Write-Host "Successfully cleaned Chrome cache for $username" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to clean Chrome cache for $username. Error: $_"
        }
    }
    else {
        Write-Host "Chrome cache directory not found for $username" -ForegroundColor Yellow
    }
}

Write-Host "Chrome cache cleanup completed for all users." -ForegroundColor Cyan