# settings
$ProgressPreferenceHidden = "SilentlyContinue";
$ProgressPreferenceActive = "Continue";

# disable progress bar for downloadable assets
$ProgressPreference = $ProgressPreferenceHidden;

# parameters
$appxFile = "Microsoft.DesktopAppInstaller.appxbundle";
$sha256File = "SHA256.txt";
$importFile = "import.json";
$runtimePackage = "Microsoft.VCLibs.140.00.UWPDesktop";

# urls
$runtimePackageUrl = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
$wingetLatestReleaseUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest";

# console messages
$message = [PSCustomObject]@{

    #processing
    RuntimeUpdating = "Updating runtime..."
    WingetDownloading = "WinGet assets found, downloading..."
    WingetInstalling = "Installing WinGet..."
    AppsInstalling = "Installing applications..."

    #success
    RuntimeUpdated = "[OK] Runtime updated"
    WingetDownloaded = "[OK] WinGet assets downloaded"
    WingetInstalled = "[OK] WinGet restored"
    AppsInstalling = "[OK] Applications installed"

    #errors
    NetworkError = "[ERROR] WinGet can't be downloaded due to network error. Status code: {0}"
    ResponseEmptyError = "[ERROR] WinGet can't be downloaded. The response body is empty"
    ChecksumError = "[ERROR] Can't install: appxbundle checksum doesn't match published."
}

#region Functions

function Restore-Runtime {
    <#
    .NAME
        Restore-Runtime
    .SYNOPSIS
        Updates the runtime for appx bundle installation
    .DESCRIPTION
        Downloads and installs C++ Runtime framework packages 
    .EXAMPLE
        Restore-Runtime
    #>

    Write-Host $message.RuntimeUpdating;
    Add-AppxPackage -Path $runtimePackageUrl;
    Write-Host $message.RuntimeUpdated -ForegroundColor Green;
}

function Restore-WinGet {
    <#
    .NAME
        Restore-WinGet
    .SYNOPSIS
        Restores winget cli
    .DESCRIPTION
        Downloads the latest winget release, verifies checksum and installs/updates winget msix bundle
    .EXAMPLE
        Restore-WinGet
    #>

    # send a request for the latest release assets
    $response = Invoke-WebRequest -Uri $wingetLatestReleaseUrl -Headers @{"accept"="application/json"} -UseBasicParsing;

    # check if response is ok
    if ($response.StatusCode -ne 200) {
        Write-Host ($message.NetworkError -f $response.StatusCode) -ForegroundColor Red;
        break;
    }

    #check if response body is ok
    if ([string]::IsNullOrEmpty($response.Content)) {
        Write-Host $message.ResponseEmptyError -ForegroundColor Red;
        break;
    }

    # filter for assets in the response
    $content = $response.Content | ConvertFrom-Json;

    $assetUrls = $content.assets.browser_download_url;

    [string]$appxFileUrl = ($assetUrls | Select-String -Pattern ".appxbundle" )[0];
    [string]$sha256FileUrl = ($assetUrls | Select-String -Pattern ".txt" )[0];

    Write-Host $message.WingetDownloading;

    # download assets
    $appxFilePath = "$($PSScriptRoot)\$($appxFile)";
    $sha256FilePath = "$($PSScriptRoot)\$($sha256File)";

    Invoke-WebRequest $appxFileUrl -OutFile $appxFilePath;
    Invoke-WebRequest $sha256FileUrl -OutFile $sha256FilePath;

    Write-Host $message.WingetDownloaded -ForegroundColor Green;
    Write-Host $message.WingetInstalling;

    # check SHA256 checksum
    $sha256FileContent = Get-Content -Path $sha256FilePath;
    $appxFileSha256 = Get-FileHash $appxFilePath -Algorithm SHA256;

    if ($appxFileSha256.Hash.ToLower() -ne $sha256FileContent)
    {
        Write-Host $message.ChecksumError -ForegroundColor Red;
        Write-Host "Expected: $($sha256FileContent)" -ForegroundColor Yellow;
        Write-Host "  Actual: $($appxFileSha256.Hash.ToLower())" -ForegroundColor Red;
        break;
    }

    # installing
    Add-AppxPackage -Path $appxFilePath;

    Write-Host $message.WingetInstalled -ForegroundColor Green;
    $ProgressPreference = $ProgressPreferenceActive;
}

# TODO: Add parameter to choose *.import.json file
function Install-Apps {
    <#
    .NAME
        Install-Apps
    .SYNOPSIS
        Installs a list of applications
    .DESCRIPTION
        Installs a list of applications described in "import.json" file
    .EXAMPLE
        Install-Apps
    #>
    Write-Host $message.AppsInstalling;
    winget import -i "$($PSScriptRoot)\$($importFile)";
    Write-Host $message.AppsInstalled;
}

function Remove-WinGet {
    <#
    .NAME
        Remove-WinGet
    .SYNOPSIS
        Removes winget cli 
    .DESCRIPTION
        Uninstalls winget msix application
    .EXAMPLE
        Remove-WinGet
    #>
    # winget uninstall --id Microsoft.PowerToys;
    # winget uninstall --id Microsoft.WindowsTerminal;
    Get-AppXPackage Microsoft.DesktopAppInstaller | Remove-AppXPackage;
}

function Run {
    Set-Location $PSScriptRoot;
    Restore-Runtime;
    Restore-WinGet;
    Install-Apps;
    # Remove-WinGet;

    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

#endregion

Run;