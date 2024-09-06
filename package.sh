#!/bin/sh -e
# Copyright (c) 2024 Roger Brown.
# Licensed under the MIT License.

RIDARCH=$(uname -p)
MAINTAINER="$(git config user.email)"
DOTNETVERS=8.0
PKGDIR=opt/microsoft/powershell/7

test -n "$MAINTAINER"

case "$RIDARCH" in
	amd64 )
		RIDARCH=x64
		;;
	aarch64 )
		RIDARCH=arm64
		;;
	* )
		;;
esac

RID="freebsd-$RIDARCH"

TARGZ=$(echo powershell-v7*-$RID.tar.gz)
LIBPSL="github-PowerShell-Native/src/powershell-unix/libpsl-native.so"

ls -ld "$TARGZ" "$LIBPSL"

cleanup()
{
	if test -d powershell
	then
		chmod -R +w powershell

		rm -rf powershell
	fi

	rm -f *.manifest *.plist *.pkg
}

cleanup

trap cleanup 0

mkdir -p "powershell/$PKGDIR" "powershell/usr/bin"

(
	set -e
	cd "powershell/$PKGDIR"
	tar xfz -
) < "$TARGZ"

cp "$LIBPSL" "powershell/$PKGDIR"
chmod -w "powershell/$PKGDIR/"lib*.so
ln -s "/$PKGDIR/pwsh" "powershell/usr/bin/"

VERSION=$("powershell/$PKGDIR/pwsh" -Version | while read A B; do echo $B; done)

(
	cat << EOF
name powershell
version $VERSION
comment PowerShell is an automation and configuration management platform.
www https://microsoft.com/powershell
origin shells/powershell
desc: <<EOD
It consists of a cross-platform command-line shell and associated scripting language.
EOD
maintainer $MAINTAINER
prefix /
licenses: [
    "MIT"
]
categories: [
    "shells"
]
EOF
	echo "deps: {"
	RUNTIME="dotnet-runtime-$DOTNETVERS"
	for d in "$RUNTIME"
	do
		ORIGIN=$(pkg info -q --origin $d)
		VERS=$(pkg info $d | grep Version | while read A B C D; do echo $C; break; done | sed "y/,/ /" | while read E F; do echo $E; done)
		if test "$d" = "$RUNTIME"
		then
			echo "   $d: {origin: $ORIGIN, version: $VERS}"
		else
			echo "   $d: {origin: $ORIGIN, version: $VERS},"
		fi
	done
	echo "}"
) > powershell.manifest

for d in powershell
do
(
	cd $d
	find "$PKGDIR" -type f | xargs chmod -w
	find * -type d | while read N
	do
		echo @dir $N
	done
	find "$PKGDIR" -type f | (
		while read N
		do
			echo "$N"
		done
	)
	find usr -type l
) > $d.plist
done

for d in *.manifest
do
	BASE=$(echo "$d" | sed "s/\.manifest//" | while read A B; do echo $A; done)
	pkg create -M "$d" -o . -r "$BASE" -v -p "$BASE.plist"
done

tar --create --verbose --gzip --gid 0 --uid 0 --file "powershell-$VERSION-$RID.tar.gz" "powershell-$VERSION.pkg"
