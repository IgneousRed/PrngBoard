{ pkgs, toolchain }:
let
  package = (pkgs.practrand.override {
    stdenv = toolchain.llvmPackages.stdenv or pkgs.stdenv;
  }).overrideAttrs (old: {
    # Consumers need only RNG_test; do not build unrelated benchmark/output tools.
    buildPhase = builtins.replaceStrings [ "RNG_test RNG_benchmark RNG_output" ] [ "RNG_test" ] old.buildPhase;
    installPhase = builtins.replaceStrings [ "RNG_test RNG_benchmark RNG_output" ] [ "RNG_test" ] old.installPhase;
    env = old.env // { NIX_CFLAGS_COMPILE = "-O3 -std=c++14"; };
    # Upstream 0.96 assumes __GNUC__ means x86 and has an invalid clock fallback.
    # Restrict x86 intrinsics and use chrono ticks on ARM; statistical code is unchanged.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/platform_specifics.cpp \
        --replace-fail '#ifdef __GNUC__' '#if defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))' \
        --replace-fail '#elif defined __GNUC__' '#elif defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))' \
        --replace-fail 'return std::chrono::high_resolution_clock();' 'return std::chrono::high_resolution_clock::now().time_since_epoch().count();'
      substituteInPlace tools/dummy_rng.h \
        --replace-fail '#if defined __GNUC__' '#if defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))'
    '';
    meta = old.meta // { platforms = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ]; };
  });
in pkgs.runCommand "practrand-test-command" { } ''
  mkdir -p $out/bin
  ln -s ${package}/bin/PractRand-RNG_test $out/bin/PractRandTest
''
