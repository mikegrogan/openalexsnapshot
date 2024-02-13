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