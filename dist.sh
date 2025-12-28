#!/bin/bash
set -euxo pipefail
source config.sh

HOST_ARCH="$(rustc -vV | sed -n 's/^host: //p')"

# The built toolchain that we are going to package
WORKING_DIR="${PWD}/build"
BUILT_TOOLCHAIN_DIR="${WORKING_DIR}/rust/build/${HOST_ARCH}"

# The directory which will be added to the final zip file
DEST="${PWD}/dist/rust-${RUST_TOOLCHAIN}"

# The actual toolchain inside that, which will be installed to ~/.rustup/...
TOOLCHAIN_DEST="${DEST}/${RUST_TOOLCHAIN}"

rm -rf "$DEST"
mkdir -p "$TOOLCHAIN_DEST"

# Remove unneeded files from output (src and rustc-src contain symlink cycles)
rm -rf "${BUILT_TOOLCHAIN_DIR}/stage2/lib/rustlib/src"
rm -rf "${BUILT_TOOLCHAIN_DIR}/stage2/lib/rustlib/rustc-src"

# Copy in toolchain artifacts
cp -r \
    "${BUILT_TOOLCHAIN_DIR}/stage2"/* \
    "$TOOLCHAIN_DEST" \
;
cp -r \
    "${BUILT_TOOLCHAIN_DIR}/stage2-tools-bin"/* \
    "$TOOLCHAIN_DEST/bin" \
;

# Copy in static files that need to be included in the distribution
cp LICENSE* README.md "$DEST" 2>/dev/null || true

sed 's/^    //' >"$DEST/install.sh"<<EOF
    #!/bin/bash
    set -euxo pipefail

    DEST_TOOLCHAIN="\$HOME/.rustup/toolchains/${RUST_TOOLCHAIN}"
    rm -rf "\$DEST_TOOLCHAIN"
    mkdir -p "\$DEST_TOOLCHAIN"
    cp -r "${RUST_TOOLCHAIN}"/* "\$DEST_TOOLCHAIN"

    echo ""
    echo "Installed arm64e Rust toolchain: ${RUST_TOOLCHAIN}"
    echo "Use with: cargo +${RUST_TOOLCHAIN} build --target arm64e-apple-ios"
    echo ""
EOF
chmod +x "${DEST}/install.sh"

(cd dist
    rm -f "rust-${RUST_TOOLCHAIN}.zip"
    zip -r "rust-${RUST_TOOLCHAIN}.zip" "rust-${RUST_TOOLCHAIN}"
)
