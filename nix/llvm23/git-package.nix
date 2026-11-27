{ pkgs, python }:
let
  dependencies = import ./native-dependencies.nix { inherit pkgs; };
in (dependencies.git.override {
  python3 = python;
  inherit (dependencies) perlPackages curl expat;
  inherit (dependencies.rust.packages.stable) cargo rustc;
}).overrideAttrs (old: {
  # The provider embeds Gitweb's module paths directly instead of walking
  # CGI's propagated inputs. CGI 5 also needs the shared URI module there.
  postInstall = old.postInstall + ''
    substituteInPlace "$out/share/gitweb/gitweb.cgi" --replace-fail \
      'use CGI ' 'use lib "${dependencies.perlPackages.URI}/${dependencies.perl.libPrefix}"; use CGI '
  '';
})
