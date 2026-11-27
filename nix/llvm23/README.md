# LLVM 23 native toolchain

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
5. `git`: Git 2.56.1 using the selected Python and Perl 5.44.0 module scope. It preserves the catalog feature flags, output set, build environment and check policy.
6. `nodejs`: optional Node 26.13.1 with the common updated native libraries. This is an explicit binding; importing the unit does not change a consumer’s outer `pkgs.nodejs_26`.
7. `dependencies`: the common library/source scope, including the selected Perl package set.
8. `sdk`, `native`, `rawBintools`: explicit lower-level components for consumers that need them.

For a merged environment, select `odin`, `llvmPackages.clang`, `llvmPackages.llvm` and `python`. Omit redundant `bintools` from `buildEnv.paths`; use it on a tool wrapper's PATH when needed. LLVM's tool view excludes raw Clang driver aliases so the wrapped compiler wins. Shared file normalization makes identical consumer copies use identical derivations.

Select `git` rather than the catalog's `pkgs.git` when the environment needs Git.
The catalog Git package retains its original Python/compiler closure. The
standalone `git-package.nix` interface accepts `{ pkgs, python }`, so a
consumer can use the same package without changing its existing source pins.
It uses the upstream interpreter override and retains the catalog's build-time
compiler. The resulting runtime closure shares the rebuilt Python/compiler
outputs. Check the actual recursive closure before claiming removal of older
Python or LLVM backends; preserve the Perl support-file exception documented
below. Identical consumers reuse the same
immutable Git output; rebuilding solely to change its build-time compiler does
not remove that independent Perl exception.

`python3 -I nix/llvm23/verify-git.py --git OUTPUT --reference CATALOG_OUTPUT --python PYTHON_OUTPUT
--version 2.56.1 --perl-version 5.44.0 --https` checks native version/features, installed command/file parity, local
repositories and archives, shallow-fetch bootstrap, worktrees, SHA256 objects, HTTP/HTTPS transport and
Python/Perl/keychain-helper startup and a real Gitweb CGI project listing. It uses isolated temporary repositories and
configuration; it does not exercise a Perforce server, send mail or read/write
keychain credentials. Across an explicit Perl upgrade, only the validated
`site_perl` ABI directory component is normalized for file-set comparison;
every installed filename is still checked. The selected email helper's exact
Perl/module paths also load Git, IO::Socket::SSL and Net::SSLeay together.

### Shared dependency selection

`native-sources.nix` records the fixed releases missing from the common lock;
`perl-sources.nix` records the updated CPAN runtime/build/test releases. Their
hashes are public source definitions, not a second resolver. Recipes retain
catalog build features, outputs and check policies, with only the compatibility
adaptations needed by the selected releases. Copy the whole unit, including
these files, compatibility patches and `upstream/` manifest;
`git-package.nix` imports that scope.

The common selection updates Zstd, Zlib, SQLite, Expat, Readline, Git, Perl and
its modules, sigtool, Libplist, Libedit, GLFW, Kerberos, the Unicode/HTTP libraries,
Libarchive, CMake, Tcl 8.6 and the public suffix database. ICU 79.1 uses the
existing catalog recipe rather than a new provider. Node stays lazy. The Node configure interpreter is the catalog's
`pythonOnBuildForHost`, distinct from the rebuilt runtime `python` selected by
SDK wrappers. Compare both actual store identities when sharing builds.

CMake 4.5.1 retains the provider's separate full and minimal variants, including
the full variant's TLS/system-library features and every unrelated patch. Its
build compiler remains the independent catalog compiler: it cannot depend on
the native LLVM view it helps package. LLVM packaging uses the independent
public Python 3.15 interpreter, not the custom interpreter built by that LLVM.
GTK-Doc likewise uses the public build interpreter. Tcl stays in the 8.6 ABI
family for SQLite and the existing Expect 5/DejaGNU test harness.

Rust 1.100 uses the upstream Nixpkgs family recipe recorded unchanged under
`upstream/`, with the locked provider's matching bootstrap/cargo/platform APIs.
The upstream recipe and its MIT notice are retained byte-for-byte under
`upstream/`, with official source URLs and hashes in its manifest. Provider-derived
compatibility patches retain their original scope; `upstream/COPYING` also
supplies the Nixpkgs license notice for those adaptations.
The small owned adapter applies the upstream builder stack correction while
preserving fatal warnings, both upstream compatibility patches, native and Wasm
standard libraries, rustc development support and Cargo auditing. Its catalog
LLVM provider is distinct from the immutable native Odin/fuzzer compiler view;
neither a global rustup change nor a substitute binary provider is required.
That shared provider selects LLVM and TableGen 23.1.6, public Python 3.15 for
both packaging and lit's psutil environment, and the common CMake/library scope.
The existing independent catalog compiler still bootstraps those source builds.
Reuse matching realized outputs or trusted substitutes before building. This
source provider is a transitive Git build input, not an Odin runtime compiler.
An official prebuilt Rust toolchain has a different component/target contract;
changing to it requires compatibility assessment, not an automatic provider
swap. Internal backend patch metadata alone does not justify another compiler
build or an Odin toolchain change.

Perl's extension configuration retains its compiler support headers/libraries
and SDK C++ stubs. These are not an older LLVM backend. Do not strip their
references or delete working roots to claim a smaller runtime. Output sizes and
recursive references must be measured for each finalized selection; old
interpreter/module proofs do not establish a new Perl ABI.

The Perl core suite stays enabled. Its Darwin file-discovery test searches the
real shared libperl built by the test tree rather than a nonexistent on-disk
libc (modern macOS supplies libc through the dyld cache). The result-count
assertion and all existing XS load/unload checks are retained.

CGI 5's new runtime prerequisite, URI, is propagated through the common Perl
scope so Gitweb retains a complete module path rather than relying on a user's
Perl environment.

Libgit2 1.9.7's Darwin empty-parent cleanup normalizes the trailing separator
supplied by its path walker before calling `rmdir`. Otherwise a case-insensitive
directory alias to its parent returns `EINVAL` instead of the already-handled
`ENOTDIR`, failing the existing forced-checkout test. The correction retains the
provider's checkout suite and adds its utility suite with a regression proving
that parent cleanup preserves both the symlink and its target. This is a local
compatibility patch, not a newer upstream release. It follows libgit2's
[GPLv2 with linking exception](https://github.com/libgit2/libgit2/blob/v1.9.7/COPYING),
not the Nixpkgs MIT notice.

The native package exposes interpreter-based LLVM helper commands through
`native.auxiliary` on explicit demand, using the same selected Python and Perl.
`set-xcode-analyzer` is not exposed: it requires Xcode/PyObjC integration. The
original upstream script is retained as non-executable data.

### Compatibility holds

1. Cctools remains 1010.6. The 1035.1.102 source removes assembler, prebinding
   and legacy-support source targets installed by the current recipe. Dropping
   those commands or merging a second legacy source is not this upgrade.
2. OpenSSL remains the current supported 3.5.9 LTS shared ABI, not merely the
   catalog default. Python 3.15.2's OpenSSL 4 branch incorrectly marks TLS
   1.0–1.2 unavailable; the [upstream fix](https://github.com/python/cpython/commit/3e87c6315efb7593f97fc36a0fdf7a87e60ed90b)
   is newer than that release. Stable Net::SSLeay 1.96 lacks the OpenSSL 4
   compatibility introduced in the [development 1.97_01 release](https://metacpan.org/release/CHRISN/Net-SSLeay-1.97_01).
   Node 26 also retains the deprecated engine API; OpenSSL 4 removes that
   functionality. Retiring those features or adopting development providers is
   not implied by selecting the newest compatible shared libraries.
3. Preserve the SDK 14.4 header/framework cohort, including its CUPS headers
   and Apple-specific library interfaces, plus the SDK 27 C++ link stubs.
   Newer independent upstream library versions are not interchangeable with
   this platform API. The host macOS supplies their runtime implementation.
4. Linux retains its separate LLVM 22 toolchain. This Apple Silicon unit does
   not certify Linux, Intel macOS or the Emscripten LLVM 24 toolchain.

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

## Verification scope

The Apple Silicon selection has compiler/debug and C++/Objective-C execution,
static/dynamic Raylib non-window execution, Wasm object generation, SDK tool
aliases, Python TLS/native-extension and Perl/module checks. These are not
interactive graphics/audio tests or certification of other platforms. The
shared source-built LLVM ran its complete enabled test suite; Rust retains the
provider's original disabled full-suite policy rather than claiming that suite
ran. Git's separate feature check covers the packaged helpers and transport
boundaries described above. Optional Node is declared but has not been realized
or verified by this native consumer.

Do not treat a different bundle's build or interpreter/module proofs as evidence
for this selection: compare exact derivations and recursive references. The
affected consumer's own compiler, lint, test, distribution and fuzz gates remain
separate obligations.
