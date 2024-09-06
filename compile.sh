#!/bin/sh -ex

WORKDIR=github-PowerShell-Native

rm -rf "$WORKDIR"

git clone https://github.com/PowerShell/PowerShell-Native.git "$WORKDIR"

cd "$WORKDIR"

git checkout 482c219b91dc81970a9c1050c880a874d403ddc6

git apply "../$WORKDIR.patch"

cd src/libpsl-native

cmake -DCMAKE_BUILD_TYPE=Release .

make
