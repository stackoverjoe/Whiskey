
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)
if (-not $IsWindows)
{
    Write-Verbose -Message ('Skipping "{0}". Only supported on Windows, current platform is {1}.' -f $MyInvocation.MyCommand, $PSVersionTable.Platform) -Verbose
    return
}

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\PSModules\VSSetup')

$output = $null
$toolsVersionsKeyPath = 'TestRegistry:\ToolsVersions'
$toolsVersionsKeyPath32 = 'TestRegistry:\Wow6432Node\ToolsVersions'
$vsInstances = @()

function Init
{
    $Global:Error.Clear()
    $script:output = $null
    $script:vsInstances = @()

    New-Item -Path $toolsVersionsKeyPath -Force | Out-Null
    New-Item -Path $toolsVersionsKeyPath32 -Force | Out-Null

    $toolsKeyPath = $toolsVersionsKeyPath
    Mock -CommandName 'Get-ChildItem' `
         -ModuleName 'Whiskey' `
         -ParameterFilter { $Path -eq 'HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions' } `
         -MockWith {
            $PSBoundParameters['Path'] = $toolsKeyPath
            Get-ChildItem @PSBoundParameters
         }.GetNewClosure()

    $toolsKeyPath32 = $toolsVersionsKeyPath32
    Mock -CommandName 'Test-Path' `
          -ModuleName 'Whiskey' `
          -ParameterFilter { $Path -eq 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSBuild\ToolsVersions' } `
          -MockWith {
            $PSBoundParameters['Path'] = $toolsKeyPath32
            Get-ChildItem @PSBoundParameters
         }.GetNewClosure()

    Mock -CommandName 'Get-ChildItem' `
          -ModuleName 'Whiskey' `
          -ParameterFilter { $Path -eq 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\MSBuild\ToolsVersions' } `
          -MockWith {
            $PSBoundParameters['Path'] = $toolsKeyPath32
            Get-ChildItem @PSBoundParameters
         }.GetNewClosure()

    Mock -CommandName 'Get-VSSetupInstance' -ModuleName 'Whiskey'
}

function GivenVersionInRegistry
{
    param(
        [String]$Version,
        [String]$WithPath,
        [switch]$Bit32,
        [switch]$KeyOnly
    )

    $key = Join-Path -Path $toolsVersionsKeyPath -ChildPath $Version
    if( $Bit32 )
    {
        $key = Join-Path -Path $toolsVersionsKeyPath32 -ChildPath $Version
    }

    New-Item -Path $key | Out-Null

    if ($KeyOnly)
    {
        return
    }

    New-ItemProperty -Path $key -Name 'MSBuildToolsPath' -Value ($WithPath | Split-Path -Parent) | Out-Null

    Mock -CommandName 'Test-Path' `
         -ModuleName 'Whiskey' `
         -ParameterFilter ([scriptblock]::Create(('$Path -like ''{0}*''' -f $WithPath))) `
         -MockWith { return $true }
}

function GivenVersionInVisualStudio
{
    param(
        [String]$Version,
        [String]$VSInstallRoot,
        [String]$MSBuildPath,
        [String]$MSBuildPath32
    )

    $script:vsInstances = & {
        $vsInstances

        [pscustomobject]@{
            DisplayName = ('Visual Studio {0}' -f $Version)
            InstallationPath = $VSInstallRoot
            InstallationVersion = $Version

        }
    }

    $instances = $vsInstances
    Mock -CommandName 'Get-VSSetupInstance' `
         -ModuleName 'Whiskey' `
         -MockWith { $instances }.GetNewClosure()

    if ($MSBuildPath)
    {
        $msbuildPath = Join-Path -Path $VSInstallRoot -ChildPath $MSBuildPath
        New-Item -Path $MSBuildPath -Force | Out-Null
    }

    if ($MSBuildPath32)
    {
        $msbuildPath32 = Join-Path -Path $VSInstallRoot -ChildPath $MSBuildPath32
        New-Item -Path $msbuildPath32 -Force | Out-Null
    }
}

function WhenGettingMSBuild
{
    $script:output = Invoke-WhiskeyPrivateCommand -Name 'Get-MSBuild'
}

function ThenFoundMSBuild
{
    param(
        [String]$Version,
        [String]$InstallPath,
        [String]$InstallPath32
    )

    $found =
        $output |
        Where-Object { $_.Name -eq $Version } |
        Where-Object { $_.Version -eq [Version]$Version } |
        Where-Object { $_.Path -eq $InstallPath } |
        Where-Object { $_.Path32 -eq $InstallPath32 }

        $found | Should -Not -BeNullOrEmpty -Because ('it should find MSBuild version "{0}"' -f $Version)
}

function ThenReturnedNothing
{
    $output | Should -BeNullOrEmpty -Because 'it should not return anything'
}

function ThenReturnedExpectedObjects
{
    param(
        [int]$Count
    )

    $output | Should -HaveCount $Count -Because 'it should return the correct number of objects'

    foreach ($object in $output)
    {
        $objectProperties =
            $output |
            Get-Member -MemberType NoteProperty |
            Select-Object -ExpandProperty 'Name'

        $expectedProperties = @('Name', 'Version', 'Path', 'Path32')
        foreach ($property in $expectedProperties)
        {
            $property | Should -BeIn $objectProperties -Because 'should return object with expected properties'
        }
    }
}

Describe 'Get-MSBuild.when no instances of MSBuild installed' {
    It 'should not return anything' {
        Init
        WhenGettingMSBuild
        ThenReturnedNothing
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when version registry key exists but not the tool path registry value' {
    It 'should return all versions found' {
        Init
        GivenVersionInRegistry '14.0' -KeyOnly
        WhenGettingMSBuild
        ThenReturnedNothing
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when multiple versions found in registry' {
    It 'should return all versions found' {
        Init
        GivenVersionInRegistry '4.0' -WithPath ($msbuild4Path = 'TestDrive:\MSBuild\4.0\amd64\MSBuild.exe')
        GivenVersionInRegistry '4.0' -Bit32 -WithPath ($msbuild4Path32 = 'TestDrive:\MSBuild\4.0\MSBuild.exe')
        GivenVersionInRegistry '12.0' -WithPath ($msbuild12Path = 'TestDrive:\MSBuild\12.0\amd64\MSBuild.exe')
        GivenVersionInRegistry '12.0' -Bit32 -WithPath ($msbuild12Path32 = 'TestDrive:\MSBuild\12.0\MSBuild.exe')
        GivenVersionInRegistry '14.0' -WithPath ($msbuild14Path = 'TestDrive:\MSBuild\14.0\amd64\MSBuild.exe')
        GivenVersionInRegistry '15.0' -KeyOnly
        WhenGettingMSBuild
        ThenReturnedExpectedObjects -Count 3
        ThenFoundMSBuild '4.0' `
                         -InstallPath $msbuild4Path `
                         -InstallPath32 $msbuild4Path32
        ThenFoundMSBuild '12.0' `
                         -InstallPath $msbuild12Path `
                         -InstallPath32 $msbuild12Path32
        ThenFoundMSBuild '14.0' `
                         -InstallPath $msbuild14Path `
                         -InstallPath32 ''
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when found MSBuild in Visual Studio Install' {
    It 'should return all versions found' {
        Init
        $vs15Root = Join-Path -Path $TestDrive -ChildPath 'Microsoft Visual Studio\2017\Professional'
        GivenVersionInVisualStudio -Version '15.0' `
                                   -VSInstallRoot $vs15Root `
                                   -MSBuildPath ($vs15Msbuild = 'MSBuild\15.0\Bin\amd64\MSBuild.exe') `
                                   -MSBuildPath32 ($vs15Msbuild32 = 'MSBuild\15.0\Bin\MSBuild.exe')
        WhenGettingMSBuild
        ThenReturnedExpectedObjects -Count 1
        ThenFoundMSBuild '15.0' `
                  -InstallPath (Join-Path -Path $vs15Root -ChildPath $vs15Msbuild) `
                  -InstallPath32 (Join-Path -Path $vs15Root -ChildPath $vs15Msbuild32)
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when found versions in all places' {
    It 'should return all versions found' {
        Init
        GivenVersionInRegistry '4.0' -KeyOnly
        GivenVersionInRegistry '12.0' -WithPath ($msbuild12Path = 'TestDrive:\MSBuild\12.0\amd64\MSBuild.exe')
        GivenVersionInRegistry '12.0' -Bit32 -WithPath ($msbuild12Path32 = 'TestDrive:\MSBuild\12.0\MSBuild.exe')
        GivenVersionInRegistry '14.0' -WithPath ($msbuild14Path = 'TestDrive:\MSBuild\14.0\amd64\MSBuild.exe')

        $vs15Root = Join-Path -Path $TestDrive -ChildPath 'Microsoft Visual Studio\2017\Professional'
        GivenVersionInVisualStudio -Version '15.0' `
                                   -VSInstallRoot $vs15Root `
                                   -MSBuildPath ($vs15Msbuild = 'MSBuild\15.0\Bin\amd64\MSBuild.exe') `
                                   -MSBuildPath32 ($vs15Msbuild32 = 'MSBuild\15.0\Bin\MSBuild.exe')

        $vs15BuildToolsRoot = Join-Path -Path $TestDrive -ChildPath 'Microsoft Visual Studio\2017\BuildTools'
        GivenVersionInVisualStudio -Version '15.0' `
                                   -VSInstallRoot $vs15BuildToolsRoot `
                                   -MSBuildPath ($vs15Msbuild = 'MSBuild\15.0\Bin\amd64\MSBuild.exe') `
                                   -MSBuildPath32 ($vs15Msbuild32 = 'MSBuild\15.0\Bin\MSBuild.exe')
        WhenGettingMSBuild
        ThenReturnedExpectedObjects -Count 4
        ThenFoundMSBuild '12.0' `
                         -InstallPath $msbuild12Path `
                         -InstallPath32 $msbuild12Path32
        ThenFoundMSBuild '14.0' `
                         -InstallPath $msbuild14Path `
                         -InstallPath32 ''
        ThenFoundMSBuild '15.0' `
                         -InstallPath (Join-Path -Path $vs15Root -ChildPath $vs15Msbuild) `
                         -InstallPath32 (Join-Path -Path $vs15Root -ChildPath $vs15Msbuild32)
        ThenFoundMSBuild '15.0' `
                         -InstallPath (Join-Path -Path $vs15BuildToolsRoot -ChildPath $vs15Msbuild) `
                         -InstallPath32 (Join-Path -Path $vs15BuildToolsRoot -ChildPath $vs15Msbuild32)
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when MSbuild found in Visual Studio Install does not exist in a versioned directory' {
    It 'should not return that version' {
        Init
        $vs15Root = Join-Path -Path $TestDrive -ChildPath 'Microsoft Visual Studio\2017\Professional'
        GivenVersionInVisualStudio -Version '15.0' `
                                   -VSInstallRoot $vs15Root `
                                   -MSBuildPath 'MSBuild\Im-Not-A-Version\Bin\amd64\MSBuild.exe' `
                                   -MSBuildPath32 'MSBuild\Im-Not-A-Version\Bin\MSBuild.exe'
        WhenGettingMSBuild
        ThenReturnedNothing
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when only found 64bit MSBuild in Visual Studio Install' {
    It 'should return the 64bit version found' {
        Init
        $vs15Root = Join-Path -Path $TestDrive -ChildPath 'Microsoft Visual Studio\2017\Professional'
        GivenVersionInVisualStudio -Version '15.0' `
                                   -VSInstallRoot $vs15Root `
                                   -MSBuildPath ($vs15Msbuild = 'MSBuild\15.0\Bin\amd64\MSBuild.exe') `
                                   -MSBuildPath32 ''
        WhenGettingMSBuild
        ThenReturnedExpectedObjects -Count 1
        ThenFoundMSBuild '15.0' `
                  -InstallPath (Join-Path -Path $vs15Root -ChildPath $vs15Msbuild) `
                  -InstallPath32 ''
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when only found 32bit MSBuild in Visual Studio Install' {
    It 'should return the 32bit version found' {
        Init
        $vs15Root = Join-Path -Path $TestDrive -ChildPath 'Microsoft Visual Studio\2017\Professional'
        GivenVersionInVisualStudio -Version '15.0' `
                                   -VSInstallRoot $vs15Root `
                                   -MSBuildPath '' `
                                   -MSBuildPath32 ($vs15Msbuild32 = 'MSBuild\15.0\Bin\MSBuild.exe')
        WhenGettingMSBuild
        ThenReturnedExpectedObjects -Count 1
        ThenFoundMSBuild '15.0' `
                  -InstallPath (Join-Path -Path $vs15Root -ChildPath $vs15Msbuild32) `
                  -InstallPath32 (Join-Path -Path $vs15Root -ChildPath $vs15Msbuild32)
        ThenErrorRecord -Empty
    }
}

Describe 'Get-MSBuild.when MSbuild found in Visual Studio Install does not exist under a "MSBuild" directory' {
    It 'should not return that version' {
        Init
        GivenVersionInVisualStudio -Version '15.0' `
                                   -VSInstallRoot 'TestDrive:\Microsoft Visual Studio\2017\Professional' `
                                   -MSBuildPath 'Bin\amd64\MSBuild.exe' `
                                   -MSBuildPath32 'Bin\MSBuild.exe'
        WhenGettingMSBuild
        ThenReturnedNothing
        ThenErrorRecord -Empty
    }
}
