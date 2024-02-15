# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "concepts,conceptsancestors,conceptscountsbyyear,conceptsids,conceptsrelatedconcepts"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath