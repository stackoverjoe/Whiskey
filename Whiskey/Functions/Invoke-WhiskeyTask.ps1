function Invoke-WhiskeyTask
{
    <#
    .SYNOPSIS
    Runs a Whiskey task.

    .DESCRIPTION
    The `Invoke-WhiskeyTask` function runs a Whiskey task.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        # The context this task is operating in. Use `New-WhiskeyContext` to create context objects.
        [Whiskey.Context]$TaskContext,

        [Parameter(Mandatory)]
        # The name of the task.
        [string]$Name,

        [Parameter(Mandatory)]
        # The parameters/configuration to use to run the task.
        [hashtable]$Parameter
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    function Invoke-Event
    {
        param(
            $EventName,
            $Property
        )

        if( -not $events.ContainsKey($EventName) )
        {
            return
        }

        foreach( $commandName in $events[$EventName] )
        {
            Write-WhiskeyVerbose -Context $TaskContext -Message ''
            Write-WhiskeyVerbose -Context $TaskContext -Message ('[On{0}]  {1}' -f $EventName,$commandName)
            $startedAt = Get-Date
            $result = 'FAILED'
            try
            {
                $TaskContext.Temp = Join-Path -Path $TaskContext.OutputDirectory -ChildPath ('Temp.{0}.On{1}.{2}' -f $Name,$EventName,[IO.Path]::GetRandomFileName())
                if( -not (Test-Path -Path $TaskContext.Temp -PathType Container) )
                {
                    New-Item -Path $TaskContext.Temp -ItemType 'Directory' -Force | Out-Null
                }
                & $commandName -TaskContext $TaskContext -TaskName $Name -TaskParameter $Property
                $result = 'COMPLETED'
            }
            finally
            {
                Remove-WhiskeyFileSystemItem -Path $TaskContext.Temp
                $endedAt = Get-Date
                $duration = $endedAt - $startedAt
                Write-WhiskeyVerbose -Context $TaskContext ('{0}  {1} in {2}' -f (' ' * ($EventName.Length + 4)),$result,$duration)
                Write-WhiskeyVerbose -Context $TaskContext -Message ''
            }
        }
    }

    function Merge-Parameter
    {
        param(
            [hashtable]$SourceParameter,

            [hashtable]$TargetParameter
        )

        foreach( $key in $SourceParameter.Keys )
        {
            $sourceValue = $SourceParameter[$key]
            if( $TargetParameter.ContainsKey($key) )
            {
                $targetValue = $TargetParameter[$key]
                if( ($targetValue | Get-Member -Name 'Keys') -and ($sourceValue | Get-Member -Name 'Keys') )
                {
                    Merge-Parameter -SourceParameter $sourceValue -TargetParameter $targetValue
                }
                continue
            }

            $TargetParameter[$key] = $sourceValue
        }
    }

    function Get-RequiredTool
    {
        param(
            $CommandName
        )

        $cmd = Get-Command -Name $CommandName -ErrorAction Ignore 
        if( -not $cmd -or -not (Get-Member -InputObject $cmd -Name 'ScriptBlock') )
        {
            return
        }

        $cmd.ScriptBlock.Attributes |
            Where-Object { $_ -is [Whiskey.RequiresToolAttribute] }
    }
    $knownTasks = Get-WhiskeyTask -Force
    $task = $knownTasks | Where-Object { $_.Name -eq $Name }
    if( -not $task )
    {
        $task = $knownTasks | Where-Object { $_.Aliases -contains $Name }
        $taskCount = ($task | Measure-Object).Count
        if( $taskCount -gt 1 )
        {
            Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Found {0} tasks with alias "{1}". Please update to use one of these task names: {2}.' -f $taskCount,$Name,(($task | Select-Object -ExpandProperty 'Name') -join ', '))
            return
        }
        if( $task -and $task.WarnWhenUsingAlias )
        {
            Write-Warning -Message ('Task "{0}" is an alias to task "{1}". Please update "{2}" to use the task''s actual name, "{1}", instead of the alias.' -f $Name,$task.Name,$TaskContext.ConfigurationPath)
        }
    }

    if( -not $task )
    {
        $knownTaskNames = $knownTasks | Select-Object -ExpandProperty 'Name' | Sort-Object
        throw ('{0}: {1}[{2}]: ''{3}'' task does not exist. Supported tasks are:{4} * {5}' -f $TaskContext.ConfigurationPath,$Name,$TaskContext.TaskIndex,$Name,[Environment]::NewLine,($knownTaskNames -join ('{0} * ' -f [Environment]::NewLine)))
    }

    $taskCount = ($task | Measure-Object).Count
    if( $taskCount -gt 1 )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Found {0} tasks named "{1}". We don''t know which one to use. Please make sure task names are unique.' -f $taskCount,$Name)
        return
    }

    $TaskContext.TaskName = $Name

    if( $task.Obsolete )
    {
        $message = 'The "{0}" task is obsolete and shouldn''t be used.' -f $task.Name
        if( $task.ObsoleteMessage )
        {
            $message = $task.ObsoleteMessage
        }
        Write-WhiskeyWarning -Context $TaskContext -Message $message
    }

    if( -not $task.Platform.HasFlag($CurrentPlatform) )
    {
        Write-Error -Message ('Unable to run task "{0}": it is only supported on the {1} platform(s) and we''re currently running on {2}.' -f $task.Name,$task.Platform,$CurrentPlatform) -ErrorAction Stop
        return
    }

    if( $TaskContext.TaskDefaults.ContainsKey( $Name ) )
    {
        Merge-Parameter -SourceParameter $TaskContext.TaskDefaults[$Name] -TargetParameter $Parameter
    }

    Resolve-WhiskeyVariable -Context $TaskContext -InputObject $Parameter | Out-Null

    [hashtable]$taskProperties = $Parameter.Clone()
    $commonProperties = @{}
    foreach( $commonPropertyName in @( 'OnlyBy', 'ExceptBy', 'OnlyOnBranch', 'ExceptOnBranch', 'OnlyDuring', 'ExceptDuring', 'WorkingDirectory', 'IfExists', 'UnlessExists', 'OnlyOnPlatform', 'ExceptOnPlatform' ) )
    {
        if ($taskProperties.ContainsKey($commonPropertyName))
        {
            $commonProperties[$commonPropertyName] = $taskProperties[$commonPropertyName]
            $taskProperties.Remove($commonPropertyName)
        }
    }

    $workingDirectory = $TaskContext.BuildRoot
    if( $Parameter['WorkingDirectory'] )
    {
        $workingDirectory = $Parameter['WorkingDirectory'] | Resolve-WhiskeyTaskPath -TaskContext $TaskContext -PropertyName 'WorkingDirectory'
    }

    $taskTempDirectory = ''
    $requiredTools = Get-RequiredTool -CommandName $task.CommandName
    $startedAt = Get-Date
    $result = 'FAILED'
    $currentDirectory = [IO.Directory]::GetCurrentDirectory()
    Push-Location -Path $workingDirectory
    [IO.Directory]::SetCurrentDirectory($workingDirectory)
    try
    {
        if( Test-WhiskeyTaskSkip -Context $TaskContext -Properties $commonProperties)
        {
            $result = 'SKIPPED'
            return
        }

        if( $TaskContext.ShouldClean )
        {
            if( -not $task.SupportsClean )
            {
                Write-WhiskeyVerbose -Context $TaskContext -Message ('SupportsClean.{0} -ne Build.ShouldClean.{1}' -f $task.SupportsClean,$TaskContext.ShouldClean)
                $result = 'SKIPPED'
                return
            }
        }

        foreach( $requiredTool in $requiredTools )
        {
            Install-WhiskeyTool -ToolInfo $requiredTool `
                                -InstallRoot $TaskContext.BuildRoot `
                                -TaskParameter $taskProperties `
                                -InCleanMode:$TaskContext.ShouldClean `
                                -ErrorAction Stop
        }

        if( $TaskContext.ShouldInitialize -and -not $task.SupportsInitialize )
        {
            Write-WhiskeyVerbose -Context $TaskContext -Message ('SupportsInitialize.{0} -ne Build.ShouldInitialize.{1}' -f $task.SupportsInitialize,$TaskContext.ShouldInitialize)
            $result = 'SKIPPED'
            return
        }

        Invoke-Event -EventName 'BeforeTask' -Property $taskProperties
        Invoke-Event -EventName ('Before{0}Task' -f $Name) -Property $taskProperties

        Write-WhiskeyVerbose -Context $TaskContext -Message ''
        $startedAt = Get-Date
        $taskTempDirectory = Join-Path -Path $TaskContext.OutputDirectory -ChildPath ('Temp.{0}.{1}' -f $Name,[IO.Path]::GetRandomFileName())
        $TaskContext.Temp = $taskTempDirectory
        if( -not (Test-Path -Path $TaskContext.Temp -PathType Container) )
        {
            New-Item -Path $TaskContext.Temp -ItemType 'Directory' -Force | Out-Null
        }

        $parameter = Get-TaskParameter -Name $task.CommandName -TaskProperty $taskProperties -Context $TaskContext
        & $task.CommandName @parameter
        $result = 'COMPLETED'
    }
    finally
    {
        # Clean required tools *after* running the task since the task might need a required tool in order to do the cleaning (e.g. using Node to clean up installed modules)
        if( $TaskContext.ShouldClean )
        {
            foreach( $requiredTool in $requiredTools )
            {
                Uninstall-WhiskeyTool -BuildRoot $TaskContext.BuildRoot -ToolInfo $requiredTool
            }
        }

        if( $taskTempDirectory -and (Test-Path -Path $taskTempDirectory -PathType Container) )
        {
            Remove-Item -Path $taskTempDirectory -Recurse -Force -ErrorAction Ignore
        }
        $endedAt = Get-Date
        $duration = $endedAt - $startedAt
        Write-WhiskeyVerbose -Context $TaskContext -Message ('{0} in {1}' -f $result,$duration)
        Write-WhiskeyVerbose -Context $TaskContext -Message ''
        [IO.Directory]::SetCurrentDirectory($currentDirectory)
        Pop-Location
    }

    Invoke-Event -EventName 'AfterTask' -Property $taskProperties
    Invoke-Event -EventName ('After{0}Task' -f $Name) -Property $taskProperties
}