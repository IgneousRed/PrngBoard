# Dependency provenance and compatibility

Nix and the checked-in lock are the setup contract. The native recipes under
[`nix/llvm23/`](../nix/llvm23/README.md) are copied as an exact portable unit from
the public owner revision
[`6cca8868fa34b8ddd291e358ae640571a60c80e4`](https://github.com/IgneousRed/odin-lint/commit/6cca8868fa34b8ddd291e358ae640571a60c80e4).
This is recipe provenance, not a linter dependency. No sibling checkout or private
file participates in evaluation or setup.

1. Public owner source NAR: `sha256-dkWpSLZFDXKOEcpzyBLoM8RLJNNkzILF0tPwJRvVzEA=`.
2. The 26-file unit has 25 checksum rows; its `SHA256SUMS` file has SHA-256
   `7260a96cca3c441caeb4e2777115f89c75079140931db51ba5d7c41abc8878cb`.
3. The existing nixpkgs revision remains
   `619c39f6eac5d1ed6b8f073a9414baf7034b2356`, with the unchanged checked-in lock.
   Source URLs, exact releases, hashes, compatibility patches and upstream licence
   notices are retained in the unit. Fetched source/store paths remain Nix-owned;
   this project needs no persistent source view.

## Selected roles

| Role | Selection and compatibility |
| --- | --- |
| Odin | Published monthly release `dev-2026-11a`, exact source `9a6991685ddf663956d9836602eb421e141fc443`; not an unpinned development branch. |
| Darwin native compiler/linker | LLVM/Clang/LLD 23.1.6 through the existing verified macOS bottle provider. |
| Darwin SDK | SDK 14.4 headers/frameworks and SDK 27.0 C++ text stubs; **not** a full SDK 27 migration. |
| Python | 3.15.2, rebuilt with the same native toolchain and full LTO; public catalog Python remains the separate checker/bootstrap role. |
| Compiler vendor bindings | Raylib 6.2 retains static/dynamic outputs and platform bindings; GLFW is 3.5.1. |
| Statistical setup tool | PractRand 0.96, RNG_test only, retaining the ARM chrono/x86-intrinsic compatibility patch. Historical comparison results remain historical. |
| Updated selected libraries | Zstd 1.6.0, Zlib 1.4, Expat 2.11.0, SQLite 3.54.1 and Readline 8.3p6, using the common recipes rather than project-specific overrides. |
| Preserved provider exceptions | OpenSSL 3.5.9 LTS, full-feature Cctools 1010.6 command contract and independent build/bootstrap compiler roles. Features/references are not stripped to force version convergence. |
| Linux | Existing Odin-compatible LLVM 22.1.8 role on aarch64/x86_64. Python libraries and Raylib's GLFW/CMake inputs use the same common released-source scope without replacing the Linux compiler/provider. Native Linux execution remains TODO, not certified by Darwin tests. |

The unit also exposes optional Git/Perl, Rust/Cargo and Node recipes. They stay
lazy and are not added to this project's runtime environment. No linter, fuzzer,
direct-tools or UI/web dependency is introduced. Build-time tools and libraries
are distinct from runtime selections; the three-entry read-only checker reports
its declared core sources, not a claim that every transitive provider is newest.

Exact derivation/output and recursive closure identities were compared before
realization. The common Odin, native LLVM, Clang/LLD and Python outputs were reused;
only PractRand and small environment/metadata views needed local builds. Existing
roots and recovery data were preserved. This describes the selected project
environment, not cleanup or replacement of installed machine tools.

## Source compatibility

Three deprecated `core:intrinsics` imports were changed to `base:intrinsics`;
their helper procedure bodies and all generator implementations/constants remain
unchanged. The inactive public selector now uses compile-time procedure-signature
assertions, keeping every selector available without a default campaign or a
compiler-flag exception. Historical measurement tables and private experiment
records are not rewritten as fresh validation.
