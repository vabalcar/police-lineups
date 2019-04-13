Write-Host 'Installing server dependencies...'
$packageInfo = Get-Content package-info.json | ConvertFrom-Json
$venvName = $packageInfo.venvName

Write-Host 'Checking python environment...'
$virtualenvInstalled = $false
$pipLsOutFile = 'pip-ls.out'
& 'pip' 'list' '--format' 'json' > $pipLsOutFile 
$pipLs = Get-Content $pipLsOutFile | ConvertFrom-Json
foreach($package in $pipLs) {
    if ($package.name -eq 'virtualenv') {
        $virtualenvInstalled = $true
        break
    }
}
Remove-Item -Path $pipLsOutFile

if (!$virtualenvInstalled) {
    Write-Host 'Installing virtualenv...'
    $pipIOutFile = 'pip-i-virtualenv.out'
    New-Item -Force -Path "." -Type "File" -Name $pipIOutFile | Out-Null
    $virtualEnvInstallScript = (Join-Path . install-virtualenv.ps1)
    Start-Process -Wait -Verb RunAs -Path 'pwsh' -Args '-NoLogo', '-Command', "& $virtualEnvInstallScript -OutputFile $pipIOutFile"
    Get-Content $pipIOutFile
    Remove-Item -Path $pipIOutFile
} else {
    Write-Host 'Virtualenv is installed.'
}

if(!(Test-Path -PathType Container $venvName)) {
    Write-Host "Creating virtual environment ""$venvName""..."
    & 'virtualenv' $venvName
} else {
    "Virtual environment ""$venvName"" exists."
}

$executionPolicy = Get-ExecutionPolicy
if(("$executionPolicy" -eq 'Restricted') -or ("$executionPolicy" -eq 'AllSigned')) {
    $executionPolicySetter = (Join-Path . 'update-pwsh-execution-policy.ps1')
    Start-Process -Wait -Verb RunAs -Path 'pwsh' -Args '-NoLogo', '-Command', "& $executionPolicySetter"
}
Write-Host "PowerShell execution policy is set to ""$executionPolicy""."

Write-Host 'Installing local dependencies...'
if ($IsWindows) {
    & (Join-Path $venvName 'Scripts' 'activate.ps1')
} else {
    & 'source' (Join-Path $venvName 'bin' 'activate')
}
$deps = $packageInfo.dependencies
foreach ($dep in $deps) {
    & 'pip' 'install' $dep
}
& deactivate
Write-Host 'done.'