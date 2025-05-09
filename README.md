# DMS.Demo.GitVersion.CMD.ProjectFile
Steps taken to replicate:
1. Create a new project in Visual Studio.
2. Add the new project to Git source control.
3. Create a new branch from the master branch named 'feature/add-gitversion' & checkout.
4. Add the GitVersion config file to the solution directory or run this command in the developer PowerShell windows after opening the solution: $gitverfile = '.\gitversion.yml'; New-Item -Path $gitverfile -ItemType File -Force;
5. Add the GitVersion config file content. Find the GitHubFlow/v1 example @ https://gitversion.net/docs/reference/configuration.
6. Add folder structure and 'Invoke-DotNetToolAction.ps1' script as seen in '.Scripts\Build Scripts\1-Pre-Build' or below.
7. Configure the .csproj file to use GitVersion. See code below.
8. Initialize GitVersion by building the project.

Invoke-DotNetToolAction.ps1:
```
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
```

.csproj:
```
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <!-- Log the build macro values. -->
  <Target Name="Log Macros" BeforeTargets="PreBuildEvent">
    <Message Text="OutputPath: $(OutputPath)" Importance="high" />
    <Message Text="Configuration: $(Configuration)" Importance="high" />
    <Message Text="MSBuildProjectName: $(MSBuildProjectName)" Importance="high" />
    <Message Text="TargetName: $(TargetName)" Importance="high" />
    <Message Text="TargetPath: $(TargetPath)" Importance="high" />
    <Message Text="MSBuildProjectFile: $(MSBuildProjectFile)" Importance="high" />
    <Message Text="MSBuildProjectName: $(MSBuildProjectName)" Importance="high" />
    <Message Text="TargetExt: $(TargetExt)" Importance="high" />
    <Message Text="TargetFileName: $(TargetFileName)" Importance="high" />
    <Message Text="DevEnvDir: N/A" Importance="high" />
    <Message Text="OutputPath: $(OutputPath)" Importance="high" />
    <Message Text="MSBuildProjectDirectory: $(MSBuildProjectDirectory)" Importance="high" />
    <Message Text="SolutionName: $(SolutionName)" Importance="high" />
    <Message Text="SolutionPath: $(SolutionPath)" Importance="high" />
    <Message Text="SolutionDir: $(SolutionDir)" Importance="high" />
    <Message Text="SolutionName: $(SolutionName)" Importance="high" />
    <Message Text="Platform: $(Platform)" Importance="high" />
    <Message Text="ProjectExt: $(MSBuildProjectExtension)" Importance="high" />
    <Message Text="SolutionExt: $(SolutionExt)" Importance="high" />
  </Target>

  <!-- Update the .csproj file using GitVersion -->
  <Target Name="Update-ProjectVersions" BeforeTargets="PreBuildEvent" Condition="'$(TargetFramework)' == 'net8.0' Or $(TargetFramework) &gt; 'net8.0'">
    <Message Text="Ensuring GitVersion is installed." Importance="high" />
    <Exec Command='powershell -ExecutionPolicy Bypass -File ".\.Scripts\Build Scripts\1-Pre-build\Invoke-DotNetToolAction.ps1" -ToolName "GitVersion.Tool" -Action "Install" -SolutionDir "$(SolutionDir)' />
    <Message Text="Updating project versions in '$(SolutionDir)'." Importance="high" />
    <!-- Should be dotnet-gitversion if global, otherwise dotnet dotnet-gitversion. -->
    <Exec Command="dotnet dotnet-gitversion /updateprojectfiles" />
  </Target>

  <!-- Read assembly information -->
  <Target Name="ExtractVersionAfterBuild" AfterTargets="PostBuildEvent">
    <Message Text="Package Version: $(Version)" Importance="high" />
  </Target>

  <ItemGroup>
    <None Include=".Scripts\Build Scripts\1-Pre-build\Invoke-DotNetToolAction.ps1" />
  </ItemGroup>

  <ItemGroup>
    <Folder Include=".Scripts\Build Scripts\2-Post-build\" />
  </ItemGroup>

</Project>

```