#region Script Parameters

    # Set-Location -LiteralPath 'D:\My Data\Dev\dstammen\Apps\_Demos\DMS.Demo.GitVersion.CMD.AssemblyInfo';
    # powershell -ExecutionPolicy Bypass -File '.\.Scripts\Build Scripts\1-Pre-build\Invoke-DotNetToolAction.ps1' -ToolName 'GitVersion.Tool' -Action 'Install' -SolutionDir ((Get-Location).Path)
    # <Exec Command='powershell -ExecutionPolicy Bypass -File ".\.Scripts\Build Scripts\1-Pre-build\Invoke-DotNetToolAction.ps1" -ToolName "GitVersion.Tool" -Action "Install" -SolutionDir "$(SolutionDir)' />
    Param(
        [Parameter(Position=0, Mandatory = $true, HelpMessage='Please provide the name of the tool.')]
        [String]$ToolName,

        [Parameter(Position=1, Mandatory = $false, HelpMessage='Please provide the action for the script to perform.')]
        [ValidateSet('Install', 'Uninstall')]
        [String]$Action = 'Install',

        [Parameter(Position=2, HelpMessage='Switch to specify the tool should be installed globally instead of locally.')]
        [Switch]$Global,

        [Parameter(Position=3, Mandatory = $false, HelpMessage='Please provide the directory where the solution is stored.')]
        [String]$SolutionDir = $null,

        [Parameter(Position=4, HelpMessage='Switch to specify the tool should be updated if it is not the latets version.')]
        [Switch]$AutoUpdateTool,

        [Parameter(Position=5, HelpMessage='Switch to specify whether the tool manifest should be removed or not.')]
        [Switch]$RemoveToolManifest
    ) #End Param

#endregion Script Parameters

#region TestParams
    
    <#
    [String]$ToolName = 'GitVersion.Tool';
    [String]$Action = 'Install';
    [Switch]$Global = $false;
    [String]$SolutionDir = (Get-Location).Path;
    [Switch]$AutoUpdateTool = $false;
    [Switch]$RemoveToolManifest = $false;
    #>

#endregion TestParams

#region Script Preferences

    Write-Output -InputObject 'Defining Script Preferences.';
    $ActionPreferences = [System.Management.Automation.ActionPreference];
    $VerbosePreference = $ActionPreferences::Continue;
    $InformationPreference = $ActionPreferences::Continue;
    $DebugPreference = $ActionPreferences::Continue;
    $WarningPreference = $ActionPreferences::Continue;
    $ErrorActionPreference = $ActionPreferences::Continue;

#endregion Script Preferences

#region Script Constants

    Write-Debug -Message 'Defining script constants.';
    [String]$ManifestFile = '.config/dotnet-tools.json';

#endregion Script Constants

#region Functions
    
    Write-Debug -Message 'Defining functions.';
    Function Install-DotNetTool()
    {
        Param(
            [Parameter(Position=0, Mandatory = $true, HelpMessage='Please provide the name of the tool.')]
            [String]$ToolName,

            [Parameter(Position=1, Mandatory = $false, HelpMessage='Value to specify the tool should be installed globally instead of locally.')]
            [Bool]$IsGlobal = $false,

            [Parameter(Position=2, Mandatory = $false, HelpMessage='Please provide the directory where the solution is stored.')]
            [String]$SolutionDir = $null,

            [Parameter(Position=3, Mandatory = $false, HelpMessage='Value to specify the tool should be updated if it is not the latets version.')]
            [Bool]$ShouldAutoUpdateTool = $false
        ) #End Param

        # Check for data on the tool provided to validate that it is valid and gather info on it.
        Write-Debug -Message "Checking if tool '$($ToolName)' is valid.";
        [String]$ToolMetaData = dotnet tool search $ToolName | Select-String $ToolName;
        if (-Not($ToolMetaData)) { throw "Invalid tool: '$ToolName'"; } else { Write-Debug -Message "Tool '$($ToolName)' is valid."; }

        # Check that the tool should be uninstalled locally and the provided solution directory exists.
        if (-not($IsGlobal))
        {
            Write-Debug -Message 'Tool is NOT set to be global.';
            if (-not(Test-Path -LiteralPath $SolutionDir))
            {
                # Throw exception.
                throw "Solution directory was not found: '$($SolutionDir)'";
            }
            else
            {
                # Set the working directory to the solution directory.
                if ((Get-Location).Path -ne $SolutionDir)
                {
                    Write-Verbose -Message "Setting location to '$($SolutionDir)'.";
                    Set-Location -LiteralPath $SolutionDir;
                }
            }
        }
        else
        {
            Write-Debug -Message 'Tool IS set to be global.';
        }

        # Add the manifest file for local tools if it does not exist.
        if (-Not($IsGlobal))
        {
            # Check if the tool manifest exists (project-specific tools)
            if (-not (Test-Path $ManifestFile)) {
                Write-Verbose -Message 'No tool manifest found. Creating it...';
                dotnet new tool-manifest;
            }
        }

        # Check if tool is installed.
        [Bool]$ToolInstalled = $false;
        [String]$InstalledToolData = $null;
        Write-Debug -Message "Checking if tool '$($ToolName)' is installed.";
        if ($IsGlobal)
        {
            $InstalledToolData = dotnet tool list --global | Where-Object { $_ -match $ToolName };
            $ToolInstalled = if($InstalledToolData) { $true; } else { $false; }
        }
        else
        {
            $InstalledToolData = dotnet tool list | Where-Object { $_ -match $ToolName };
            $ToolInstalled = if($InstalledToolData) { $true; } else { $false; }
        }

        # Check if the tool is installed. If not, install it.
        if (-not($ToolInstalled))
        {
            Write-Verbose -Message "Tool '$ToolName' is NOT installed. Installing...";
            if ($IsGlobal) {dotnet tool install --global $ToolName; } else { dotnet tool install $ToolName; }
        }
        else
        {
            $ToolVersion = ($InstalledToolData -split '\s+')[1];
            Write-Debug -Message "Tool '$ToolName' IS installed. Version: $ToolVersion";
            if ($ShouldAutoUpdateTool)
            {
                $LatestToolVersion = $ToolMetaData | ForEach-Object { ($_ -split '\s+')[1]; }
                Write-Information -MessageData "Latest version on NuGet: $LatestToolVersion";

                if ($ToolVersion -ne $LatestToolVersion)
                {
                    Write-Verbose -Message "Updating '$ToolName' to version '$LatestToolVersion'.";
                    if ($IsGlobal) { dotnet tool update --global $ToolName;} else { dotnet tool update $ToolName;}
                }
                else
                {
                    Write-Debug -Message "'$ToolName' is up to date.";
                }
            }
        }
    } #end Function Install-DotNetTool

    Function Install-LocalDotNetTool()
    {
        Param(
            [Parameter(Position=0, Mandatory = $true, HelpMessage='Please provide the name of the tool.')]
            [String]$ToolName,

            [Parameter(Position=1, Mandatory = $true, HelpMessage='Please provide the directory where the solution is stored.')]
            [String]$SolutionDir,

            [Parameter(Position=2, Mandatory = $false, HelpMessage='Value to specify the tool should be updated if it is not the latets version.')]
            [Bool]$ShouldAutoUpdateTool = $false
        ) #End Param

        Install-DotNetTool -ToolName $ToolName -IsGlobal $false -SolutionDir $SolutionDir -ShouldAutoUpdateTool $ShouldAutoUpdateTool;
    } #end Function Install-LocalDotNetTool

    Function Install-GlobalDotNetTool()
    {
        Param(
            [Parameter(Position=0, Mandatory = $true, HelpMessage='Please provide the name of the tool.')]
            [String]$ToolName,

            [Parameter(Position=1, Mandatory = $false, HelpMessage='Value to specify the tool should be updated if it is not the latets version.')]
            [Bool]$ShouldAutoUpdateTool = $false
        ) #End Param

        Install-DotNetTool -ToolName $ToolName -IsGlobal $true -ShouldAutoUpdateTool $ShouldAutoUpdateTool;
    } #end Function Install-GlobalDotNetTool

    Function Uninstall-DotNetTool()
    {
        Param(
            [Parameter(Position=0, Mandatory = $true, HelpMessage='Please provide the name of the tool.')]
            [String]$ToolName,

            [Parameter(Position=1, Mandatory = $false, HelpMessage='Value to specify the tool should be installed globally instead of locally.')]
            [Bool]$IsGlobal = $false,

            [Parameter(Position=2, Mandatory = $false, HelpMessage='Please provide the directory where the solution is stored.')]
            [String]$SolutionDir = $null,

            [Parameter(Position=3, Mandatory = $false, HelpMessage='Value to specify whether the tool manifest should be removed or not.')]
            [Bool]$ShouldRemoveToolManifest = $false
        ) #End Param

        # Check that the tool should be uninstalled locally and the provided solution directory exists.
        if (-not($IsGlobal))
        {
            Write-Debug -Message 'Tool is NOT set to be global.';
            if (-not(Test-Path -LiteralPath $SolutionDir))
            {
                # Throw exception.
                throw "Solution directory was not found: '$($SolutionDir)'";
            }
            else
            {
                # Set the working directory to the solution directory.
                if ((Get-Location).Path -ne $SolutionDir)
                {
                    Write-Verbose -Message "Setting location to '$($SolutionDir)'.";
                    Set-Location -LiteralPath $SolutionDir;
                }
            }
        }
        else
        {
            Write-Debug -Message 'Tool IS set to be global.';
        }

        # Check if tool is installed.
        [Bool]$ToolInstalled = $false;
        [String]$InstalledToolData = $null;
        Write-Debug -Message "Checking if tool '$($ToolName)' is installed.";
        if ($IsGlobal)
        {
            $InstalledToolData = dotnet tool list --global | Where-Object { $_ -match $ToolName };
            $ToolInstalled = if($InstalledToolData) { $true; } else { $false; }
        }
        else
        {
            $InstalledToolData = dotnet tool list | Where-Object { $_ -match $ToolName };
            $ToolInstalled = if($InstalledToolData) { $true; } else { $false; }
        }

         # Check if the tool is installed. If it is, uninstall it.
        if (-not($ToolInstalled))
        {
            Write-Debug -Message "Tool '$ToolName' is NOT installed.";
        }
        else
        {
            Write-Verbose -Message "Tool '$ToolName' IS installed. Uninstalling...";
            if ($IsGlobal)
            {
                dotnet tool uninstall --global $ToolName;
            }
            else
            {
                dotnet tool uninstall $ToolName;
                if ($ShouldRemoveToolManifest)
                {
                    $ManifestFilePath = "$SolutionDir\$ManifestFile";
                    if (Test-Path -LiteralPath $ManifestFilePath)
                    {
                        Write-Verbose -Message "Removing manifest file '$ManifestFilePath'.";
                        Remove-Item -LiteralPath $ManifestFilePath -Force;
                    }
                }
            }
        }
    } #end Function Uninstall-DotNetTool

    Function Uninstall-LocalDotNetTool()
    {
        Param(
            [Parameter(Position=0, Mandatory = $true, HelpMessage='Please provide the name of the tool.')]
            [String]$ToolName,

            [Parameter(Position=1, Mandatory = $false, HelpMessage='Please provide the directory where the solution is stored.')]
            [String]$SolutionDir = $null,

            [Parameter(Position=2, Mandatory = $false, HelpMessage='Value to specify whether the tool manifest should be removed or not.')]
            [Bool]$ShouldRemoveToolManifest = $false
        ) #End Param

        Uninstall-DotNetTool -ToolName $ToolName -IsGlobal $false -SolutionDir $SolutionDir;
    } #end Function Uninstall-LocalDotNetTool

    Function Uninstall-GlobalDotNetTool()
    {
        Param(
            [Parameter(Position=0, Mandatory = $true, HelpMessage='Please provide the name of the tool.')]
            [String]$ToolName
        ) #End Param

        Uninstall-DotNetTool -ToolName $ToolName -IsGlobal $true;
    } #end Function Uninstall-GlobalDotNetTool

#endregion Functions

#region Script Core

    if ($Action -eq 'Install')
    {
        if ($Global.IsPresent)
        {
            #Install-GlobalDotNetTool -ToolName 'GitVersion.Tool' -ShouldAutoUpdateTool $true;
            Install-GlobalDotNetTool -ToolName $ToolName -ShouldAutoUpdateTool $AutoUpdateTool.IsPresent;
        }
        else
        {
            #Install-LocalDotNetTool -ToolName 'GitVersion.Tool' -SolutionDir ((Get-Location).Path) -ShouldAutoUpdateTool $true;
            Install-LocalDotNetTool -ToolName $ToolName -SolutionDir $SolutionDir -ShouldAutoUpdateTool $AutoUpdateTool.IsPresent;
        }
    }
    elseif ($Action -eq 'Uninstall')
    {
        if ($Global.IsPresent)
        {
            #Uninstall-GlobalDotNetTool -ToolName 'GitVersion.Tool';
            Uninstall-GlobalDotNetTool -ToolName $ToolName;
        }
        else
        {
            #Uninstall-LocalDotNetTool -ToolName 'GitVersion.Tool' -SolutionDir ((Get-Location).Path) -ShouldRemoveToolManifest $true;
            Uninstall-LocalDotNetTool -ToolName $ToolName -SolutionDir $SolutionDir -ShouldRemoveToolManifest $RemoveToolManifest.IsPresent;
        }
    }

#endregion Script Core