param (
    [string]$oraclepath = (Get-Location).Path
)

Clear-Host

# Setup working directory
Set-Location -Path $oraclepath

. (Join-Path -Path $PSScriptRoot -ChildPath "settings.ps1")

$settingsFullPath = Join-Path $oraclepath $settingsPath

# Read the JSON file
$jsonContent = Get-Content -Raw -Path $settingsFullPath | ConvertFrom-Json

# Access the properties
$environment = $jsonContent.environment
$database = $jsonContent.database

# Access database properties based on environment
$datasource = $database.$environment.datasource
$schema = $database.$environment.schema
$connectionstring = $database.$environment.connectionstring

$importlistArr=$importlist -split ','

# Output the values
Write-Host "Path: $oraclepath"
Write-Host "ImportList: $importlistArr"
Write-Host "Environment: $environment"
Write-Host "Datasource: $datasource"
Write-Host "Schema: $schema"
Write-Host "ConnectionString: $connectionstring"

# Run Oracle Import
foreach ($item in $importlistArr) {
    # Clean up old logs
    Remove-Item -Path "logs\$item.*" -Force -ErrorAction SilentlyContinue

    $controlfile="control\$importmode\$item.ctl"    
        
    if ($importMode -eq "append") {
        # $parallel = "true"
        $parallel = "true"
    } else{
        $parallel = "false"
    }

    Write-Host "controlfile: $controlfile"
    Write-Host "parallel: $parallel"

    # Oracle Import
    sqlldr userid=$connectionstring direct=true skip=1 errors=0 skip_index_maintenance=true parallel=$parallel control="$controlfile" log="logs\$item.log"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Error]: SQL*Loader encountered errors. Please check the log file for details."
    }
}