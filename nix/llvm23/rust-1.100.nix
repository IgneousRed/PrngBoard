{ pkgs, llvmPackages, cmake, zlib, sqlite, curl, libgit2 }:
let
  inherit (pkgs) lib;
  provider = builtins.readFile ./upstream/rust-1_100.nix;
  anchor = "import ./default.nix";
  # Keep the upstream family unchanged on disk; use the existing locked API.
  family = builtins.toFile "rust-1_100.nix" (
    assert lib.assertMsg (builtins.length (lib.splitString anchor provider) == 2)
      "Review the Rust family provider import";
    lib.replaceStrings [ anchor ]
      [ "import ${pkgs.path}/pkgs/development/compilers/rust/default.nix" ] provider
  );
  selected = set: set // { rust_1_100 = rust; llvmPackages_23 = llvmPackages; };
  base = pkgs.callPackage family {
    llvmPackages_23 = llvmPackages;
    pkgsBuildBuild = selected pkgs.pkgsBuildBuild;
    pkgsBuildHost = selected pkgs.pkgsBuildHost;
    pkgsBuildTarget = selected pkgs.pkgsBuildTarget;
    pkgsHostTarget = selected pkgs.pkgsHostTarget;
    pkgsTargetTarget = selected pkgs.pkgsTargetTarget;
  };
  rust = base // {
    packages = base.packages // {
      stable = base.packages.stable.overrideScope (_final: previous: {
        rustc-unwrapped = (previous.rustc-unwrapped.override {
          inherit cmake zlib;
          python3 = pkgs.python315;
        }).overrideAttrs (old: {
          # Upstream provider correction for the unpatched 1.100 bootstrap.
          # Preserve fatal warnings, source patches, LLVM and all test flags.
          env = (old.env or { }) // { RUST_MIN_STACK = 17 * 1024 * 1024; };
        });
        cargo = previous.cargo.override {
          inherit cmake zlib sqlite curl libgit2;
          python3 = pkgs.python315;
          pkgsHostHost = pkgs.pkgsHostHost // { inherit curl; };
        };
      });
    };
  };
in
assert lib.assertMsg pkgs.stdenv.hostPlatform.isDarwin
  "This portable native Rust family has only been selected for Darwin";
rust
