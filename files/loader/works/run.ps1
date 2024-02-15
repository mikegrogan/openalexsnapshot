# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "works,worksbestoalocations,worksbiblio,worksconcepts,worksids,worksmesh,worksopenaccess,worksreferencedworks,worksrelatedworks"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath