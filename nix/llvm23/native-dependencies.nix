{ pkgs }:
let
  inherit (pkgs) lib;
  sources = import ./native-sources.nix;
  release = name: package:
    if lib.versionAtLeast package.version sources.${name}.version then package else
    package.overrideAttrs (_: {
      inherit (sources.${name}) version;
      src = if sources.${name} ? tag then pkgs.fetchFromGitHub {
        inherit (sources.${name}) owner repo tag hash;
      } else pkgs.fetchurl { inherit (sources.${name}) url hash; };
    });
  # Retain the provider's full/minimal split and independent catalog compiler.
  # Neither CMake variant is built by the LLVM view it helps construct.
  cmakeRelease = package: (release "cmake" package).overrideAttrs (old:
    let
      original = builtins.readFile (lib.last old.patches);
      before = [
        "-  find_program(CMAKE_UNAME NAMES uname PATHS /bin /usr/bin /usr/local/bin)"
        "+  find_program(CMAKE_UNAME NAMES uname)"
      ];
      after = [
        "-  find_program(CMAKE_UNAME NAMES uname PATHS /bin /usr/bin /usr/local/bin NO_CMAKE_FIND_ROOT_PATH)"
        "+  find_program(CMAKE_UNAME NAMES uname NO_CMAKE_FIND_ROOT_PATH)"
      ];
      # Keep every impurity removal while retaining 4.5's host-tool root policy.
      impurePatch = assert lib.assertMsg
        (builtins.all (anchor: builtins.length (lib.splitString anchor original) == 2) before)
        "Review CMake's host uname lookup before refreshing the impurity patch";
        builtins.toFile "remove-impure-search-paths.patch" (lib.replaceStrings before after original);
    in {
      patches = assert lib.assertMsg
        (builtins.baseNameOf (builtins.head old.patches) == "nixpkgs-cmake-prefix-path.patch"
          && builtins.baseNameOf (lib.last old.patches) == "remove-impure-search-paths.patch")
        "Review the provider's CMake patch ordering";
        [ (builtins.path { path = ./cmake-4.5-prefix-path.patch; name = "nixpkgs-cmake-prefix-path.patch"; }) ]
        ++ lib.init (builtins.tail old.patches) ++ [ impurePatch ];
    });
  cmakeMinimal = cmakeRelease pkgs.cmakeMinimal;
  cmake = (cmakeRelease pkgs.cmake).override {
    inherit zlib expat libarchive;
    curlMinimal = pkgs.curlMinimal.override {
      inherit zlib nghttp2 perl;
      libkrb5 = krb5;
    };
  };
  libarchive = ((release "libarchive" pkgs.libarchive).override { inherit zlib zstd; }).overrideAttrs (old: {
    # Both provider backports reverse-apply to the 3.8.11 release source.
    patches = assert lib.assertMsg (builtins.length old.patches == 2
      && lib.hasSuffix "archive-read-fix-large-child-environment-test.patch" (toString (builtins.head old.patches))
      && lib.hasSuffix "032c0ddead2f7acb5be56a0577159e03b3d4dc69.patch" (toString (builtins.elemAt old.patches 1)))
      "Review the provider's Libarchive patches before removing integrated changes";
      [ ];
  });
  zlib = (release "zlib" pkgs.zlib).overrideAttrs (old: {
    # 1.4 incorporates the export-variable change and the later backport.
    # Keep the independent MinGW compatibility patch and all build/test flags.
    patches = assert lib.assertMsg
      (map builtins.baseNameOf old.patches == [ "export-variable.patch" "mingw-shared.patch" "cve-2026-85091.patch" ])
      "Review the catalog Zlib patches before removing integrated changes";
      [ (builtins.elemAt old.patches 1) ];
  });
  expat = release "expat" pkgs.expat;
  tcl = (release "tcl" pkgs.tcl).overrideAttrs (old: {
    passthru = old.passthru // { version = sources.tcl.version; };
    patches = assert lib.assertMsg (builtins.length old.patches == 2
      && builtins.baseNameOf (lib.last old.patches) == "8.6-windows-disable-tzdata.patch")
      "Review Tcl's compatibility patch ordering";
      [ (builtins.head old.patches) ./tcl-8.6.18-windows-tzdata.patch ];
  });
  expect = pkgs.expect.override { inherit tcl; };
  dejagnu = pkgs.dejagnu.override { inherit expect; };
  libffiReal = (release "libffiReal" pkgs.libffiReal).override { inherit dejagnu; };
  gtk-doc = ((release "gtk-doc" pkgs.gtk-doc).override {
    python3 = pkgs.python315;
  }).overrideAttrs (final: old: {
    # Release archives do not have the GitLab fetcher's tag attribute.
    meta = old.meta // {
      changelog = "https://gitlab.gnome.org/GNOME/gtk-doc/-/blob/${final.version}/NEWS";
    };
  });
  libplist = release "libplist" pkgs.libplist;
  libedit = release "libedit" pkgs.libedit;
  libgit2 = (pkgs.libgit2.override {
    inherit cmake zlib llhttp;
    python3 = pkgs.python315;
  }).overrideAttrs (old: lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    patches = (old.patches or [ ]) ++ [ ./libgit2-rmdir-symlink.patch ];
    # Retain the complete provider checkout suite and exercise the added
    # utility regression alongside every existing utility test.
    # The provider's custom checkPhase does not call a postCheck hook.
    checkPhase = old.checkPhase + ''
      ./util_tests -v
    '';
  });
  # Rust's shared LLVM is a separate catalog provider, not the native bottle
  # boundary used by Odin and its fuzzer. Preserve the provider's targets/tests.
  rustLLVMBase = pkgs.llvmPackages_23.override {
    inherit (sources.rustLLVM) version;
    officialRelease.sha256 = sources.rustLLVM.hash;
    inherit cmake cmakeMinimal zlib zstd;
    python3 = pkgs.python315;
    python3Minimal = pkgs.python315;
  };
  rustLLVM = rustLLVMBase.overrideScope (_final: previous: {
    libllvm = (previous.libllvm.override {
      # The provider explicitly bypasses normal splicing for lit's psutil
      # interpreter and its TableGen tool. Select both build roles coherently.
      buildLlvmPackages = rustLLVM;
      pkgsBuildBuild = pkgs.pkgsBuildBuild // {
        targetPackages = pkgs.pkgsBuildBuild.targetPackages // { python3 = pkgs.python315; };
      };
      python3Packages = pkgs.python315.pkgs;
    }).overrideAttrs (old: {
      # Refresh install-directory context and lit insertion anchors for 23.1.6.
      # Preserve every loader adaptation, assertion and unrelated provider patch.
      patches = assert lib.assertMsg
        (builtins.length old.patches == 5
          && lib.hasSuffix "gnu-install-dirs.patch" (toString (builtins.head old.patches))
          && lib.hasSuffix "llvm-lit-cfg-add-libs-to-dylib-path.patch"
            (toString (builtins.elemAt old.patches 1)))
        "Review LLVM's install-directory/loader patch ordering";
        [
          (builtins.path { path = ./llvm23-install-dirs.patch; name = "gnu-install-dirs.patch"; })
          (builtins.path { path = ./llvm23-lit-loader.patch; name = "llvm-lit-cfg-add-libs-to-dylib-path.patch"; })
        ] ++ lib.drop 2 old.patches;
    });
  });
  rust = import ./rust-1.100.nix {
    inherit pkgs cmake zlib sqlite libgit2;
    inherit (nativeDependencies) curl;
    llvmPackages = rustLLVM;
  };
  readline = if lib.versionAtLeast pkgs.readline.version sources.readline.version then pkgs.readline else
    pkgs.readline.overrideAttrs (old: {
      upstreamPatches = assert lib.assertMsg (builtins.length old.upstreamPatches == 3)
        "Review the existing Readline upstream patch set";
        old.upstreamPatches ++ map pkgs.fetchurl sources.readline.patches;
    });
  icu = pkgs.icu79;
  ada = (release "ada" pkgs.ada).override { inherit cmake simdutf simdjson gtest gbenchmark; };
  simdjson = (release "simdjson" pkgs.simdjson).override { inherit cmake; };
  simdutf = (release "simdutf" pkgs.simdutf).override { inherit cmake; };
  llhttp = (release "llhttp" pkgs.llhttp).override { inherit cmake; };
  nbytes = (release "nbytes" pkgs.nbytes).override { inherit cmake; };
  nghttp2 = (release "nghttp2" pkgs.nghttp2).override { inherit zlib; };
  nghttp3 = (release "nghttp3" pkgs.nghttp3).override { inherit cmake; };
  ngtcp2 = (release "ngtcp2" pkgs.ngtcp2).override { inherit nghttp3 cmake; };
  gtest = (release "gtest" pkgs.gtest).override { inherit cmake; };
  gbenchmark = (release "gbenchmark" pkgs.gbenchmark).override { inherit cmake; };
  hdrhistogram_c = (release "hdrhistogram_c" pkgs.hdrhistogram_c).override { inherit cmake zlib; };
  libiconvReal = release "libiconvReal" pkgs.libiconvReal;
  libunistring = (release "libunistring" pkgs.libunistring).override { inherit libiconvReal; };
  libidn2 = pkgs.libidn2.override { inherit libunistring; libiconv = libiconvReal; };
  publicsuffix-list = pkgs.publicsuffix-list.overrideAttrs (_: {
    inherit (sources.publicsuffix-list) version;
    src = pkgs.fetchFromGitHub {
      owner = "publicsuffix";
      repo = "list";
      inherit (sources.publicsuffix-list) rev hash;
    };
  });
  libpsl = pkgs.libpsl.override { inherit libidn2 libunistring publicsuffix-list gtk-doc; };
  krb5 = ((release "krb5" pkgs.krb5).override { inherit libedit perl; }).overrideAttrs (old: {
    # Both catalog backports are present in the 1.22.3 release source.
    patches = assert lib.assertMsg
      (map builtins.baseNameOf old.patches == [ "CVE-2026-11850.patch" "CVE-2026-40355-and-CVE-2026-40356.patch" ])
      "Review the catalog Kerberos patches before removing integrated changes";
      lib.optional pkgs.stdenv.hostPlatform.isDarwin
        (builtins.path { path = ./krb5-rpc-support-link.patch; name = "krb5-rpc-support-link.patch"; });
  });
  glfw = ((release "glfw" pkgs.glfw).override { inherit cmake; }).overrideAttrs (old: {
    patches = assert lib.assertMsg (map builtins.baseNameOf old.patches == [ "x11.patch" ])
      "Review the catalog GLFW compatibility patches";
      [ (builtins.path { path = ./glfw-3.5-x11.patch; name = "glfw-x11.patch"; }) ];
  });
  sqlite = ((release "sqlite" pkgs.sqlite).overrideAttrs (_: {
    docsrc = pkgs.fetchurl { inherit (sources.sqlite_doc) url hash; };
  })).override { inherit zlib tcl; };
  zstd = if lib.versionAtLeast pkgs.zstd.version sources.zstd.version then pkgs.zstd else
    (pkgs.zstd.override {
      buildPackages = pkgs.buildPackages // { inherit cmakeMinimal; };
    }).overrideAttrs (old: {
      inherit (sources.zstd) version;
      src = pkgs.fetchFromGitHub {
        owner = "meta";
        repo = "zstd";
        rev = sources.zstd.tag;
        inherit (sources.zstd) hash;
      };
      # The manual update is upstream in 1.6.0. Keep the GNU-tool adaptation,
      # refreshed for the new test source, without removing any test assertions.
      patches = assert lib.assertMsg
        (map builtins.baseNameOf old.patches == [ "playtests-darwin.patch" "man-fix.patch" ])
        "Review the catalog Zstd patches before replacing the compatibility adaptation";
        [ (builtins.path { path = ./zstd-1.6-gnu-tests.patch; name = "zstd-gnu-tests.patch"; }) ];
      postPatch = assert lib.assertMsg
        (lib.hasInfix "message(SEND_ERROR \"You need to build static library to build tests\")" old.postPatch)
        "Review Zstd's shared-library test adaptation";
        lib.replaceStrings
          [ "substituteInPlace build/cmake/CMakeLists.txt" "message(SEND_ERROR \"You need to build static library to build tests\")" ]
          [ "substituteInPlace build/cmake/CMakeModules/ZstdBuild.cmake" "message(SEND_ERROR \"Static library required to build test suite\")" ]
          old.postPatch;
    });
  perl = if lib.versionAtLeast pkgs.perl.version sources.perl.version then pkgs.perl else
    (pkgs.perl.override {
      self = perl;
      inherit zlib;
      inherit (sources.perl) version;
      sha256 = sources.perl.hash;
    }).overrideAttrs (old: {
      doCheck = true;
      patches = old.patches ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin
        ./perl-darwin-library-test.patch;
    });
  perlSources = import ./perl-sources.nix;
  knownLicenses = {
    artistic_2 = lib.licenses.artistic2;
    mit = lib.licenses.mit;
    apache_2_0 = lib.licenses.asl20;
  };
  perlPackages = perl.pkgs.overrideScope (final: previous:
    lib.mapAttrs (name: source: releasePerl previous.${name} source) perlSources // {
        CGI = (releasePerl previous.CGI perlSources.CGI).overrideAttrs (old: {
          # CGI 5 requires URI at runtime; the older catalog recipe predates
          # that dependency, including the Gitweb wrapper's module path.
          propagatedBuildInputs = old.propagatedBuildInputs ++ [ final.URI ];
        });
        CompressRawZlib = (releasePerl previous.CompressRawZlib perlSources.CompressRawZlib).overrideAttrs (old: {
          buildInputs = map (input: if (input.pname or "") == "zlib" then zlib else input) old.buildInputs;
        });
        ModuleRuntime = (releasePerl previous.ModuleRuntime perlSources.ModuleRuntime).overrideAttrs (_: {
          # 0.018 switched from Module::Build to MakeMaker. The underlying
          # buildPerlPackage builder already configures Makefile.PL; restore
          # its standard build/install/test phases without disabling checks.
          buildPhase = null;
          installPhase = null;
          checkPhase = null;
        });
      });
  releasePerl = package: source:
    if lib.versionAtLeast package.version source.version then package else package.overrideAttrs (old: {
    inherit (source) version;
    name = "perl${perl.version}-${old.pname}-${source.version}";
    src = pkgs.fetchurl { inherit (source) url hash; };
    meta = old.meta // {
      identifiers = (old.meta.identifiers or { }) // {
        purlParts = { type = "cpan"; spec = "${old.pname}@${source.version}"; };
      };
    } // lib.optionalAttrs
      (builtins.length source.licenses == 1 && builtins.hasAttr (builtins.head source.licenses) knownLicenses)
      { license = knownLicenses.${builtins.head source.licenses}; };
  });
  sigtoolRelease = if lib.versionAtLeast pkgs.darwin.sigtool.version sources.sigtool.version then
    pkgs.darwin.sigtool else pkgs.darwin.sigtool.overrideAttrs (_: {
      inherit (sources.sigtool) version;
      src = pkgs.fetchFromGitHub {
        owner = "nix-community";
        repo = "sigtool";
        rev = sources.sigtool.tag;
        inherit (sources.sigtool) hash;
      };
    });
  sigtool = sigtoolRelease.override { inherit libplist; };
  git = if lib.versionAtLeast pkgs.git.version sources.git.version then pkgs.git else
    pkgs.git.overrideAttrs (old: {
      inherit (sources.git) version;
      src = pkgs.fetchurl { inherit (sources.git) url hash; };
      meta = old.meta // {
        changelog = "https://github.com/git/git/blob/v${sources.git.version}/Documentation/RelNotes/${sources.git.version}.adoc";
      };
    });
  nativeDependencies = {
  inherit zstd perl sigtool git perlPackages zlib expat sqlite libffiReal readline
    icu ada simdjson simdutf llhttp nbytes nghttp2 nghttp3 ngtcp2 gtest gbenchmark hdrhistogram_c
    libiconvReal libunistring libidn2 publicsuffix-list libpsl krb5 glfw cmake cmakeMinimal libarchive
    libplist libedit tcl expect dejagnu gtk-doc rust libgit2;
  merve = pkgs.merve.override { inherit simdutf cmake; };
  curl = pkgs.curl.override {
    inherit zstd zlib nghttp2 nghttp3 ngtcp2 libidn2 libpsl perl;
    libkrb5 = krb5;
  };
  # 1035.1.102 removes sources/commands required by the current full-feature
  # recipe. Do not silently retire them or synthesize a legacy-source merge.
  cctools = pkgs.cctools;
  };
in nativeDependencies
