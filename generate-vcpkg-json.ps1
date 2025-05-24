$vcpkgExe = Join-Path $PSScriptRoot "vcpkg.exe"

if (-not (Test-Path $vcpkgExe)) {
    Write-Error "vcpkg.exe not found in $PSScriptRoot"
    exit 1
}

if (Test-Path (Join-Path $PSScriptRoot "vcpkg.json")) {
    Write-Error "Please remove or rename existing vcpkg.json before running this script."
    exit 1
}

$installedPackages = & $vcpkgExe list

if (-Not $installedPackages -or $installedPackages -match "No packages are installed") {
    Write-Error "No packages found or vcpkg.json might exist. Ensure classic mode."
    exit 1
}

$dependenciesMap = @{}

foreach ($line in $installedPackages) {
    # Proper regex to clearly separate package name, optional feature, triplet, and version
    if ($line -match "^([^:\[\]]+)(?:\[([^\]]+)\])?:([^\s]+)\s+([^\s]+)") {
        $pkgName = $matches[1]
        $feature = $matches[2]  # Can be null
        $triplet = $matches[3]
        $version = $matches[4]

        # Exclude internal vcpkg tools
        if ($pkgName -like "vcpkg-*") { continue }

        # Key by package and triplet
        $key = "$pkgName`:$triplet"

        # Create new dependency entry if not exists
        if (-not $dependenciesMap.ContainsKey($key)) {
            $dependenciesMap[$key] = @{
                name = $pkgName
                version = "=$version"
                "default-features" = $true
                triplet = $triplet
                features = @()
            }
        }

        # If feature exists, add it as array entry
        if ($feature) {
            $dependenciesMap[$key].features += $feature
            $dependenciesMap[$key]."default-features" = $false
        }
    }
}

$dependencies = $dependenciesMap.Values | Sort-Object name

# Fix the features arrays and remove empty arrays
foreach ($dep in $dependencies) {
    if ($dep.features.Count -eq 0) {
        $dep.Remove('features')
    } else {
        # Ensure distinct, sorted array of features
        $dep.features = $dep.features | Sort-Object -Unique
    }
}

$manifest = @{
    name = "wse-3rd-parties"
    version = "0.1.0"
    dependencies = $dependencies
}

$manifestPath = Join-Path $PSScriptRoot "vcpkg.json"
$manifest | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $manifestPath

Write-Host "Generated vcpkg.json at '$manifestPath' with $($dependencies.Count) dependencies."
