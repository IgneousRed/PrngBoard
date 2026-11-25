# LLVM 23 toolchain candidate

This bundle packages the fixed LLVM/Clang/LLD 23.1.6 Apple Silicon macOS bottles in Nix, builds Odin at `9a6991685ddf663956d9836602eb421e141fc443`, and supplies Raylib 6.2 and Python 3.15.2 from the shared locked nixpkgs catalog. The native bottles require macOS 26 or later. Linux and Intel macOS have not been verified by this candidate.

Use nixpkgs revision `619c39f6eac5d1ed6b8f073a9414baf7034b2356` with NAR hash `sha256-oa2P5WZer1A4wuhatl92JyHHEjrrOdIyuvTuI5LUi9Q=`. Copy this directory as a unit; its imports are relative and require no sibling checkout or local artifact paths.

```nix
toolchain = import ./nix/llvm23/llvm23-toolchain.nix { inherit pkgs; };
```

The result exports:

1. `odin`: exact source/stamp, immutable libraries, matching Clang/LLD, and pinned SDK context. It can run outside the source checkout or development shell. Existing compiler/vet/style flags and explicit Odin linker choices remain authoritative.
2. `llvmPackages.{clang,llvm,bintools,lld,stdenv}`: wrapped Clang, LLVM tools, Darwin binutils aliases, LLD and the compiler environment. `llvm.dev` supplies `llvm-config` and headers; `llvm.lib` supplies the LLVM shared library.
3. `raylib`, `raylibStatic`: unchanged 6.2 ABI/configurations, rebuilt using the selected compiler and SDK. Native Odin binding slots use these outputs; the existing source binding branches remain intact.
4. `python`: Python 3.15.2 rebuilt with this compiler environment using full LTO, retaining native extension build support.
5. `git`: Git 2.56.0 using the selected Python. It preserves the catalog source, feature flags, output set, build environment and check policy.
6. `sdk`, `native`, `rawBintools`: explicit lower-level components for consumers that need them.

For a merged environment, select `odin`, `llvmPackages.clang`, `llvmPackages.llvm` and `python`. Omit redundant `bintools` from `buildEnv.paths`; use it on a tool wrapper's PATH when needed. LLVM's tool view excludes raw Clang driver aliases so the wrapped compiler wins. Shared file normalization makes identical consumer copies use identical derivations.

Select `git` rather than the catalog's `pkgs.git` when the environment needs Git.
The catalog Git package retains its original Python/compiler closure. The
standalone `git-package.nix` interface accepts `{ pkgs, python }`, so a
consumer can use the same package without changing its existing source pins.
It uses the upstream interpreter override and retains the catalog's build-time
compiler. The resulting runtime closure shares the rebuilt Python/compiler
outputs. It removes the older Python and LLVM backends while retaining the
Perl support-file exception documented below. Identical consumers reuse the same
immutable Git output; rebuilding solely to change its build-time compiler does
not remove that independent Perl exception.

`python3 -I nix/llvm23/verify-git.py --git OUTPUT --reference CATALOG_OUTPUT --python PYTHON_OUTPUT
--https` checks native version/features, installed command/file parity, local
repositories and archives, shallow-fetch bootstrap, worktrees, SHA256 objects, HTTP/HTTPS transport and
Python/Perl/keychain-helper startup. It uses isolated temporary repositories and
configuration; it does not exercise a Perforce server, send mail or read/write
keychain credentials.

### Perl support-file exception

Git's pinned Perl 5.42.3 package retains three older support outputs through the
include/library search paths in `Config_heavy.pl`:

| Output | NAR bytes |
| --- | ---: |
| `compiler-rt-libc-21.1.8` | 6,236,224 |
| `compiler-rt-libc-21.1.8-dev` | 774,208 |
| `libcxx-22.1.6+apple-sdk-27.0` | 13,034,520 |
| Total | 20,044,952 |

These are compiler support libraries/headers and SDK C++ stubs, not an older
LLVM backend or Python interpreter. Preserve their configuration references;
stripping them would hide Perl extension-build requirements. A different Git
build environment leaves these separate Perl references intact.

A source-only assessment found that a Perl migration would have to replace the
current 52,214,008-byte interpreter output and migrate 36 module outputs totalling
5,518,424 bytes, including native extensions, before relinking Git's helper
dependencies. New output sizes and build cost have not been measured. Working
packages must remain during that migration, and old roots may still retain the
support files. No measured net space benefit justifies a new Perl build or
download for the current task.

The native package exposes interpreter-based LLVM helper commands through `native.auxiliary` on explicit demand. Its Python is the same rebuilt `python`, and its Perl is the pinned catalog package. `set-xcode-analyzer` is not exposed: it requires Xcode/PyObjC integration. The original upstream script is retained as non-executable data.

## Compatibility choices

1. Verified bottle hashes are fixed in `llvm23-package.nix`; acquisition uses anonymous public GHCR access. No installed Homebrew package or runtime Homebrew path is used. Archive paths/types and link targets are checked before extraction; the external Homebrew `etc/clang` configuration link is omitted. Mach-O dependencies/IDs are relocated and changed files signed.
2. The SDK preserves every header/framework file. Its six Xcode tool aliases use LLVM 23 rather than retaining cctools/LLVM 21. The SDK setup hook points to the new immutable output.
3. Clang uses LLVM 23 C++ headers with Apple system C++ link stubs. The stubs come from the locked catalog's SDK 27 package; they are text link descriptions, with runtime symbols supplied by macOS.
4. The Darwin linker dispatches to `ld64.lld`. The pinned Nix wrapper's hardening capability probe recognizes LLD's `unknown argument` wording as well as `unknown option`; supported checks remain enabled.
5. Clang uses Apple linker compatibility profile `957.1`, because the bottle's newer Apple linker assumption enables Objective-C class-selector stubs that LLD 23 does not implement. This is a capability profile, not an older installed linker. Regular selector stubs and modern platform-version linking remain enabled. See the [pinned Clang driver](https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-23.1.6/clang/lib/Driver/ToolChains/Darwin.cpp).
6. Python uses its supported `--with-lto=full` mode. The default ThinLTO build failed when linking its bootstrap executable; full LTO built successfully and passed standard-library and native extension checks. The exact ThinLTO failure cause remains unconfirmed. LTO and validation checks remain enabled. See [CPython's LTO options](https://docs.python.org/3.15/using/configure.html#cmdoption-with-lto).
7. Nix's original catalog compiler/tools may still be needed as build-time bootstrap inputs. Runtime closure evidence must be checked for the selected consumer outputs. Existing installed packages and old roots must remain until consumer verification succeeds.

Emscripten 7.0.0's coupled LLVM 24 bundle is outside this replacement. Its unique native LLVM payload measured 474,503,232 bytes (about 452.5 MiB), plus Clang resources. Do not replace it with LLVM 23 without web-toolchain compatibility verification. Other upstream embedded toolchains require their owners' checks as well.

## Lean dependency checker

Keep the public binary-substitutable Python as the bootstrap API, and declare the preferred rebuilt interpreter separately:

```nix
lib.dependencyCheck.${system} =
  let interpreter = pkgs.python315;
  in {
    inherit interpreter;
    python = "${interpreter}/bin/python3";
    preferredPython = "${toolchain.python}/bin/python3";
    metadata = updates;
  };
```

The approved checker uses a preferred interpreter only when it is already executable and registered in Nix. Otherwise, it downloads only the public bootstrap closure with local/remote builds disabled. Each invocation retains its interpreter until exit. A completed report atomically retargets the project's checker cache root; failures preserve the existing cache. Keep bootstrap derivations out of the main runtime manifest, and migrate old checker roots before claiming their compiler references are removed.

Do not alter consumer source pins just to adopt this toolchain. Supply the exact existing linter source/revision to its canonical recipe and retain the consumer's real compiler gates before invoking the packaged CLI. Runtime evidence for this candidate is recorded separately; adding the bundle alone does not certify every application's targets or justify deleting old dependencies.

## Verified scope

The candidate was checked on Apple Silicon macOS 26 with odin-lint 0.7.6 source revision `d20eac1dbe6b5b6dd7cc87b1e3c30d5f6cc1e0de`. Verification covered maximal compatible compiler checks, native debug execution, static/dynamic Raylib linkage, a debug `js_wasm32` object, C++ and Objective-C execution, debug-map verification and the six SDK tool aliases. SDK headers and frameworks matched the pinned original. The current implementation passed self-lint, all 16 Odin tests and 43 normal CLI tests. Python passed compression/database/TLS/decimal/ctypes checks and built/imported a native extension using its actual compiler configuration.

A source archive without Git metadata evaluated and built the same core package outputs, ran through the canonical launcher, and switched its checker cache from the public bootstrap to the rebuilt Python after a successful read-only report. The checker passed 14 protocol/selection/root-lifetime fixtures, and the launcher passed 16 fixtures. Optional LLVM helpers were checked separately; `scan-view` was checked for command-line startup only.

The Git interpreter override passed 30 focused checks against the original
catalog package, including inventory parity for 149 built-in commands and
installed files, local clone/commit/archive, shallow-fetch bootstrap, worktrees, SHA1/SHA256
object interoperability, smart HTTP, public HTTPS and helper startup. A Git-free
archive selected the same environment and ran the packaged Git. The complete
selected environment retains only the three older support outputs documented
above; Git and Perl features remain enabled. No additional Git/Perl compilation
or download was required for this consolidation.

The selected Odin and rebuilt-Python recursive runtime closures contain no LLVM/Clang 21 or 22, cctools or ld64 package. This describes those outputs, not the whole machine: production environments, public bootstrap roots and build-time dependencies can still retain older packages. Full application suites, distribution gates and fuzz-tool adoption are separate consumer responsibilities before promotion.
