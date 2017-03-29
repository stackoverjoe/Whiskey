
function Invoke-WhsCIPester4Task
{
    <#
    .SYNOPSIS
    Runs Pester tests using Pester 4.

    .DESCRIPTION
    The `Invoke-Pester4Task` runs tests using Pester 4. You pass the path(s) to test to the `Path` parameter, which are passed directly to the `Invoke-Pester` function's `Script` parameter. Additional configuration information can be included in the `$TaskContext` such as:

    * `$TaskContext.Version`: The version of Pester 4 to use. Can be a version greater than 4.0. Must match a version on the Powershell Gallery. To find a list of all the versions of Pester available, install the Package Management module, then run `Find-Module -Name 'Pester' -AllVersions`. You usually want the latest version.

    If any tests fail (i.e. if the `FailedCount property on the result object returned by `Invoke-Pester` is greater than 0), this function will throw a terminating error.

    .EXAMPLE
    Invoke-WhsCIPester4Task -TaskContext $context -TaskParameter $taskParameter

    Demonstrates how to run Pester tests against a set of test fixtures. In this case, The version of Pester in `$TaskContext.Version` will recursively run all tests under `TaskParameter.Path` and output an XML report with the results in the `$TaskContext.OutputDirectory` directory.
    #>
    [CmdletBinding()]
    param(
         [Parameter(Mandatory=$true)]
        [object]
        $TaskContext,
    
        [Parameter(Mandatory=$true)]
        [hashtable]
        $TaskParameter        
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( -not ($TaskParameter.ContainsKey('Path')))
        {
            Stop-WhsCITask -TaskContext $TaskContext -Message ('Element ''Path'' is mandatory. It should be one or more paths, which should be a list of Pester Tests to run with Pester4, e.g. 
        
            BuildTasks:
            - Pester4:
                Path:
                - My.Tests.ps1
                - Tests')
        }

    $path = $TaskParameter['Path'] | Resolve-WhsCITaskPath -TaskContext $TaskContext -PropertyName 'Path'
    
    if( $TaskParameter.Version )
    {
        $version = $TaskParameter.Version | ConvertTo-WhsCISemanticVersion
        if( -not $version )
        {
            Stop-WhsCITask -TaskContext $TaskContext -message ('Configuration property ''Version'' isn''t a valid version number. It must be a version number of the form MAJOR.MINOR.BUILD.')
        }

        if( $version.Major -ne 4)
        {
            Stop-WhsCITask -TaskContext $TaskContext -Message ('Specified Pester Version {0} is not part of version 4. The Pester4 task is designed to run tests using Pester4 with version 4.0.0 or greater.' -f $version)
        }
        
        $version = [version]('{0}.{1}.{2}' -f $version.Major,$version.Minor,$version.Patch)
    }
    else
    {
        $latestPester = ( Find-Module -Name 'Pester' -AllVersions | Where-Object { $_.Version -like '4.*' } ) 
        if( -not $latestPester )
        {
            Stop-WhsCITask -TaskContext $TaskContext -Message ('Unable to find a suitable default version of Pester4. Try again with explicit Version property.')
        }
        $latestPester = $latestPester | Sort-Object -Property Version -Descending | Select-Object -First 1
        $version = $latestPester.Version 
    }

    $pesterModulePath = Install-WhsCITool -ModuleName 'Pester' -Version $version
    if( -not $pesterModulePath )
    {
        Stop-WhsCITask -TaskContext $TaskContext -Message ('Failed to download or install Pester {0}, most likely because version {0} does not exist. Available version numbers can be found at https://www.powershellgallery.com/packages/Pester' -f $version)
    }

    $testIdx = 0
    $outputFileNameFormat = 'pester-{0:00}.xml'
    while( (Test-Path -Path (Join-Path -Path $TaskContext.OutputDirectory -ChildPath ($outputFileNameFormat -f $testIdx))) )
    {
        $testIdx++
    }

    # We do this in the background so we can test this with Pester.
   $job = Start-Job -ScriptBlock {
        $script = $using:Path
        $outputRoot = $using:TaskContext.OutputDirectory
        $testIdx = $using:testIdx
        $pesterModulePath = $using:pesterModulePath
        $outputFileNameFormat = $using:outputFileNameFormat

        Import-Module -Name $pesterModulePath
        $outputFile = Join-Path -Path $outputRoot -ChildPath ($outputFileNameFormat -f $testIdx)
        $result = Invoke-Pester -Script $script -OutputFile $outputFile -OutputFormat NUnitXml -PassThru
        $result
        if( $result.FailedCount )
        {
             Stop-WhsCITask -TaskContext $TaskContext -Message ('Pester tests failed.')
        }
    } 
    
    do
    {
        $job | Receive-Job
    }
    while( -not ($job | Wait-Job -Timeout 1) )

    $job | Receive-Job
}