# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "works,worksauthorships,worksbestoalocations,worksbiblio,worksconcepts,worksids,workslocations,worksmesh,worksopenaccess,worksprimarylocations,worksreferencedworks,worksrelatedworks",
    [string]$importmode = "append"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath