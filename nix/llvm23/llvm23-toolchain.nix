{ pkgs }:
let
  inherit (pkgs) lib;
  dependencies = import ./native-dependencies.nix { inherit pkgs; };
  native = import ./llvm23-package.nix {
    inherit pkgs;
    python3 = python;
    inherit (dependencies) zstd cctools sigtool perl;
  };
  llvmTools = pkgs.runCommand "llvm-tools-23.1.6" { version = "23.1.6"; } ''
    mkdir -p "$out/bin"
    for program in ${native}/bin/*; do
      case "$(basename "$program")" in clang|clang++|clang-23|clang-cl|clang-cpp) continue ;; esac
      [ -x "$program" ] && ln -s "$program" "$out/bin/$(basename "$program")"
    done
    ln -s ${native}/lib "$out/lib"
  '';
  lldTools = pkgs.runCommand "lld-23.1.6" { version = "23.1.6"; } ''
    mkdir -p "$out/bin"
    for program in ld.lld ld64.lld lld lld-link wasm-ld; do ln -s ${native}/bin/$program "$out/bin/$program"; done
  '';
  darwinLd = pkgs.writeShellScriptBin "ld" ''
    exec ${native}/bin/ld64.lld "$@"
  '';
  rawBintools = pkgs.runCommand "llvm-binutils-23.1.6" {
    version = "23.1.6";
    passthru = { isLLVM = true; targetPrefix = ""; llvm = native; lld = native; };
  } ''
    mkdir -p "$out/bin"
    for program in llvm-ar llvm-ranlib llvm-nm llvm-strip llvm-objcopy llvm-objdump llvm-readobj llvm-strings llvm-symbolizer llvm-cxxfilt llvm-size llvm-libtool-darwin llvm-lipo llvm-otool llvm-install-name-tool ld.lld ld64.lld lld lld-link wasm-ld; do ln -s ${native}/bin/$program "$out/bin/$program"; done
    for pair in ar:llvm-ar ranlib:llvm-ranlib nm:llvm-nm strip:llvm-strip objcopy:llvm-objcopy objdump:llvm-objdump readelf:llvm-readobj strings:llvm-strings addr2line:llvm-symbolizer c++filt:llvm-cxxfilt size:llvm-size libtool:llvm-libtool-darwin lipo:llvm-lipo otool:llvm-otool install_name_tool:llvm-install-name-tool; do
      ln -sf ${native}/bin/"''${pair#*:}" "$out/bin/''${pair%%:*}"
    done
    ln -sf ${darwinLd}/bin/ld "$out/bin/ld"
  '';
  sdk = import ./apple-sdk-llvm23.nix { inherit pkgs rawBintools; };
  bintools = (pkgs.wrapBintoolsWith { bintools = rawBintools; apple-sdk = sdk; }).overrideAttrs (old:
    let
      before = ''un(recognized|known)\ option'';
      after = ''un(recognized|known)\ (option|argument)'';
    in assert lib.assertMsg (lib.hasInfix before old.postFixup)
      "Recheck the pinned bintools hardening capability probe";
    { postFixup = lib.replaceStrings [ before ] [ after ] old.postFixup; });
  systemCxxStubs = pkgs.runCommand "apple-sdk-27.0-libcxx-stubs" {
    passthru = { isLLVM = true; dev = native; };
    meta = pkgs.darwin.libcxx.meta;
  } ''
    mkdir -p "$out/lib"
    cp -P ${pkgs.darwin.libcxx}/lib/*.tbd "$out/lib/"
  '';
  clang = pkgs.wrapCCWith {
    cc = native; inherit bintools; libcxx = systemCxxStubs; apple-sdk = sdk;
    extraBuildCommands = ''
      echo '-mlinker-version=957.1' >> "$out/nix-support/cc-cflags"
    '';
  };
  stdenv = pkgs.stdenv.override (old: {
    allowedRequisites = null; cc = clang; hasCC = true;
    extraBuildInputs = map (input: if (input.pname or "") == "apple-sdk" then sdk else input)
      (old.extraBuildInputs or [ ]);
  });
  llvmPackages = {
    inherit stdenv clang bintools;
    llvm = llvmTools // { dev = native; lib = native; };
    lld = lldTools;
  };
  shared = import ./toolchain.nix { inherit llvmPackages; pkgs = pkgs // {
    raylib = pkgs.raylib.override { inherit stdenv; inherit (dependencies) glfw cmake; };
    odin = pkgs.odin.overrideAttrs (old:
      let anchor = "--set-default ODIN_ROOT $out/share";
      in assert lib.assertMsg (lib.hasInfix anchor old.installPhase)
        "Recheck the pinned Odin wrapper SDK setup";
      { src = pkgs.fetchFromGitHub {
      owner = "odin-lang"; repo = "Odin";
      rev = "9a6991685ddf663956d9836602eb421e141fc443";
      hash = "sha256-LzvPcA6CA0p9DZi1cuFUizDPkVODMZ0OC9/y+NAO0Kc=";
    };
    installPhase = lib.replaceStrings [ anchor ] [
      (anchor + " --prefix PATH : ${sdk}/usr/bin --set DEVELOPER_DIR ${sdk} --set SDKROOT ${sdk.sdkroot}")
    ] old.installPhase;
    });
  }; };
  python = (pkgs.python315.override {
    inherit stdenv;
    inherit (dependencies) zstd zlib expat sqlite readline;
  }).overrideAttrs (old:
    assert lib.assertMsg (builtins.elem "--with-lto" old.configureFlags)
      "Recheck Python's configured LTO policy before updating this recipe";
    {
      configureFlags = map (flag: if flag == "--with-lto" then "--with-lto=full" else flag)
        old.configureFlags;
      preBuild = (old.preBuild or "") + ''
        export NIX_LDFLAGS="''${NIX_LDFLAGS:-} --threads=''${NIX_BUILD_CORES}"
      '';
    });
  git = import ./git-package.nix { inherit pkgs python; };
  nodejs = pkgs.nodejs_26.override {
    nodejs-slim = pkgs.nodejs-slim_26.override {
      python3 = python;
      darwin = pkgs.darwin // { inherit (dependencies) sigtool; };
      inherit (dependencies) zstd zlib libffiReal sqlite icu ada simdjson simdutf
        llhttp nbytes nghttp2 gtest hdrhistogram_c merve;
    };
  };
in shared // { inherit llvmPackages native rawBintools python sdk git nodejs dependencies; }
