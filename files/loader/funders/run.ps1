# Set parameters
param (
    [string]$oraclepath = (Get-Location).Path,
    [string]$environment = "local"
)

# Call settings script
. "$oraclepath\..\base.ps1" -oraclepath $oraclepath

# Run Oracle Import
$importlist = "institutions", "institutionsassociated", "institutionscounts", "institutionsgeo", "institutionsids"

foreach ($item in $importlist) {
    # Clean up old logs
    Remove-Item -Path "logs\$item.*" -Force -ErrorAction SilentlyContinue

    # Oracle Import
    sqlldr userid=$connectionstring direct=true skip=1 skip_index_maintenance=true control="$item.ctl" log="logs\$item.log"
}
