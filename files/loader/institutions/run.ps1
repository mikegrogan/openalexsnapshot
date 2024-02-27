# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "institutions,institutionsassociatedinstitutions,institutionscountsbyyear,institutionsgeo,institutionsids",
    [string]$importmode = "merge"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath