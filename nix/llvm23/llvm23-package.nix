{ pkgs, python3 ? pkgs.python315 }:
assert pkgs.lib.assertMsg (pkgs.stdenv.hostPlatform.system == "aarch64-darwin")
  "The verified LLVM 23.1.6 bottles support Apple Silicon macOS 26 or later";
let
  inherit (pkgs) lib;
  fetch = name: digest: hash: pkgs.fetchurl {
    name = name + "-23.1.6-arm64-tahoe.bottle.tar.gz";
    url = "https://ghcr.io/v2/homebrew/core/${name}/blobs/sha256:${digest}";
    inherit hash;
    curlOptsList = [ "--header" "Authorization: Bearer QQ==" ];
  };
  llvmArchive = fetch "llvm" "e8479b14cf92f2c1092ef31531a89b8c9b88e97207e3b80e330f2037e594963b" "sha256-6EebFM+S8sEJLvMVMaibjJuI6XIH47gOMw8gN+WUljs=";
  lldArchive = fetch "lld" "1c2e0a1ad4edbd0082a6f90f434cc40ce8494ae65ab584bed45611ea325b4780" "sha256-HC4KGtTtvQCCpvkPQ0zEDOhJSuZatYS+1FYR6jJbR4A=";
  unpackScript = builtins.path { path = ./unpack-llvm.py; name = "unpack-llvm.py"; };
  relocateScript = builtins.path { path = ./relocate-llvm.py; name = "relocate-llvm.py"; };
  auxiliary = pkgs.runCommand "llvm-auxiliary-23.1.6" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    for program in ${native}/bin/*; do
      if head -c 2 "$program" | grep -q '^#!'; then
        case "$(basename "$program")" in set-xcode-analyzer) continue ;; esac
        case "$(head -n 1 "$program")" in
          *perl*) interpreter=${pkgs.perl}/bin/perl ;;
          *python*) interpreter=${python3}/bin/python3 ;;
          *) echo "Unsupported auxiliary interpreter: $program" >&2; exit 1 ;;
        esac
        makeWrapper "$interpreter" "$out/bin/$(basename "$program")" \
          --prefix PATH : ${lib.makeBinPath [ python3 pkgs.perl ]}:${native}/libexec --add-flags "$program"
      fi
    done
  '';
  native = pkgs.stdenvNoCC.mkDerivation {
  pname = "llvm-native";
  version = "23.1.6";
  nativeBuildInputs = [ pkgs.python3 pkgs.cctools pkgs.darwin.sigtool ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    python3 ${unpackScript} "$out" ${llvmArchive} ${lldArchive}
    python3 ${relocateScript} "$out" ${lib.getLib pkgs.z3} ${lib.getLib pkgs.zstd}
    for program in "$out"/bin/*; do
      if head -c 2 "$program" | grep -q '^#!'; then chmod a-x "$program"; fi
    done
    "$out/bin/clang" --version
    "$out/bin/llvm-config" --version
    "$out/bin/ld64.lld" --version
    "$out/bin/wasm-ld" --version
  '';
  passthru = {
    isClang = true; langC = true; langCC = true; libllvm = native;
    hardeningUnsupportedFlagsByTargetPlatform = pkgs.llvmPackages_23.clang-unwrapped.hardeningUnsupportedFlagsByTargetPlatform; inherit llvmArchive lldArchive auxiliary;
    unsupportedAuxiliary = [ "set-xcode-analyzer (requires Xcode and PyObjC)" ];
  };
  meta = {
    description = "Verified LLVM, Clang and LLD 23.1.6 native tools; auxiliary interpreters are a separate package";
    priority = 20;
    platforms = [ "aarch64-darwin" ];
    license = lib.licenses.asl20;
  };
};
in native
