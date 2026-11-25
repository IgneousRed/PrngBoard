{ pkgs }:
assert pkgs.lib.assertMsg (pkgs.odin.version == "dev-2026-11a" && pkgs.raylib.version == "6.2")
  "Review the compiler source identity and Raylib ABI before changing the shared toolchain";
let
  inherit (pkgs) lib;
  llvmPackages = pkgs.llvmPackages_22;
  raylib = pkgs.raylib;
  raylibStatic = (pkgs.raylib.override { sharedLib = false; }).overrideAttrs (old: {
    cmakeFlags = builtins.filter (flag: !(lib.hasPrefix "-DUSE_EXTERNAL_GLFW=" flag)) old.cmakeFlags
      ++ [ "-DUSE_EXTERNAL_GLFW=OFF" ];
  });
  odinBase = (pkgs.odin.override { inherit llvmPackages; }).overrideAttrs (old: {
    # Preserve Odin's platform/Wasm binding branches and embed the reviewed source identity.
    patches = builtins.filter (patch: !(lib.hasSuffix "system-raylib.patch" (toString patch))) old.patches;
    postPatch = old.postPatch + ''
      substituteInPlace build_odin.sh \
        --replace-fail 'GIT_DATE=$(date +"%Y-%m")' 'GIT_DATE=2026-11a
      CPPFLAGS="$CPPFLAGS -DGIT_SHA=\"9a6991685\""'
    '';
    postInstall = (if (old.postInstall or null) == null then "" else old.postInstall) + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      mkdir -p $out/share/vendor/raylib/macos
      ln -s ${raylibStatic}/lib/libraylib.a $out/share/vendor/raylib/macos/libraylib.a
      ln -s ${lib.getLib raylib}/lib/libraylib.dylib $out/share/vendor/raylib/macos/libraylib.620.dylib
    '' + lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      # Never expose a native archive in the other architecture's binding slot.
      rm -rf $out/share/vendor/raylib/linux $out/share/vendor/raylib/linux-arm64
      target=${if pkgs.stdenv.hostPlatform.isAarch64 then "linux-arm64" else "linux"}
      mkdir -p $out/share/vendor/raylib/$target
      ln -s ${raylibStatic}/lib/libraylib.a $out/share/vendor/raylib/$target/libraylib.a
      ln -s ${lib.getLib raylib}/lib/libraylib.so $out/share/vendor/raylib/$target/libraylib.so.620
    '';
  });
  # The catalog's older Darwin linker emits bad debug maps for LLVM 22 Odin
  # objects. Keep debug information intact by selecting matching LLD by default;
  # an explicit caller linker remains authoritative.
  odinLauncher = pkgs.writeShellScriptBin "odin" ''
    command="''${1:-}"
    case "$command" in
      build|run|test)
        for argument in "$@"; do
          case "$argument" in
            --) break ;;
            -linker:*) exec ${odinBase}/bin/odin "$@" ;;
          esac
        done
        [ "$#" -ge 2 ] || exec ${odinBase}/bin/odin "$@"
        package=$2
        shift 2
        exec ${odinBase}/bin/odin "$command" "$package" -linker:lld "$@"
        ;;
      *) exec ${odinBase}/bin/odin "$@" ;;
    esac
  '';
  odin = if !pkgs.stdenv.hostPlatform.isDarwin then odinBase else
    pkgs.runCommand "odin-${odinBase.version}" {
      inherit (odinBase) version;
      passthru = { inherit (odinBase) src; };
      meta = odinBase.meta;
    } ''
      mkdir -p "$out/bin"
      ln -s ${odinLauncher}/bin/odin "$out/bin/odin"
      ln -s ${odinBase}/share "$out/share"
    '';
in
{
  inherit odin llvmPackages raylib raylibStatic;
}
