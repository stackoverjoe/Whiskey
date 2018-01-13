function Remove-WhiskeyItem
{
    <#
    .SYNOPSIS
    Deletes files or directories.

    .DESCRIPTION
    The `Delete` task deletes files or directories. If the file/directory doesn't exist, nothing happens.

    This task also deletes files when a build is cleaning.

    ## Properties
    * `Path` (mandatory): a list of paths to delete. Must be relative to the `whiskey.yml` file. Paths that don't exist are ignored. Wildcards are allowed.

    ## Examples

    ### Example 1

    BuildTasks:
    - Delete:
        Path:
        - result.json
        - .output\*.upack
    
    This example demonstrates how to use the `Delete` task to delete files. In this case, the `result.json` and all `.upack` files in the `.output` directory are removed.

    ### Example 2

    BuildTasks:
    - Delete:
        Path:
        - Test\bin
        - Test\obj
    
    This example demonstrates how to use the `Delete` task to delete directories. In this case, the `Test\bin` and `Test\obj` directories will be deleted.
    #>
    [Whiskey.TaskAttribute('Delete', SupportsClean=$true)]
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
    
    foreach( $path in $TaskParameter['Path'] )
    {
        $path = $path | Resolve-WhiskeyTaskPath -TaskContext $TaskContext -PropertyName 'Path' -ErrorAction Ignore
        if( -not $path )
        {
            continue
        }

        $path | 
            Where-Object { (Test-Path -Path $_) } |
            ForEach-Object { Remove-Item -Path ('\\?\{0}' -f $_) -Force -Recurse }
    }
}