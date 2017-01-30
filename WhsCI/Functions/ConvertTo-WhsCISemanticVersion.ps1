
function ConvertTo-WhsCISemanticVersion
{
    <#
    .SYNOPSIS
    Converts an object to a semantic version.

    .DESCRIPTION
    The `ConvertTo-WhsCISemanticVersion` function converts strings, numbers, and date/time objects to semantic versions. If the conversion fails, it writes an error and you get nothing back. It also adds build metadata. If run by a developer, the build metadata will be `$env:USERNAME@$env:COMPUTERNAME`. If run by a build server, the build metadata will be the build number, branch (from source control), and short commit ID (also from source control), separated by spaces, e.g. `80.develop.deadbee`. If the object passed in contains build information, it will be overwritten by the generated build information. To leave the original build metadata intact, use the `-PreserveBuildMetadata` switch.

    If the version doesn't have a patch number (e.g, `2`, `3.1`) and this function is running under a build server, the patch number will be set using the build server's build number/ID. Otherwise it will be set to `0`. 

    This function is designed to handle objects converted by YAML parsers. When some version numbers aren't surrounded by quotes, they are parsed as dates or numbers. For example, YAML parsers see

        Version: 1.2.3

    as January 2nd, 2003. The same is true for numbers, e.g. YAML parsers think `2.0` and `2` are numbers. This functions converts those correctly to semantic versions.

    .EXAMPLE
    '1.2.3' | ConvertTo-WhsCISemanticVersion

    Demonstrates how to convert a string to a semantic version.

    .EXAMPLE
    '1.2.3+build.info' | ConvertTo-WhsCISemanticVersion -PreserveBuildMetadata

    Demonstrates how to convert a string to a semantic version, preserving any build metadata that may or may not be in the original, i.e. the build metadata won't be replaced by the build metadata generated by this function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [object]
        # The object to convert to a semantic version. Can be a version string, number, or date/time.
        $InputObject,

        [Switch]
        # Use the build metadata from the original object, even if it doesn't exist. This stops `ConvertTo-WhsCISemanticVersion` from setting the build metadata based on the current build.
        $PreserveBuildMetadata
    )

    process
    {
        Set-StrictMode -Version 'Latest'
        Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

        if( -not $InputObject )
        {
            $InputObject = (Get-Date).ToString('yyyy.MMdd')
        }

        $buildInfo = $buildInfoWithBuildNumber = '{0}.{1}' -f $env:USERNAME,$env:COMPUTERNAME
        
        $patch = '0'
        if( (Test-WhsCIRunByBuildServer) )
        {
            $buildID = (Get-Item -Path 'env:BUILD_ID').Value
            $patch = $buildID
            $branch = (Get-Item -Path 'env:GIT_BRANCH').Value -replace '^origin/',''
            $branch = $branch -replace '[^A-Za-z0-9-]','-'
            $commitID = (Get-Item -Path 'env:GIT_COMMIT').Value.Substring(0,7)
            $buildInfo = '{0}.{1}' -f $branch,$commitID
            $buildInfoWithBuildNumber = '{0}.{1}.{2}' -f $buildID,$branch,$commitID
        }

        if( $InputObject -is [string] )
        {
            [int]$asInt = 0
            [double]$asDouble = 0.0
            [version]$asVersion = $null
            if( [version]::TryParse($InputObject,[ref]$asVersion) )
            {
                $InputObject = $asVersion.ToString()
                if( $asVersion.Build -le -1 )
                {
                    $InputObject = '{0}.{1}' -f $asVersion,$patch
                }
            }
            elseif( [int]::TryParse($InputObject,[ref]$asInt) )
            {
                $InputObject = $asInt
            }
            elseif( [double]::TryParse($InputObject,[ref]$asDouble) )
            {
                $InputObject = $asDouble
            }
        }
        
        if( $InputObject -is [datetime] )
        {
            $patch = $InputObject.Year
            if( $patch -ge 2000 )
            {
                $patch -= 2000
            }
            elseif( $patch -ge 1900 )
            {
                $patch -= 1900
            }
            $InputObject = '{0}.{1}.{2}' -f $InputObject.Month,$InputObject.Day,$patch
            $buildInfo = $buildInfoWithBuildNumber
        }
        elseif( $InputObject -is [double] )
        {
            $major,$minor = $InputObject.ToString('g') -split '\.'
            if( -not $minor )
            {
                $minor = '0'
            }
            $InputObject = '{0}.{1}.{2}' -f $major,$minor,$patch
        }
        elseif( $InputObject -is [int] )
        {
            $InputObject = '{0}.0.{1}' -f $InputObject,$patch
        }
        else
        {
            $buildInfo = $buildInfoWithBuildNumber
        }

        $semVersion = $null
        if( ([SemVersion.SemanticVersion]::TryParse($InputObject,[ref]$semVersion)) )
        {
            if( $PreserveBuildMetadata )
            {
                return $semVersion
            }

            return (New-Object -TypeName 'SemVersion.SemanticVersion' -ArgumentList ($semVersion.Major,$semVersion.Minor,$semVersion.Patch,$semVersion.Prerelease,$buildInfo))
        }

        Write-Error -Message ('Unable to convert ''{0}'' of type ''{1}'' to a semantic version.' -f $PSBoundParameters['InputObject'],$PSBoundParameters['InputObject'].GetType().FullName)
    }
}
