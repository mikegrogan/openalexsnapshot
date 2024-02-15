# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "publishers,publisherscountsbyyear,publishersids"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath