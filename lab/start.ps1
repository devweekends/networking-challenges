# Start the lab from Windows PowerShell. Run it on your computer (not inside the lab):
#   .\lab\start.ps1                 normal start
#   .\lab\start.ps1 -NoPrivilege    start WITHOUT --privileged, to see the checker fail on purpose
param(
    [switch]$NoPrivilege
)

$ErrorActionPreference = 'Continue'

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is not running. Start Docker Desktop, wait until it says it is running, then run this again."
    exit 1
}

# Build the image once. It stays on your computer after that.
docker image inspect networking-lab *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Building the lab image. This happens once."
    Push-Location $Repo
    docker build -t networking-lab lab/
    $buildCode = $LASTEXITCODE
    Pop-Location
    if ($buildCode -ne 0) {
        Write-Host "The build failed. Read the last lines above, fix the problem, then run this again."
        exit 1
    }
}

$runArgs = @('run', '--rm', '-it')
if (-not $NoPrivilege) {
    $runArgs += '--privileged'
}
$runArgs += @('--hostname', 'lab', '-v', "${Repo}:/work", 'networking-lab', 'bash')

& docker @runArgs
exit $LASTEXITCODE
