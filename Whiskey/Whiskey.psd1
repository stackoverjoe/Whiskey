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
    ModuleVersion = '0.44.0'

    # ID used to uniquely identify this module
    GUID = '93bd40f1-dee5-45f7-ba98-cb38b7f5b897'

    # Author of this module
    Author = 'WebMD Health Services'

    # Company or vendor of this module
    CompanyName = 'WebMD Health Services'

    CompatiblePSEditions = @( 'Desktop', 'Core' )

    # Copyright statement for this module
    Copyright = '(c) 2016 - 2018 WebMD Health Services. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Continuous Integration/Continuous Delivery module.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

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
    RequiredAssemblies = @( 'bin\SemanticVersion.dll', 'bin\Whiskey.dll', 'bin\YamlDotNet.dll' )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @(
                            'Formats\System.Exception.format.ps1xml',
                            'Formats\System.Management.Automation.ErrorRecord.format.ps1xml',
                            'Formats\Whiskey.BuildInfo.format.ps1xml',
                            'Formats\Whiskey.BuildVersion.format.ps1xml',
                            'Formats\Whiskey.Context.format.ps1xml',
                            'Formats\Whiskey.TaskAttribute.format.ps1xml'
                        )

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @( )

    # Functions to export from this module
    FunctionsToExport = @(
                            'Add-WhiskeyApiKey',
                            'Add-WhiskeyCredential',
                            'Add-WhiskeyTaskDefault',
                            'Add-WhiskeyVariable',
                            'Assert-WhiskeyNodePath',
                            'Assert-WhiskeyNodeModulePath',
                            'ConvertFrom-WhiskeyContext'
                            'ConvertFrom-WhiskeyYamlScalar',
                            'ConvertTo-WhiskeyContext',
                            'ConvertTo-WhiskeySemanticVersion',
                            'Get-WhiskeyApiKey',
                            'Get-WhiskeyTask',
                            'Get-WhiskeyCredential',
                            'Get-WhiskeyMSBuildConfiguration',
                            'Install-WhiskeyTool',
                            'Invoke-WhiskeyNodeTask',
                            'Invoke-WhiskeyNpmCommand',
                            'Invoke-WhiskeyPipeline',
                            'Invoke-WhiskeyBuild',
                            'Invoke-WhiskeyTask',
                            'New-WhiskeyContext',
                            'Publish-WhiskeyBuildMasterPackage',
                            'Publish-WhiskeyNuGetPackage',
                            'Publish-WhiskeyProGetUniversalPackage',
                            'Publish-WhiskeyBBServerTag',
                            'Register-WhiskeyEvent',
                            'Resolve-WhiskeyNodePath',
                            'Resolve-WhiskeyNodeModulePath',
                            'Resolve-WhiskeyNuGetPackageVersion',
                            'Resolve-WhiskeyTaskPath',
                            'Resolve-WhiskeyVariable',
                            'Set-WhiskeyBuildStatus',
                            'Set-WhiskeyMSBuildConfiguration',
                            'Stop-WhiskeyTask',
                            'Uninstall-WhiskeyTool',
                            'Unregister-WhiskeyEvent',
                            'Write-WhiskeyDebug',
                            'Write-WhiskeyError',
                            'Write-WhiskeyInfo',
                            'Write-WhiskeyVerbose',
                            'Write-WhiskeyWarning'
                         );

    # Cmdlets to export from this module
    CmdletsToExport = @( )

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

            # Any prerelease to use when publishing to a repository.
            Prerelease = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
* The `GetPowerShellModule` task now supports installing prerelease versions of modules. Set the `AllowPrerelease` property to `true`.
* The `GetPowerShellModule` task can now install a module into a custom directory instead of the PSModules directory. Pass the path to the `Path` parameter.
* The `GetPowerShellModule` task can now import the module being installed. Set the `Import` property to `true`.
* Fixed: Whiskey fails to fail a build when certain PowerShell terminating errors are thrown (i.e. strict mode violations, command not found error, etc.).
* Breaking change: Whiskey's default version number is now `0.0.0` instead of using the current date. If you care about your version number, make sure you have a `Version` task defined in your whiskey.yml file.
* Removed all support for old "VersionFrom", "PrereleaseMap", and "Version" properties in the root of your whiskey.yml file. Use Whiskey's `Version` task instead.
'@
        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
