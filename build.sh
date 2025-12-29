#!/bin/bash

# Build script for Rust with Apple's Swift LLVM for arm64e support
# This creates a custom toolchain with arm64e-apple-ios target enabled

set -euxo pipefail

# Calculate script directory before changing directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source config.sh

# verify build requirements are present

if ! command -v cmake &> /dev/null; then
    echo "cmake not found. Try: brew install cmake"
    exit 1
fi
if ! command -v ninja &> /dev/null; then
    echo "ninja not found. Try: brew install ninja"
    exit 1
fi
if ! command -v openssl &> /dev/null; then
    echo "openssl not found. Try: brew install openssl"
    exit 1
fi

# setup openssl environment

set +x

# default lookup directory prior to 2022.06
export OPENSSL_DIR='/usr/local/opt/openssl'
export OPENSSL_STATIC=1

if [ ! -d "$OPENSSL_DIR" ]; then
    printf "OpenSSL not found at expected location (%s). Trying another location...\n" "${OPENSSL_DIR}"

    # location where brew installs the latest openssl version (in 2022.06)
    export OPENSSL_DIR='/opt/homebrew/opt/openssl@3'
    if [ ! -d "$OPENSSL_DIR" ]; then
        printf "OpenSSL not found at expected location (%s). Trying another location...\n" "${OPENSSL_DIR}"

        # location where macports installs the latest openssl version (in 2022.06)
        export OPENSSL_DIR='/opt/local/libexec/openssl3'
        if [ ! -d "$OPENSSL_DIR" ]; then
            printf "OpenSSL not found at expected location (%s). Try: brew install openssl\n" "${OPENSSL_DIR}"
            exit 1
        fi
    fi
fi

echo "OPENSSL_DIR=${OPENSSL_DIR}"
echo "OPENSSL_STATIC=${OPENSSL_STATIC}"

# setup work directory

set -x

WORKING_DIR="$(pwd)/build"
mkdir -p "$WORKING_DIR"
cd "$WORKING_DIR"

# Clone Swift's LLVM (has arm64e/PAC support)
if [ ! -d "llvm-project" ]; then
    git clone \
        --depth 1 \
        --branch "$LLVM_TAG" \
        "$LLVM_REPO" \
    ;
fi
(cd "llvm-project"
    git reset --hard
    git clean -fd
    # Try to apply the system-libs patch if it applies cleanly
    # This may not be needed for newer LLVM versions
    if git apply --check ../../patches/llvm-system-libs.patch 2>/dev/null; then
        git apply ../../patches/llvm-system-libs.patch
        echo "Applied llvm-system-libs.patch"
    else
        echo "Skipping llvm-system-libs.patch (may not be needed for this LLVM version)"
    fi
)

# setup llvm build directory

mkdir -p llvm-build
(cd llvm-build
    cmake \
        "$WORKING_DIR/llvm-project/llvm" \
        -DCMAKE_INSTALL_PREFIX="$WORKING_DIR/llvm-root" \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_INSTALL_UTILS=ON \
        -DLLVM_TARGETS_TO_BUILD='X86;ARM;AArch64' \
        -DLLVM_ENABLE_PROJECTS='clang;lld' \
        -DLLVM_ENABLE_RUNTIMES='' \
        -DLLVM_ENABLE_ZSTD=OFF \
        -DLLVM_ENABLE_ZLIB=OFF \
        -G Ninja \
    ;
    ninja
    ninja install
)

# clone rust repo

if [ ! -d "rust" ]; then
    git clone https://github.com/rust-lang/rust.git
fi
(cd rust
    git reset --hard
    git clean -fd
    git fetch --tags
    git checkout "$RUST_BRANCH"
    # Clean the build directory to ensure patches take effect
    rm -rf build/
)

# Apply Rust patches for Swift LLVM compatibility and arm64e support
# Patches are stored in rust-patches/ directory
echo "Applying Rust patches..."
for patch in "$SCRIPT_DIR"/rust-patches/*.patch; do
    if [ -f "$patch" ]; then
        echo "Applying $(basename "$patch")..."
        git -C "$WORKING_DIR/rust" apply "$patch"
    fi
done
echo "Applied all Rust patches"

# Determine host triple
HOST_TRIPLE=$(rustc -vV | sed -n 's/^host: //p')

# Create bootstrap.toml for rust build configuration
cat > "$WORKING_DIR/rust/bootstrap.toml" << EOF
# Bootstrap configuration for arm64e-apple-ios custom toolchain

[build]
# Build for host and arm64e iOS target
host = ["$HOST_TRIPLE"]
target = ["$HOST_TRIPLE", "arm64e-apple-ios", "aarch64-apple-ios"]
extended = true
tools = ["cargo", "rustfmt", "clippy"]

[rust]
channel = "nightly"
# Enable debug assertions for better error messages during development
debug-assertions = false
# LLD is useful but not strictly required
lld = false

[llvm]
# Use our custom-built Swift LLVM
download-ci-llvm = false

[target.$HOST_TRIPLE]
llvm-config = "$WORKING_DIR/llvm-root/bin/llvm-config"

[target.arm64e-apple-ios]
llvm-config = "$WORKING_DIR/llvm-root/bin/llvm-config"

[target.aarch64-apple-ios]
llvm-config = "$WORKING_DIR/llvm-root/bin/llvm-config"
EOF

echo "Created bootstrap.toml with arm64e-apple-ios target"

# Build rust
(cd rust
    python3 x.py build --stage 2
)
