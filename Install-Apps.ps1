# settings
$ProgressPreferenceHidden = "SilentlyContinue";
$ProgressPreferenceActive = "Continue";

# parameters

$appxFile = "Microsoft.DesktopAppInstaller.appxbundle";
$sha256File = "SHA256.txt";
$importFile = "import.json";

#region Functions
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
    $wingetLatestReleaseUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest";

    # disable progress bar for downloadable assets
    $ProgressPreference = $ProgressPreferenceHidden;

    # send a request for the latest release assets
    $response = Invoke-WebRequest -Uri $wingetLatestReleaseUrl -Headers @{"accept"="application/json"};

    # check if response is ok
    if ($response.StatusCode -ne 200) {
        Write-Host "[ERROR] WinGet can't be downloaded due to network error. Status code: $($response.StatusCode)" -ForegroundColor Red;
        break;
    }

    #check if response body is ok
    if ([string]::IsNullOrEmpty($response.Content)) {
        Write-Host "[ERROR] WinGet can't be downloaded. The response body is empty" -ForegroundColor Red;
        break;
    }

    # filter for assets in the response
    $content = $response.Content | ConvertFrom-Json;

    $assetUrls = $content.assets.browser_download_url;

    [string]$appxFileUrl = ($assetUrls | Select-String -Pattern ".appxbundle" )[0];
    [string]$sha256FileUrl = ($assetUrls | Select-String -Pattern ".txt" )[0];

    Write-Host 'WinGet assets found, downloading...' -ForegroundColor Green;

    # download assets
    $appxFilePath = "$($PSScriptRoot)\$($appxFile)";
    $sha256FilePath = "$($PSScriptRoot)\$($sha256File)";

    Invoke-WebRequest $appxFileUrl -OutFile $appxFilePath;
    Invoke-WebRequest $sha256FileUrl -OutFile $sha256FilePath;

    Write-Host 'WinGet assets downloaded, installing...' -ForegroundColor Green;

    # check SHA256 checksum
    $sha256FileContent = Get-Content -Path $sha256FilePath;
    $appxFileSha256 = Get-FileHash $appxFilePath -Algorithm SHA256;

    if ($appxFileSha256.Hash.ToLower() -ne $sha256FileContent)
    {
        Write-Host "[ERROR] Can't install: appxbundle checksum doesn't match published." -ForegroundColor Red;
        Write-Host "Expected: $($sha256FileContent)" -ForegroundColor Yellow;
        Write-Host "  Actual: $($appxFileSha256.Hash.ToLower())" -ForegroundColor Red;
        break;
    }

    # installing
    $ProgressPreference = $ProgressPreferenceActive;
    Add-AppxPackage -Path $appxFilePath;

    Write-Host 'WinGet restored!' -ForegroundColor Green;
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
    Write-Host 'Installing applications...' -ForegroundColor Green;
    winget import -i "$($PSScriptRoot)\$($importFile)";
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
    winget uninstall --id Microsoft.PowerToys;
    winget uninstall --id Microsoft.WindowsTerminal;
    Get-AppXPackage Microsoft.DesktopAppInstaller | Remove-AppXPackage;
}

function Run {
    Set-Location $PSScriptRoot;
    Restore-WinGet;
    Install-Apps;
    # Remove-WinGet;

    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}

#endregion

Run;