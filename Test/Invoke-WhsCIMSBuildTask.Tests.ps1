
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhsCITest.ps1' -Resolve)

$failingNUnit2TestAssemblyPath = Join-Path -Path $PSScriptRoot -ChildPath 'Assemblies\NUnit2FailingTest\bin\Release\NUnit2FailingTest.dll'
$passingNUnit2TestAssemblyPath = Join-Path -Path $PSScriptRoot -ChildPath 'Assemblies\NUnit2PassingTest\bin\Release\NUnit2PassingTest.dll'


function Invoke-MSBuild
{
    param(
        [Switch]
        $ThatFails,

        [string[]]
        $On,

        [Switch]
        $InReleaseMode,

        [Switch]
        $AsDeveloper,

        [Switch]
        $ForRealProjects,

        [String[]]
        $ForAssemblies,

        [String]
        $WithError,

        [Switch]
        $WithCleanSwitch
    )

    Process
    {
        $optionalArgs = @{ }
        $optionalParams = @{ }
        $threwException = $false
        $Global:Error.Clear()
        
        $runByBuildServerMock = { return $true }
        $taskParameter = @{ }
        if( $On )
        {
            $taskParameter['Path'] = $On
        }

        if ( $InReleaseMode )
        {
            $optionalArgs['InReleaseMode'] = $true
        }

        if ( $AsDeveloper )
        {
            $version = [SemVersion.SemanticVersion]"1.2.3-rc.1+build"
            $runByBuildServerMock = { return $false }
            $optionalArgs['ByDeveloper'] = $true
        }
        else
        {
            $version = [SemVersion.SemanticVersion]"1.1.1-rc.1+build"
            $optionalArgs['ByBuildServer'] = $true
        }
        if ( $WithCleanSwitch )
        {
            $optionalParams['Clean'] = $True
        }

        # Get rid of any existing packages directories.
        Get-ChildItem -Path $PSScriptRoot -Include 'bin','obj','packages' -Recurse -Directory | Remove-Item -Recurse -Force

        Mock -CommandName 'Test-WhsCIRunByBuildServer' -ModuleName 'WhsCI' -MockWith $runByBuildServerMock
        MOck -CommandName 'ConvertTo-WhsCISemanticVersion' -ModuleName 'WhsCI' -MockWith { return $version }.GetNewClosure()
        $context = New-WhsCITestContext -ForBuildRoot (Join-Path -Path $PSScriptRoot -ChildPath 'Assemblies') @optionalArgs
        $assembliesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'Assemblies'
        # Set aside the AssemblyInfo.cs files so we can restore them late
        Get-ChildItem -Path $assembliesRoot -Filter 'AssemblyInfo.cs' -Recurse |
            ForEach-Object { Copy-Item -Path $_.FullName -Destination ('{0}.orig' -f $_.FullName) }
        $errors = @()
        try
        {
            Invoke-WhsCIMSBuildTask -TaskContext $context -TaskParameter $taskParameter @optionalParams
        }
        catch
        {
            $threwException = $true
        }
        finally
        {
            # Restore the original AssemblyInfo.cs files.
            Get-ChildItem -Path $assembliesRoot -Filter 'AssemblyInfo.cs.orig' -Recurse |
                ForEach-Object { Move-Item -Path $_.FullName -Destination ($_.FullName -replace '\.orig$','') -Force }
        }
        
        if( $WithError )
        {
            It 'should should write an error'{
                $Global:Error | Should Match ( $WithError )
            }
        }      
        if( $ThatFails )
        {
            It 'should throw an exception'{
                $threwException | Should Be $true
            }
        }
        #Valid Path
        else
        {
            It 'should not throw an exception'{
                $threwException | Should Be $false
            }

            It 'should write no errors' {
                $errors | Should Not Match 'MSBuild'
            }
            if( $WithCleanSwitch )
            {
                foreach( $assembly in $ForAssemblies )
                {
                    It ('should not build the {0} assembly' -f ($assembly | Split-Path -Leaf)) {
                        $assembly | Should not Exist
                    }
                }
                It 'should remove NuGet packages' {
                    Get-ChildItem -Path $PSScriptRoot -Filter 'packages' -Recurse -Directory | Should BeNullOrEmpty
                }
            }
            else
            {
                foreach( $assembly in $ForAssemblies )
                {
                    It ('should build the {0} assembly' -f ($assembly | Split-Path -Leaf)) {
                        $assembly | Should Exist
                    }
                }
                It 'should restore NuGet packages' {
                    Get-ChildItem -Path $PSScriptRoot -Filter 'packages' -Recurse -Directory | Should Not BeNullOrEmpty
                }
                foreach( $assembly in $ForAssemblies )
                {
                    It ('should version the {0} assembly' -f ($assembly | Split-Path -Leaf)) {
                        $fileInfo = Get-Item -Path $assembly
                        $fileVersionInfo = $fileInfo.VersionInfo
                        $fileVersionInfo.FileVersion | Should Be $context.Version.Version.ToString()
                        $fileVersionInfo.ProductVersion | Should Be ('{0}' -f $context.Version)
                    }
                }
            }
        }  
    }
}

Describe 'Invoke-WhsCIMSBuildTask.when building real projects with Clean Switch' {
    $assemblies = @( $failingNUnit2TestAssemblyPath, $passingNUnit2TestAssemblyPath )
    Invoke-MSBuild -On @(
                                        'NUnit2FailingTest\NUnit2FailingTest.sln',
                                        'NUnit2PassingTest\NUnit2PassingTest.sln'
                                    ) -InReleaseMode -ForAssemblies $assemblies -WithCleanSwitch
}

Describe 'Invoke-WhsCIMSBuildTask.when building real projects with Clean Switch and removing related nuget packages' {
    $assemblies = @( $failingNUnit2TestAssemblyPath, $passingNUnit2TestAssemblyPath )  
    Context 'Build task to populate packages' {
        Invoke-MSBuild -On @(
                                'NUnit2FailingTest\NUnit2FailingTest.sln',
                                'NUnit2PassingTest\NUnit2PassingTest.sln'
                            ) -InReleaseMode -ForAssemblies $assemblies  
    }
    Context 'Clean task to remove packages' {
        Invoke-MSBuild -On @(
                                'NUnit2FailingTest\NUnit2FailingTest.sln',
                                'NUnit2PassingTest\NUnit2PassingTest.sln'
                            ) -InReleaseMode -ForAssemblies $assemblies -WithCleanSwitch
    }
}

Describe 'Invoke-WhsCIMSBuildTask.when building real projects' {
    $assemblies = @( $failingNUnit2TestAssemblyPath, $passingNUnit2TestAssemblyPath )
    Invoke-MSBuild -On @(
                                        'NUnit2FailingTest\NUnit2FailingTest.sln',
                                        'NUnit2PassingTest\NUnit2PassingTest.sln'
                                    ) -InReleaseMode -ForAssemblies $assemblies
}

Describe 'Invoke-WhsCIMSBuildTask.when compilation fails' {
    Invoke-MSBuild -ThatFails -On @(
                                    'ThisWillFail.sln',
                                    'ThisWillAlsoFail.sln'
                                )
}

Describe 'Invoke-WhsCIMSBuildTask. when Path Parameter is not included' {
    $errorMatch = [regex]::Escape('Element ''Path'' is mandatory')
    Invoke-MSBuild -ThatFails -WithError $errorMatch
}

Describe 'Invoke-WhsCIMSBuildTask. when Path Parameter is invalid' {
    $errorMatch = [regex]::Escape('does not exist.')
    Invoke-MSBuild -ThatFails -On 'I\do\not\exist' -WithError $errorMatch
}

Describe 'Invoke-WhsCIBuild.when a developer is compiling dotNET project' {
    $assemblies = @( $failingNUnit2TestAssemblyPath, $passingNUnit2TestAssemblyPath )
    Invoke-MSBuild -On @(
                                        'NUnit2FailingTest\NUnit2FailingTest.sln',
                                        'NUnit2PassingTest\NUnit2PassingTest.sln'
                                    ) -AsDeveloper -ForAssemblies $assemblies
}

$output = $null
$path = $null
$threwException = $null

function GivenAProjectThatCompiles
{
    $source = Join-Path -Path $PSScriptRoot -ChildPath 'Assemblies\NUnit2PassingTest'
    $destination = Join-Path -Path $TestDrive.FullName -ChildPath 'BuildRoot'
    robocopy $source $destination '/MIR' '/NP' '/R:0'
    $script:path = 'NUnit2PassingTest.sln'
}

function WhenRunningTask
{
    param(
        [hashtable]
        $WithParameter = @{},

        [Switch]
        $AsDeveloper,

        [Switch]
        $AsBuildServer
    ) 

    $optionalParams = @{ }
    if( $AsDeveloper )
    {
        $optionalParams['ForDeveloper'] = $true
    }
    
    if( $AsBuildServer )
    {
        $optionalParams['ForBuildServer'] = $true
    }

    $context = New-WhsCITestContext @optionalParams -ForBuildRoot (Join-Path -Path $TestDrive.FullName -ChildPath 'BuildRoot')

    $WithParameter['Path'] = $path
    
    try
    {
        $script:output = Invoke-WhsCIMSBuildTask -TaskContext $context -TaskParameter $WithParameter
    }
    catch
    {
        Write-Error $_
        $script:threwException = $true
    }
}

function ThenOutputIsEmpty
{
    It 'should write no output' {
        $output | Should BeNullOrEmpty
    }
}

function ThenOutputIsMinimal
{
    It 'should write minimal output' {
        $output | Should Match '^.*\ ->\ .*$'
    }
}

function ThenOutputIsDebug
{
    It 'should write debug output' {
        $output -join [Environment]::NewLine | Should Match 'Target\ "[^"]+"\ in\ file\ '
    }
}

Describe 'Invoke-WhsCIMSBuildTask.when customizing output level' {
    GivenAProjectThatCompiles
    WhenRunningTask -WithParameter @{ 'Verbosity' = 'q' }
    ThenOutputIsEmpty
}

Describe 'Invoke-WhsCIMSBuildTask.when run by developer using default verbosity output level' {
    GivenAProjectThatCompiles
    WhenRunningTask -AsDeveloper
    ThenOutputIsMinimal
}

Describe 'Invoke-WhsCIMSBuildTask.when run by build server using default verbosity output level' {
    GivenAProjectThatCompiles
    WhenRunningTask -AsBuildServer
    ThenOutputIsDebug
}
