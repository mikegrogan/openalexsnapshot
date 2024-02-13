# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local",
    [string]$importlist = "authors,authorscountsbyyear,authorsids"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath

# Run Oracle Import
foreach ($item in $importlistArr) {
    # Clean up old logs
    Remove-Item -Path "logs\$item.*" -Force -ErrorAction SilentlyContinue

    # Oracle Import
    sqlldr userid=$connectionstring direct=true skip=1 skip_index_maintenance=true control="$item.ctl" log="logs\$item.log"
}
