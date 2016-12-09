<#
.SYNOPSIS
Initializes this repository for development.

.DESCRIPTION
The `init.ps1` script initializes this repository for development. It:

 * Installs NuGet packages for Pester
#>
[CmdletBinding()]
param(
    [Switch]
    # Removes any previously downloaded packages and re-downloads them.
    $Clean
)

Set-StrictMode -Version 'Latest'
#Requires -Version 4

& (Join-Path -Path $PSScriptRoot -ChildPath 'Arc\Carbon\Import-Carbon.ps1' -Resolve)

Install-Junction -Link (Join-Path -Path $PSScriptRoot -ChildPath 'Carbon') `
                 -Target (Join-Path -Path $PSScriptRoot -ChildPath 'Arc\Carbon')
