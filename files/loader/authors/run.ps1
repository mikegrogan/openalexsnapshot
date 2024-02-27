# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "authors,authorsaffiliations,authorscountsbyyear,authorsids",
    [string]$importmode = "append"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath