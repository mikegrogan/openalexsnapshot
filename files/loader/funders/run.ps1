# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "funders,funderscountsbyyear,fundersids"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath