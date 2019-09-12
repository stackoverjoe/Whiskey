function Invoke-WhiskeyNUnit2Task
{
    [Whiskey.Task("NUnit2",SupportsInitialize,Platform='Windows')]
    [Whiskey.RequiresTool('NuGet::NUnit.Runners','NUnitPath',Version='2.6.4',VersionParameterName='NUnitVersion')]
    [Whiskey.RequiresTool('NuGet::OpenCover','OpenCoverPath',VersionParameterName='OpenCoverVersion')]
    [Whiskey.RequiresTool('NuGet::ReportGenerator','ReportGeneratorPath',VersionParameterName='ReportGeneratorVersion')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Whiskey.Context] $TaskContext,

        [Parameter(Mandatory=$true)]
        [hashtable] $TaskParameter
    )

    Set-StrictMode -version 'latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $package = 'NUnit.Runners'
    $version = '2.6.4'
    if( $TaskParameter['NUnitVersion'] )
    {
        $version = $TaskParameter['NUnitVersion']
        if( $version -notlike '2.*' )
        {
            Stop-WhiskeyTask -TaskContext $TaskContext -PropertyName 'Version' -Message ('The version ''{0}'' isn''t a valid 2.x version of NUnit.' -f $TaskParameter['NUnitVersion'])
            return
        }
    }

    $openCoverArgs = @()
    if( $TaskParameter['OpenCoverArgument'] )
    {
        $openCoverArgs += $TaskParameter['OpenCoverArgument']
    }

    $reportGeneratorArgs = @()
    if( $TaskParameter['ReportGeneratorArgument'] )
    {
        $reportGeneratorArgs += $TaskParameter['ReportGeneratorArgument']
    }

    $includeParam = $null
    if( $TaskParameter.ContainsKey('Include') )
    {
        $includeParam = '/include={0}' -f $TaskParameter['Include']
    }

    $excludeParam = $null
    if( $TaskParameter.ContainsKey('Exclude') )
    {
        $excludeParam = '/exclude={0}' -f $TaskParameter['Exclude']
    }

    $frameworkParam = '4.0'
    if( $TaskParameter.ContainsKey('Framework') )
    {
        $frameworkParam = $TaskParameter['Framework']
    }
    $frameworkParam = '/framework={0}' -f $frameworkParam

    Write-WhiskeyTiming -Message ('Installing NUnit.')
    $nunitRoot = $TaskParameter['NUnitPath']
    Write-WhiskeyTiming -Message ('COMPLETE')
    if( -not (Test-Path -Path $nunitRoot -PathType Container) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Package {0} {1} failed to install!' -f $package,$version)
        return
    }
    $nunitRoot = Get-Item -Path $nunitRoot | Select-Object -First 1
    $nunitRoot = Join-Path -Path $nunitRoot -ChildPath 'tools'
    $nunitConsolePath = Join-Path -Path $nunitRoot -ChildPath 'nunit-console.exe' -Resolve
    if( -not ($nunitConsolePath) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('{0} {1} was installed, but couldn''t find nunit-console.exe at ''{2}''.' -f $package,$version,$nunitConsolePath)
        return
    }

    Write-WhiskeyTiming -Message ('Installing OpenCover.')
    $openCoverRoot = $TaskParameter['OpenCoverPath']
    Write-WhiskeyTiming -Message ('COMPLETE')
    if( -not (Test-Path -Path $openCoverRoot -PathType Container) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Failed to install NuGet package OpenCover {0}.' -f $version)
        return
    }
    $openCoverPath = Get-ChildItem -Path $openCoverRoot -Filter 'OpenCover.Console.exe' -Recurse |
                        Select-Object -First 1 |
                        Select-Object -ExpandProperty 'FullName'
    if( -not (Test-Path -Path $openCoverPath -PathType Leaf) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Unable to find OpenCover.Console.exe in OpenCover NuGet package at ''{0}''.' -f $openCoverRoot)
        return
    }

    Write-WhiskeyTiming -Message ('Installing ReportGenerator.')
    $reportGeneratorRoot = $TaskParameter['ReportGeneratorPath']
    Write-WhiskeyTiming -Message ('COMPLETE')
    if( -not (Test-Path -Path $reportGeneratorRoot -PathType Container) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Failed to install NuGet package ReportGenerator.' -f $version)
        return
    }
    $reportGeneratorPath = Get-ChildItem -Path $reportGeneratorRoot -Filter 'ReportGenerator.exe' -Recurse |
                                Select-Object -First 1 |
                                Select-Object -ExpandProperty 'FullName'
    if( -not (Test-Path -Path $reportGeneratorPath -PathType Leaf) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Unable to find ReportGenerator.exe in ReportGenerator NuGet package at ''{0}''.' -f $reportGeneratorRoot)
        return
    }

    if( $TaskContext.ShouldInitialize )
    {
        return
    }

    # Be sure that the Taskparameter contains a 'Path'.
    if( -not ($TaskParameter.ContainsKey('Path')) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Element ''Path'' is mandatory. It should be one or more paths, which should be a list of assemblies whose tests to run, e.g.

        Build:
        - NUnit2:
            Path:
            - Assembly.dll
            - OtherAssembly.dll')
        return
    }

    $path = $TaskParameter['Path'] | Resolve-WhiskeyTaskPath -TaskContext $TaskContext -PropertyName 'Path'
    $reportPath = Join-Path -Path $TaskContext.OutputDirectory -ChildPath ('nunit2+{0}.xml' -f [IO.Path]::GetRandomFileName())

    $coverageReportDir = Join-Path -Path $TaskContext.outputDirectory -ChildPath "opencover"
    New-Item -Path $coverageReportDir -ItemType 'Directory' -Force | Out-Null
    $openCoverReport = Join-Path -Path $coverageReportDir -ChildPath 'openCover.xml'

    $extraArgs = $TaskParameter['Argument'] | Where-Object { $_ }
    
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  Path                {0}' -f ($Path | Select-Object -First 1))
    $Path | Select-Object -Skip 1 | ForEach-Object { Write-WhiskeyVerbose -Context $TaskContext -Message ('                      {0}' -f $_) }
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  Framework           {0}' -f $frameworkParam)
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  Include             {0}' -f $includeParam)
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  Exclude             {0}' -f $excludeParam)
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  Argument            /xml={0}' -f $reportPath)
    $extraArgs | ForEach-Object { Write-WhiskeyVerbose -Context $TaskContext -Message ('                      {0}' -f $_) }
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  CoverageFilter      {0}' -f ($TaskParameter['CoverageFilter'] | Select-Object -First 1))
    $TaskParameter['CoverageFilter'] | Select-Object -Skip 1 | ForEach-Object { Write-WhiskeyVerbose -Context $TaskContext -Message ('                      {0}' -f $_) }
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  Output              {0}' -f $openCoverReport)
    $disableCodeCoverage = $TaskParameter['DisableCodeCoverage'] | ConvertFrom-WhiskeyYamlScalar
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  DisableCodeCoverage {0}' -f $disableCodeCoverage)
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  OpenCoverArgs       {0}' -f ($openCoverArgs | Select-Object -First 1))
    $openCoverArgs | Select-Object -Skip 1 | ForEach-Object { Write-WhiskeyVerbose -Context $TaskContext -Message ('                      {0}' -f $_) }
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  ReportGeneratorArgs {0}' -f ($reportGeneratorArgs | Select-Object -First 1))
    $reportGeneratorArgs | Select-Object -Skip 1 | ForEach-Object { Write-WhiskeyVerbose -Context $TaskContext -Message ('                      {0}' -f $_) }

    if( -not $disableCodeCoverage )
    {
        $coverageFilterString = ($TaskParameter['CoverageFilter'] -join " ")
        $extraArgString = ($extraArgs -join " ")
        $pathsArg = ($path -join '" "')
        $nunitArgs = '"{0}" /noshadow {1} /xml="{2}" {3} {4} {5}' -f $pathsArg,$frameworkParam,$reportPath,$includeParam,$excludeParam,$extraArgString
        $nunitArgs = $nunitArgs -replace '"', '\"'
        Write-WhiskeyTiming -Message ('Running OpenCover')
        & $openCoverPath "-target:${nunitConsolePath}" "-targetargs:${nunitArgs}" "-filter:${coverageFilterString}" '-register:user' "-output:${openCoverReport}" '-returntargetcode' $openCoverArgs
        Write-WhiskeyTiming -Message ('COMPLETE')
        $testsFailed = $LastExitCode;
        Write-WhiskeyTiming -Message ('Running ReportGenerator')
        & $reportGeneratorPath "-reports:${openCoverReport}" "-targetdir:$coverageReportDir" $reportGeneratorArgs
        Write-WhiskeyTiming -Message ('COMPLETE')
        if( $LastExitCode -or $testsFailed )
        {
            Stop-WhiskeyTask -TaskContext $TaskContext -Message ('NUnit2 tests failed. {0} returned exit code {1}.' -f $openCoverPath,$LastExitCode)
            return
        }
    }
    else
    {
        Write-WhiskeyTiming -Message ('Running NUnit')
        & $nunitConsolePath $path $frameworkParam $includeParam $excludeParam $extraArgs ('/xml={0}' -f $reportPath)
        Write-WhiskeyTiming -Message ('COMPLETE')
        if( $LastExitCode )
        {
            Stop-WhiskeyTask -TaskContext $TaskContext -Message ('NUnit2 tests failed. {0} returned exit code {1}.' -f $nunitConsolePath,$LastExitCode)
            return
        }
    }
}
