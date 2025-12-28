#!/bin/bash

# Build script for Rust with Apple's Swift LLVM for arm64e support
# This creates a custom toolchain with arm64e-apple-ios target enabled

set -euxo pipefail

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
)

# Apply patches for Swift LLVM compatibility
# Swift LLVM 21.x has a mix of API versions:
# - PGOOptions: Has LLVM 22 API (no FileSystem parameter)
# - getSummaryList: Has LLVM 20 API (.SummaryList member, not method)
# - LintPass, getGUID, cfiFunctions: Has LLVM 21 API
PASS_WRAPPER="$WORKING_DIR/rust/compiler/rustc_llvm/llvm-wrapper/PassWrapper.cpp"
if [ -f "$PASS_WRAPPER" ]; then
    echo "Patching PassWrapper.cpp for Swift LLVM 21.x API compatibility..."

    # PGOOptions: Change version checks from 22 to 21 (Swift LLVM 21 has LLVM 22 PGOOptions API)
    sed -i '' 's/LLVM_VERSION_GE(22, 0)/LLVM_VERSION_GE(21, 0)/g' "$PASS_WRAPPER"
    sed -i '' 's/LLVM_VERSION_LT(22, 0)/LLVM_VERSION_LT(21, 0)/g' "$PASS_WRAPPER"

    # getSummaryList: Only these specific lines need to use old API (.SummaryList)
    # Swift LLVM 21 doesn't have .getSummaryList() on GlobalValueSummaryInfo
    # We target the specific pattern that accesses I.second.getSummaryList() or List.second.getSummaryList()
    sed -i '' 's/I\.second\.getSummaryList()/I.second.SummaryList/g' "$PASS_WRAPPER"
    sed -i '' 's/List\.second\.getSummaryList()/List.second.SummaryList/g' "$PASS_WRAPPER"

    echo "Patched PassWrapper.cpp"
fi

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
