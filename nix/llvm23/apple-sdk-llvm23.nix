{ pkgs, rawBintools }:
let
  original = pkgs.apple-sdk_14;
  sdk = pkgs.stdenvNoCC.mkDerivation {
    pname = "apple-sdk-llvm23";
    inherit (original) version;
    nativeBuildInputs = [ pkgs.coreutils ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      mkdir -p "$out"
      cp -a ${original}/. "$out/"
      chmod -R u+w "$out"
      substituteInPlace "$out/nix-support/setup-hook" --replace-fail ${original} "$out"
      for tool in libtool lipo nm otool size strip; do
        target="$out/Toolchains/XcodeDefault.xctoolchain/usr/bin/$tool"
        test -L "$target"
        test -x ${rawBintools}/bin/$tool
        ln -sf ${rawBintools}/bin/$tool "$target"
      done
    '';
    passthru.sdkroot = sdk + "/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
    meta = original.meta // {
      description = "Apple SDK 14.4 with its six Xcode tool aliases supplied by LLVM 23.1.6";
    };
  };
in sdk
