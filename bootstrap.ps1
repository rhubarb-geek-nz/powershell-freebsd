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
		$OriginalName = "dotnet-sdk-8.0.108-freebsd-$Arch.tar.gz"

		$Uri = "https://github.com/sec/dotnet-core-freebsd-source-build/releases/download/8.0.108-vmr/$OriginalName"
		Invoke-WebRequest -Uri $Uri -OutFile $OriginalName

@"
mkdir sdk
tar xfz $OriginalName -C sdk ./packs
for d in sdk/packs/*freebsd*
do
	e=`$(basename `$d)
	if test ! -d `$HOME/.dotnet/packs/`$e
	then
		mv `$d `$HOME/.dotnet/packs/`$e
	fi
done
rm -rf sdk
"@ | sh -e

		if ($LastExitCode)
		{
			throw "LastExitCode $LastExitCode"
		}

		Remove-Item $OriginalName
	}

	$RIDList = @('freebsd-arm64', 'freebsd-x64')

	$BasePath = sh -c 'dotnet --info | grep "^ Base Path:" | while read A B C; do echo $C; done'

	$BasePath

	$PackPath = Join-Path $BasePath '../../packs'

	$Properties = Join-Path $BasePath 'Microsoft.NETCoreSdk.BundledVersions.props'

	[xml]$xml = Get-Content $Properties

	foreach ($Node in $xml.SelectNodes('/Project/ItemGroup/KnownFrameworkReference'))
	{
		if ($Node.RuntimePackNamePatterns -and $Node.RuntimePackNamePatterns.EndsWith('**RID**'))
		{
			foreach ($RID in $RIDList)
			{
				$RuntimePackName = $Node.RuntimePackNamePatterns.Replace('**RID**',$RID)
				$TargetingPackVersion = $Node.TargetingPackVersion

				$Pack = Join-Path $PackPath "$RuntimePackName/$TargetingPackVersion"

				if (Test-Path $Pack)
				{
					$Pack

					$RIDs = $Node.RuntimePackRuntimeIdentifiers

					if (-not ($RIDs.Split(';') -Contains $RID))
					{
						$Node.RuntimePackRuntimeIdentifiers = "$RIDs;$RID"
					}
				}
			}
		}
	}

	foreach ($Node in $xml.SelectNodes('/Project/ItemGroup/KnownAppHostPack'))
	{
		if ($Node.AppHostPackNamePattern -and $Node.AppHostPackNamePattern.EndsWith('**RID**'))
		{
			foreach ($RID in $RIDList)
			{
				$AppHostPackName = $Node.AppHostPackNamePattern.Replace('**RID**',$RID)
				$AppHostPackVersion = $Node.AppHostPackVersion

				$Pack = Join-Path $PackPath "$AppHostPackName/$AppHostPackVersion"

				if (Test-Path $Pack)
				{
					$Pack

					$RIDs = $Node.AppHostRuntimeIdentifiers

					if (-not ($RIDs.Split(';') -Contains $RID))
					{
						$Node.AppHostRuntimeIdentifiers = "$RIDs;$RID"
					}
				}
			}
		}
	}

	$xml.Save($Properties)
}
finally
{
	Pop-Location
}
