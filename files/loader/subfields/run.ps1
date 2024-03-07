# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "subfields,subfieldsids,subfieldssiblings,subfieldstopics",
    [string]$importmode = "merge"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath