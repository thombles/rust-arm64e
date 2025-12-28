# Rust toolchain with arm64e support

This is a fork of [getditto/rust-bitcode](https://github.com/getditto/rust-bitcode), a collection of scripts to aid in building custom Rust toolchains for Apple platforms. The original project built toolchains with Xcode-compatible bitcode; this fork builds toolchains with `arm64e-apple-ios` target support for experimenting with Pointer Authentication Code (PAC) and Memory Integrity Enforcement (MIE).

**This is for testing purposes only.**

## How it works

The scripts build a custom Rust toolchain using Apple's Swift LLVM fork, which includes arm64e support that hasn't been upstreamed to LLVM yet. This allows Rust to target `arm64e-apple-ios` with full std library support.

## Build from source

1. Ensure required build tools are installed:
   ```bash
   brew install ninja cmake openssl
   ```

2. Clone this repository.

3. Review `config.sh` to check the Rust and LLVM versions.

4. Run the build:
   ```bash
   ./build.sh
   ```
   This will clone Rust and Apple's Swift LLVM under `build/` and compile them. The build takes approximately 30-60 minutes.

5. Install the toolchain:
   ```bash
   ./install.sh
   ```
   This installs to `~/.rustup/toolchains/arm64e-<version>`.

## Using the toolchain

Build your library targeting arm64e iOS:

```bash
cargo +arm64e-1.92.0 build --target arm64e-apple-ios --release
```

Or use rustc directly:

```bash
rustup run arm64e-1.92.0 rustc --target arm64e-apple-ios ...
```

## Available targets

The toolchain includes pre-built std for:
- `aarch64-apple-darwin` (host)
- `aarch64-apple-ios`
- `arm64e-apple-ios`

## License

The shell scripts in this repository are made available under the Apache 2.0 licence. See [LICENSE](LICENSE).

Binary releases contain LLVM and Rust. See [LICENSE-LLVM](LICENSE-LLVM) and [LICENSE-RUST](LICENSE-RUST) for their respective licenses.
