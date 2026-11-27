{
  description = "Locked development dependencies for prng-board";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/619c39f6eac5d1ed6b8f073a9414baf7034b2356";
  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      forSystem = system:
        let
          pkgs = import nixpkgs { inherit system; };
          dependencies = import ./nix/llvm23/native-dependencies.nix { inherit pkgs; };
          toolchain = if system == "aarch64-darwin" then
            import ./nix/llvm23/llvm23-toolchain.nix { inherit pkgs; }
          else import ./nix/toolchain.nix { pkgs = pkgs // {
            raylib = pkgs.raylib.override { inherit (dependencies) glfw cmake; };
          }; };
          python = toolchain.python or (pkgs.python315.override {
            inherit (dependencies) zstd zlib expat sqlite readline;
          });
          environmentMetadata = pkgs.writeText "project-environment.json" (builtins.toJSON {
            schema = 1;
            variables = {
              ODIN = "${toolchain.odin}/bin/odin";
              ODIN_ROOT = "${toolchain.odin}/share";
            };
            unset = [ "PYTHONHOME" "PYTHONPATH" "VIRTUAL_ENV" ];
          });
          updateMetadata = {
            schema = 1;
            dependencies = [
              { name = "nixpkgs"; current = nixpkgs.rev; kind = "github-revision";
                repository = "NixOS/nixpkgs"; ref = "nixpkgs-unstable"; }
              { name = "Odin"; current = toolchain.odin.version; kind = "github-release";
                repository = "odin-lang/Odin"; }
              { name = "LLVM"; current = "llvmorg-${toolchain.llvmPackages.llvm.version}"; kind = "github-release";
                repository = "llvm/llvm-project"; }
            ];
          };
          updates = pkgs.writeText "dependency-updates.json" (builtins.toJSON updateMetadata);
          metadata = pkgs.runCommand "odin-native-environment-metadata" { } ''
            mkdir -p $out/share
            cp ${environmentMetadata} $out/share/project-environment.json
            cp ${updates} $out/share/dependency-updates.json
          '';
          environment = pkgs.buildEnv {
            name = "odin-native-development";
            paths = [ toolchain.odin python metadata (import ./nix/practrand.nix { inherit pkgs toolchain; }) ];
          };
        in { inherit pkgs python environment updateMetadata; };
    in {
      lib.dependencyCheck = eachSystem (system:
        let cfg = forSystem system; in (import ./nix/dependency-check.nix cfg.pkgs cfg.updateMetadata) // {
          preferredPython = "${cfg.python}/bin/python3";
        });
      packages = eachSystem (system: { dev-environment = (forSystem system).environment; });
      devShells = eachSystem (system:
        let configured = forSystem system;
        in { default = configured.pkgs.mkShellNoCC {
          packages = [ configured.environment ];
          PROJECT_NIX_ENVIRONMENT = configured.environment;
        }; });
    };
}
