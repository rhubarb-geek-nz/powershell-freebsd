# rhubarb-geek-nz/powershell-freebsd

Packages [PowerShell](https://github.com/PowerShell/PowerShell) for FreeBSD.

## Overview

In this project, PowerShell is built in a Linux environment which has `freebsd-arm64` and `freebsd-x64` packs added to the .NET SDK.

## Build process

Multiple environments are required to build the final packages.

## 1. On Linux

### 1.1. Bootstrap the Linux build environment. 
    
Setup the build environment to target FreeBSD on Linux. This is not as hard as it sounds, [bootstrap.ps1](bootstrap.ps1) should perform all the steps. Run this in as minimal environment as you can without an installed .NET SDK (eg in a `docker`) but with PowerShell.

1. The [PowerShell](https://github.com/PowerShell/PowerShell) project is cloned from git.

2. [Patches](github-PowerShell.patch) are applied.

3. The PowerShell `Start-PSBootstrap` is run to install a local copy of the matching .NET SDK.

4. The `freebsd-arm64` and `freebsd-x64` runtime and apphost packs from [sec/dotnet-core-freebsd-source-build](https://github.com/sec/dotnet-core-freebsd-source-build) are added to the SDK.

5. The SDK configuration is updated to recognize those new packs.

### 1.2. Compile the application

Compile the application with [compile.ps1](compile.ps1) which uses `freebsd-arm64` and `freebsd-x64` as the targets.

## 2. On FreeBSD

`FreeBSD` with the target architecture is used to build the final package.

1. Transfer the appropriate 'powershell-v7.4.5-freebsd-*.tar.gz' to the `FreeBSD` machine from the `Linux` environment.

2. Build the `libpsl-native.so` on the native host using [compile.sh](compile.sh).

3. [Package](package.sh) the `FreeBSD` package file, this combines the result of the cross-compilation and the local `libpsl-native.so`.

The resulting package depends on the `dotnet-runtime-8.0` package from [rhubarb-geek-nz/dotnet-freebsd](https://github.com/rhubarb-geek-nz/dotnet-freebsd)

## Patching

The patches include the following

1. Add `freebsd-arm64` and `freebsd-x64` as valid targets to the build tools.

2. Change the `powershell-unix.csproj` to not be a self-contained application. The result will use the host's `.NET` runtime.

3. Change `Program.cs` which has `Linux` and `MacOS` mechanisms to get the application program name and path and replaces them with `FreeBSD` mechanisms .

## Known Issues

This is not a heavily tested target.

1. Interactive mode does not work well on `arm64`.

2. Strongly recommend don't run as `root`.

3. `NamedPipeIPC_ServerListenerError` appears on the system console when using interactive mode.

## Any feedback welcome.
