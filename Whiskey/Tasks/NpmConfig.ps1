
function Invoke-WhiskeyNpmConfig
{
    [Whiskey.Task('NpmConfig',Obsolete,ObsoleteMessage='The "NpmConfig" task is obsolete. It will be removed in a future version of Whiskey. Please use the "Npm" task instead.')]
    [Whiskey.RequiresTool('Node',PathParameterName='NodePath',VersionParameterName='NodeVersion')]
    param(
        [Parameter(Mandatory)]
        [Whiskey.Context]$TaskContext,

        [Parameter(Mandatory)]
        [hashtable]$TaskParameter
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $configuration = $TaskParameter['Configuration']
    if( -not $configuration )
    {
        Write-WhiskeyWarning -Context $TaskContext -Message ('Your NpmConfig task isn''t doing anything. Its Configuration property is missing. Please update the NpmConfig task in your whiskey.yml file so that it is actually setting configuration, e.g.

    Build:
    - NpmConfig:
        Configuration:
            key1: value1
            key2: value2
            ')
        return
    }

    if( -not ($configuration | Get-Member -Name 'Keys') )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Configuration property is invalid. It must have only key/value pairs, e.g.

    Build:
    - NpmConfig:
        Configuration:
            key1: value1
            key2: value2
     ')
        return
    }

    $scope = $TaskParameter['Scope']
    if( $scope )
    {
        if( @('Project', 'User', 'Global') -notcontains $scope )
        {
            Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Scope property ''{0}'' is invalid. Allowed values are `Project`, `User`, `Global` to set configuration at the project, user, or global level. You may also remove the `Scope` property to set configuration at the project level (i.e. in the current directory).' -f $scope)
            return
        }
    }

    foreach( $key in $TaskParameter['Configuration'].Keys )
    {
        $argumentList = & {
                                'set'
                                $key
                                $configuration[$key]
                                if( $scope -eq 'User' )
                                {
                                }
                                elseif( $scope -eq 'Global' )
                                {
                                    '-g'
                                }
                                else
                                {
                                    '-userconfig'
                                    '.npmrc'
                                }
                        }

        Invoke-WhiskeyNpmCommand -Name 'config' -ArgumentList $argumentList -BuildRootPath $TaskContext.BuildRoot -ForDeveloper:$TaskContext.ByDeveloper
    }

}