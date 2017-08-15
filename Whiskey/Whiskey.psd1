#
# Module manifest for module 'Whiskey'
#
# Generated by: ajensen
#
# Generated on: 12/8/2016
# 

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'Whiskey.psm1'

    # Version number of this module.
    ModuleVersion = '0.13.0'

    # ID used to uniquely identify this module
    GUID = '93bd40f1-dee5-45f7-ba98-cb38b7f5b897'

    # Author of this module
    Author = 'WebMD Health Services'

    # Company or vendor of this module
    CompanyName = 'WebMD Health Services'

    # Copyright statement for this module
    Copyright = '(c) 2016 WebMD Health Services. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Continuous Integration/Continuous Delivery module.'

    # Minimum version of the Windows PowerShell engine required by this module
    # PowerShellVersion = ''

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @( 'bin\SemanticVersion.dll', 'bin\YamlDotNet.dll' )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    #ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @( 
                        'BitbucketServerAutomation',
                        'BuildMasterAutomation',
                        'ProGetAutomation',
                        'VSSetup'
                     )

    # Functions to export from this module
    FunctionsToExport = @( 
                            'Add-WhiskeyApiKey',
                            'Add-WhiskeyCredential',
                            'ConvertFrom-WhiskeyYamlScalar',
                            'ConvertTo-WhiskeySemanticVersion',
                            'Get-WhiskeyApiKey',
                            'Get-WhiskeyTask',
                            'Get-WhiskeyCredential',
                            'Install-WhiskeyNodeJs',
                            'Install-WhiskeyTool',
                            'Invoke-WhiskeyNodeTask',
                            'Invoke-WhiskeyNUnit2Task',
                            'Invoke-WhiskeyPester3Task',
                            'Invoke-WhiskeyPester4Task',
                            'Invoke-WhiskeyPipeline',
                            'Invoke-WhiskeyBuild',
                            'Invoke-WhiskeyTask',
                            'New-WhiskeyContext',
                            'Publish-WhiskeyBuildMasterPackage',
                            'Publish-WhiskeyNuGetPackage',
                            'Publish-WhiskeyProGetUniversalPackage',
                            'Publish-WhiskeyBBServerTag',
                            'Register-WhiskeyEvent',
                            'Resolve-WhiskeyNuGetPackageVersion',
                            'Resolve-WhiskeyPowerShellModuleVersion',
                            'Resolve-WhiskeyTaskPath',
                            'Set-WhiskeyBuildStatus',
                            'Stop-WhiskeyTask',
                            'Uninstall-WhiskeyTool',
                            'Unregister-WhiskeyEvent',
                            'Write-CommandOutput'
                         );

    # Cmdlets to export from this module
    #CmdletsToExport = '*'

    # Variables to export from this module
    #VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = '*'

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @( 'build', 'pipeline', 'devops', 'ci', 'cd', 'continuous-integration', 'continuous-delivery', 'continuous-deploy' )

            # A URL to the license for this module.
            LicenseUri = 'https://www.apache.org/licenses/LICENSE-2.0'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/webmd-health-services/Whiskey'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
* ***BREAKING CHANGE***: Removed `Get-WhiskeyOutputDirectory` function. You should use the `OutputDirectory` property on the build's context object (which is returned by `New-WhiskeyContext`).
* ***BREAKING CHANGE***: Removed `Test-WhiskeyRunByBuildServer` function. You should use the `ByBuildServer` or `ByDeveloper` properties on the build's context object (which is returned by `New-WhiskeyContext`).
* ***BREAKING CHANGE***: The `ConvertTo-WhiskeySemanticVersion` function now tries to convert its input into a semantic version. It no longer also tries to create a version number for the current build. It is now safe to use this function to convert objects to version numbers.
* Build metadata is now available on a `BuildMetadata` property on build context objects returned by `New-WhiskeyContext`. This includes information like build number, job name, source control information, etc.
* Fixed: setting a build status in Bitbucket Server doesn't replace previous statuses. If any build of a commit has ever failed, Bitbucket Server shows that commit as failed.
* Added support for running builds under AppVeyor.
* Added support for running builds under TeamCity.
* ***BREAKING CHANGE***: Whiskey no longer publishes on `develop`, `release`, `release/*`, or `master` branches by default. Publishing only happens if you supply a `PublishOn` property in your whiskey.yml file.
* ***BREAKING CHANGE***: PublishOn property now uses wildcards instead of regular expressions.
* ***BREAKING CHANGE***: PublishBuildMasterPackage task now requires a `ReleaseName` property.
* ***BREAKING CHANGE***: Build context object no longer has a ReleaseName property.
* ***BREAKING CHANGE***: Build context object no longer has an ApplicationName property.
* ***BREAKING CHANGE***: PrereleaseMap configuration property now uses wildcards instead of regular expressions to match branch names.
* Added `Version` property to MSBuild task. Use this property to specify which version of MSBuild to use. The default is now the most recent (i.e. highest) version installed.
* Added `NoFileLogger` property to MSBuild task. Use this property to disable writing debug logs to the output directory.
* Added `NoMaxCpuCountArgument` property to MSBuild task. Use this property to not pass the `/maxcpucount` parameter to MSBuild.
* Added support for building with MSBuild 15.0.
* Added `ConvertFrom-WhiskeyYamlScalar` function for converting configuration properties into booleans, integers, floating-point numbers, and date/times according to the YAML specification.
* ***BREAKING CHANGE***: Switched from `powershell-yaml` module to `YamlDotNet` library to parse YAML files. The `powershell-yaml` module tries to convert all scalars to strongly-typed objects, which causes pain.
'@
        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
