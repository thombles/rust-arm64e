# Configuration for building Rust with Apple's Swift LLVM for arm64e support
#
# This builds a custom Rust toolchain with arm64e-apple-ios target support,
# using Apple's Swift LLVM which includes Pointer Authentication (PAC) and
# Memory Integrity Enforcement (MIE) support.
#
# To check your local Swift/LLVM version: xcrun -sdk iphoneos swiftc --version

set -euxo pipefail

# 1. Select the Rust version
# Use a stable release like "1.92.0" or nightly like "nightly-2025-12-20"
RUST_VERSION="1.92.0"

# 2. Select the Swift LLVM tag from https://github.com/swiftlang/llvm-project
# Use a development snapshot that matches your Xcode/Swift version.
# Recent snapshots are based on LLVM 21.1.x which is compatible with Rust 1.92+
# Check available tags: https://github.com/swiftlang/llvm-project/tags
LLVM_TAG="swift-DEVELOPMENT-SNAPSHOT-2025-12-19-a"

# LLVM repository URL (swiftlang has arm64e/PAC support)
LLVM_REPO="https://github.com/swiftlang/llvm-project.git"

get_rust_commit_for_toolchain() (
    # Yields "" for a toolchain like `x.y.z`, and `mm-dd-yy` for `nightly-mm-dd-yy`
    IF_NIGHTLY_DATE_STRIPPED=$(echo "${RUST_VERSION}" | sed -n 's/^nightly-//p')
    if [ -n "${IF_NIGHTLY_DATE_STRIPPED}" ]; then # `if let Some(nightly_date)`
        curl -s "https://static.rust-lang.org/dist/${IF_NIGHTLY_DATE_STRIPPED}/channel-rust-nightly-git-commit-hash.txt"
    else
        echo "refs/tags/${RUST_VERSION}"
    fi
)

# 3. Derived configuration
RUST_BRANCH="$(get_rust_commit_for_toolchain)"

# 4. Toolchain name for rustup installation
# Will be installed under $HOME/.rustup/toolchains/$RUST_TOOLCHAIN
RUST_TOOLCHAIN="arm64e-${RUST_VERSION}"
