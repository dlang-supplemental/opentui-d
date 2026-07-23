<#
.SYNOPSIS
  Download OpenTUI native shared libraries from GitHub Releases into ./native.
#>
param(
    [string]$Version = "v0.4.5",
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $OutDir) {
    $OutDir = Join-Path (Split-Path -Parent $PSScriptRoot) "native"
}

function Get-HostRid {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    if ($arch -eq "x64") { $arch = "x64" }
    elseif ($arch -eq "arm64") { $arch = "arm64" }
    else { throw "Unsupported arch: $arch" }

    if ($env:OS -match "Windows") { return "windows-$arch" }
    if ($IsWindows) { return "windows-$arch" }
    if ($IsMacOS) { return "darwin-$arch" }
    if ($IsLinux) { return "linux-$arch" }

    # Windows PowerShell 5.1 fallback
    if ([System.Environment]::OSVersion.Platform -eq "Win32NT") { return "windows-$arch" }
    throw "Unsupported OS"
}

$rid = Get-HostRid
$zip = "opentui-native-$Version-$rid.zip"
$url = "https://github.com/anomalyco/opentui/releases/download/$Version/$zip"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$dest = Join-Path $OutDir $rid
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$zipPath = Join-Path $OutDir $zip
Write-Host "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $zipPath
if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
    Expand-Archive -Path $zipPath -DestinationPath $dest -Force
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $dest, $true)
}
Remove-Item $zipPath
Write-Host "Extracted to $dest"
Get-ChildItem $dest | Format-Table Name, Length
