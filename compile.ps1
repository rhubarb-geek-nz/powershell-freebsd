#!/usr/bin/env pwsh
# Copyright (c) 2024 Roger Brown.
# Licensed under the MIT License.

Param($ReleaseTag = 'v7.4.5')

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$WorkDir = 'github-PowerShell'
$Env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

trap
{
	throw $PSItem
}

if (-not ( Test-Path $WorkDir ))
{
	sh -c "git clone https://github.com/PowerShell/PowerShell.git $WorkDir --single-branch --branch $ReleaseTag"

	if ($LastExitCode)
	{
		exit $LastExitCode
	}

	Push-Location $WorkDir

	try
	{
		git apply "../$WorkDir.patch"

		if ($LastExitCode)
		{
			throw "LastExitCode $LastExitCode"
		}
	}
	finally
	{
		Pop-Location
	}
}

Push-Location $WorkDir

try
{
	Import-Module ./build.psm1
	Start-PSBootstrap

	foreach ($Arch in 'arm64', 'x64')
	{
		$RID = "freebsd-$Arch"

		Start-PSBuild -Clean -Configuration Release -ReleaseTag $ReleaseTag -Runtime $RID

@"
		(
			set -e
			cd src/powershell-unix/bin/Release/net*/$RID/publish
			find . -type l | xargs rm
			tar cfz - *
		) > ../powershell-$ReleaseTag-$RID.tar.gz
"@ | sh -e

		if ($LastExitCode)
		{
			throw "LastExitCode $LastExitCode"
		}				
	}
}
finally
{
	Pop-Location
}
