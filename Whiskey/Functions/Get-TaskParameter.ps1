
function Get-TaskParameter
{
    [CmdletBinding()]
    param(
        # The name of the command.
        [Parameter(Mandatory)]
        [string]$Name,

        # The properties from the tasks's YAML.
        [Parameter(Mandatory)]
        [hashtable]$TaskProperty,

        # The current context.
        [Parameter(Mandatory)]
        [Whiskey.Context]$Context
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    
    # Parameters of the actual command.
    $cmdParameters =
        Get-Command -Name $task.CommandName |
        Select-Object -ExpandProperty 'Parameters'

    # Parameters to pass to the command.
    $taskParameters = @{ }

    [Management.Automation.ParameterMetadata]$cmdParameter = $null

    foreach( $cmdParameter in $cmdParameters.Values )
    {
        $propertyName = $cmdParameter.Name

        $value = $TaskProperty[$propertyName]

        # PowerShell can't implicitly convert strings to bool/switch values so we have to do it.
        if( $cmdParameter.ParameterType -eq [Switch] -or $cmdParameter.ParameterType -eq [bool] )
        {
            $value = $value | ConvertFrom-WhiskeyYamlScalar
        }

        [Whiskey.Tasks.ParameterValueFromVariableAttribute]$valueFromVariableAttr =
            $cmdParameter.Attributes |
            Where-Object { $_ -is [Whiskey.Tasks.ParameterValueFromVariableAttribute] }

        if( $valueFromVariableAttr )
        {
            $value = Resolve-WhiskeyVariable -InputObject ('$({0})' -f $valueFromVariableAttr.VariableName) `
                                             -Context $Context
        }

        [Whiskey.Tasks.ValidatePathAttribute]$validateAsPathAttribute =
            $cmdParameter.Attributes |
            Where-Object { $_ -is [Whiskey.Tasks.ValidatePathAttribute] }

        if( $validateAsPathAttribute )
        {
            $params = @{ }

            $params['PropertyName'] = $propertyName
            $params['CmdParameter'] = $cmdParameter
            $params['ValidateAsPathAttribute'] = $validateAsPathAttribute
            $value = $value | Resolve-WhiskeyTaskPathParameter -TaskContext $Context @params
        }

        # If the user didn't provide a value and we couldn't find one, don't pass anything.
        if( -not $TaskProperty.ContainsKey($propertyName) -and -not $value )
        {
            continue
        }

        $taskParameters[$propertyName] = $value
        $TaskProperty.Remove($propertyName)
    }

    foreach( $name in @( 'TaskContext', 'Context' ) )
    {
        if( $cmdParameters.ContainsKey($name) )
        {
            $taskParameters[$name] = $Context
        }
    }

    foreach( $name in @( 'TaskParameter', 'Parameter' ) )
    {
        if( $cmdParameters.ContainsKey($name) )
        {
            $taskParameters[$name] = $TaskProperty
        }
    }

    return $taskParameters
}
