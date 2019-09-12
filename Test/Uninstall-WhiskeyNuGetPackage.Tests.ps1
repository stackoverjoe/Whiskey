& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

function GivenAnInstalledNuGetPackage
{
    [CmdLetBinding()]
    param(
        [String]$WithVersion = '2.6.4',

        [String]$WithName = 'NUnit.Runners'
    )
    $WithVersion = Resolve-WhiskeyNuGetPackageVersion -NuGetPackageName $WithName -Version $WithVersion
    if( -not $WithVersion )
    {
        return
    }
    $dirName = '{0}.{1}' -f $WithName, $WithVersion
    $installRoot = Join-Path -Path $TestDrive.FullName -ChildPath 'packages'
    New-Item -Name $dirName -Path $installRoot -ItemType 'Directory' | Out-Null
}

function WhenUninstallingNuGetPackage
{
    [CmdletBinding()]
    param(
        [String]$WithVersion = '2.6.4',

        [String]$WithName = 'NUnit.Runners'
    )

    $Global:Error.Clear()
    Uninstall-WhiskeyNuGetPackage -Name $WithName -Version $WithVersion -BuildRoot $TestDrive.FullName
}

function ThenNuGetPackageUninstalled
{
    [CmdLetBinding()]
    param(
        [String]$WithVersion = '2.6.4',

        [String]$WithName = 'NUnit.Runners'
    )

    $Name = '{0}.{1}' -f $WithName, $WithVersion
    $path = Join-Path -Path $TestDrive.FullName -ChildPath 'packages'
    $uninstalledPath = Join-Path -Path $path -ChildPath $Name

    $uninstalledPath | Should not Exist

    $Global:Error | Should beNullOrEmpty
}

function ThenNuGetPackageNotUninstalled
{
    [CmdLetBinding()]
    param(
        [String]$WithVersion = '2.6.4',

        [String]$WithName = 'NUnit.Runners',

        [switch]$PackageShouldExist,

        [string]$WithError
    )

    $Name = '{0}.{1}' -f $WithName, $WithVersion
    $path = Join-Path -Path $TestDrive.FullName -ChildPath 'packages'
    $uninstalledPath = Join-Path -Path $path -ChildPath $Name

    if( -not $PackageShouldExist )
    {
        $uninstalledPath | Should not Exist
    }
    else
    {
        $uninstalledPath | Should Exist
        Remove-Item -Path $uninstalledPath -Recurse -Force
    }

    $Global:Error | Should Match $WithError
}

if( $IsWindows )
{
    Describe 'Uninstall-WhiskeyNuGetPackage.when given an NuGet Package' {
        It 'should successfully uninstall the NuGet Package' {
            GivenAnInstalledNuGetPackage
            WhenUninstallingNuGetPackage
            ThenNuGetPackageUnInstalled
        }
    }

    Describe 'Uninstall-WhiskeyNuGetPackage.when given an NuGet Package with an empty Version' {
        It 'should successfully uninstall the NuGet Package' {
            GivenAnInstalledNuGetPackage -WithVersion ''
            WhenUninstallingNuGetPackage -WithVersion ''
            ThenNuGetPackageUnInstalled -WithVersion ''
        }
    }
    
    Describe 'Uninstall-WhiskeyNuGetPackage.when given an NuGet Package with a wildcard Version' {
        It 'should never have installed the package' {
            GivenAnInstalledNuGetPackage -WithVersion '2.*' -ErrorAction SilentlyContinue
            WhenUninstallingNuGetPackage -WithVersion '2.*' -ErrorAction SilentlyContinue
            ThenNuGetPackageNotUnInstalled -WithVersion '2.*' -WithError 'Wildcards are not allowed for NuGet packages'
        }
    }    
}