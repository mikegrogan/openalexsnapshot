# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "sources,sourcescountsbyyear,sourcesids"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath