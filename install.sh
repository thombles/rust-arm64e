#!/bin/bash

set -euxo pipefail

source config.sh

WORKING_DIR="$(pwd)/build"
HOST_ARCH="$(rustc -vV | sed -n 's/^host: //p')"

STAGE_DIR="${WORKING_DIR}/rust/build/${HOST_ARCH}/stage2"

# remove unnecessary files from output (src and rustc-src contain symlink cycles)

rm -rf "${STAGE_DIR}/lib/rustlib/src"
rm -rf "${STAGE_DIR}/lib/rustlib/rustc-src"

# setup toolchain directory

DEST_TOOLCHAIN="${HOME}/.rustup/toolchains/${RUST_TOOLCHAIN}"

rm -rf "${DEST_TOOLCHAIN}"
mkdir -p "${DEST_TOOLCHAIN}"

# install artifacts

cp -r "${STAGE_DIR}"/* "${DEST_TOOLCHAIN}"
cp -r "${STAGE_DIR}-tools-bin"/* "${DEST_TOOLCHAIN}/bin"

echo ""
echo "=============================================="
echo "Installed arm64e Rust toolchain: ${RUST_TOOLCHAIN}"
echo "=============================================="
echo ""
echo "Use with: rustup run ${RUST_TOOLCHAIN} rustc ..."
echo "Or:       cargo +${RUST_TOOLCHAIN} build ..."
echo ""
echo "Available targets:"
"${DEST_TOOLCHAIN}/bin/rustc" --print target-list | grep -E "arm64e|aarch64-apple"
echo ""
